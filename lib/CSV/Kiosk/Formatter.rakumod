use v6;
unit module CSV::Kiosk::Formatter;

role Formatter { method render(*@) { ... } }

class Text does Formatter {
    method render(@records, :$title = 'List') {
        my @lines = $title, '-' x $title.chars;
        for @records { @lines.push: .Str }
        @lines.join("\n") ~ "\n"
    }
}

class CSVOut does Formatter {
    has Str $.sep = ',';
    method render(@records, :@header = <name email>) {
        my @rows = @records.map({ .as-row(@header).join($!sep) });
        @header.join($!sep) ~ "\n" ~ @rows.join("\n") ~ "\n"
    }
}

class JSONOut does Formatter {
    use JSON::Fast;
    method render(@records, :@header = <name email>) {
        to-json(@records.map({ @header Z=> .as-row(@header) }).map(*.Hash))
    }
}

class PDFOut does Formatter {
    # tolerant text(): 3-pos fallback to 1-pos + :at
    sub txt($page, $x, $y, $s) {
        (try { $page.text($x, $y, $s); True } // False)
        or (try { $page.text($s, :at[$x, $y]); True } // False)
        or die "PDF text() signature mismatch";
        True
    }
    method render(@records, :$title = 'List', :$out!, :@header = <name email>) {
        use PDF::Lite;
        my $doc  = PDF::Lite.new;
        my $page = $doc.page(:size<Letter>, :orientation<portrait>);
        my $m = 36; my $x = $m; my $y = $page.height - $m; my $lh = 14;
        try $page.set-font('Helvetica-Bold', 18);
        txt($page, $x, $y, $title); $y -= 2*$lh;
        try $page.set-font('Helvetica', 10);
        txt($page, $x, $y, "Fields: " ~ @header.join(', ')); $y -= 1.5*$lh;
        try $page.set-font('Helvetica', 11);
        for @records -> $r {
            if $y < $m + $lh {
                $page = $doc.page(:size<Letter>, :orientation<portrait>);
                $y = $page.height - $m;
                try $page.set-font('Helvetica', 11);
            }
            txt($page, $x, $y, $r.as-row(@header).join('  |  '));
            $y -= $lh;
        }
        try $page.set-font('Helvetica-Oblique', 10);
        txt($page, $x, $m/2, "Total: " ~ @records.elems);
        $doc.save-as($out);
        $out
    }
}

