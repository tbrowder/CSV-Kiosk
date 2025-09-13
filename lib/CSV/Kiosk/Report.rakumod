unit module CSV::Kiosk::Report;

our sub sort-csv(
    Str :$csv,
    Str :$by,
    Str :$sep = ',',
    Str :$out,
    Bool :$numeric,
    Bool :$reverse,
    --> Int
) is export {
    try {
        unless $csv.IO.f {
            note "sort-csv: input file not found: $csv";
            return 2;
        }

        my $fh = $csv.IO.open(:r);
        my $header-line = $fh.get // do {
            note "sort-csv: empty file: $csv";
            return 2;
        };
        my @headers = $header-line.split($sep, :skip-empty(False));
        my $idx = $by.defined ?? @headers.first-index($by) !! 0;
        if $idx ~~ Nil {
            note "sort-csv: header '$by' not found in {@headers.join: ', '}";
            return 2;
        }

        my @rows = gather for $fh.lines -> $line {
            my @f = $line.split($sep, :skip-empty(False));
            take @f;
        }
        $fh.close;

        my &key = $numeric ?? { .[$idx].Numeric } !! { .[$idx] // '' };
        if $numeric {
            @rows = @rows.sort( { key($^a) <=> key($^b) } );
        } else {
            @rows = @rows.sort( { key($^a) cmp key($^b) } );
        }
        @rows .= reverse if $reverse;

        my $out-h = $out ?? $out.IO.open(:w) !! $*OUT;
        $out-h.say: @headers.join($sep);
        for @rows -> @f { $out-h.say: @f.join($sep) }
        $out-h.close if $out;
        return 0;
    }
    CATCH {
        default {
            note "sort-csv: $_";
            return 1;
        }
    }
}

our sub generate-pdf(
    Str :$csv,
    Str :$out,
    Str :$title = 'CSV Kiosk Report',
    --> Int
) is export {
    try {
        unless $csv.IO.f {
            note "generate-pdf: input not found: $csv";
            return 2;
        }
        unless $out.defined {
            note "generate-pdf: --out is required";
            return 2;
        }
        my $text = "$title\nSource: {$csv.IO.basename}";

        my %xref;
        my $buf = "";
        sub emit(Str $s) { $buf ~= $s }
        sub add-obj(Int $n, Str $body) {
            %xref{$n} = $buf.chars;
            emit("$n 0 obj\n$body\nendobj\n");
        }

        emit("%PDF-1.4\n%\xE2\xE3\xCF\xD3\n");

        add-obj 1, "<< /Type /Catalog /Pages 2 0 R >>";
        add-obj 2, "<< /Type /Pages /Kids [3 0 R] /Count 1 >>";
        add-obj 3, "<< /Type /Page /Parent 2 0 R /MediaBox [0 0 612 792] /Contents 4 0 R /Resources << /Font << /F1 5 0 R >> >> >>";

        my $content = q:to/END/;
BT
/F1 12 Tf
72 720 Td
(TITLE) Tj
0 -18 Td
(SOURCE) Tj
ET
END
        $content .= subst('TITLE',  $text.lines[0] // '');
        $content .= subst('SOURCE', $text.lines[1] // '');
        my $len = $content.encode('ascii').bytes;
        add-obj 4, "<< /Length $len >>\nstream\n$content\nendstream";

        add-obj 5, "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>";

        my $xref-start = $buf.chars;
        emit("xref\n0 6\n");
        emit(sprintf("%010d %05d f \n", 0, 65535));
        for 1..5 -> $n {
            emit(sprintf("%010d %05d n \n", %xref{$n}, 0));
        }
        emit("trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n$xref-start\n%%EOF");

        $out.IO.spurt($buf);
        return 0;
    }
    CATCH {
        default {
            note "generate-pdf: $_";
            return 1;
        }
    }
}
