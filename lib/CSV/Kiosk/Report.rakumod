use v6;
unit module CSV::Kiosk::Report;

# ---- tiny compatibility shim for PDF::Lite / PDF::Content text() signatures ----
# Some versions expect text($x,$y,$str); others expect text($str, :at[$x,$y]).
sub txt($page, $x, $y, $s) {
    my $ok = False;
    try {
        $page.text($x, $y, $s);
        $ok = True;
    }
    unless $ok {
        try {
            $page.text($s, :at[$x, $y]);
            $ok = True;
        }
        CATCH { default { die "PDF::Content.text signature mismatch: tried 3-pos and 1-pos + :at[]" } }
    }
    True
}

sub read-csv(Str:D $csv-file, Str :$sep = ',') returns Hash is export {
    my $fh = open $csv-file, :r or die "Cannot open $csv-file";
    my @lines = $fh.lines;
    $fh.close;
    die "CSV has no data" unless @lines;
    my @header = @lines.shift.split($sep);
    my @rows;
    for @lines -> $line {
        next if $line.trim.chars == 0;
        my @cols = $line.split($sep);
        @cols = @cols.map(*.trim);
        @rows.push(@cols);
    }
    { header => @header, rows => @rows }
}

sub sort-csv(Str:D $csv-file, Str :$by = '', Str :$sep = ',') is export {
    my $data   = read-csv($csv-file, :$sep);
    my @header = $data<header>;
    my %idx    = @header.kv.map({ .value => .key }).Hash;

my $i;
if $by.chars and %idx{$by}:exists {
    $i = %idx{$by};
}
else {
    $i = 0;
}

    my @rows   = $data<rows>.sort( -> @a, @b { @a[$i] leg @b[$i] } );
    spurt $csv-file, @header.join($sep) ~ "\n" ~ @rows.map(*.join($sep)).join("\n") ~ "\n";
    True
}

sub generate-pdf(Str:D $csv-file, Str:D $pdf-file, Str :$title = 'CSV List', Str :$sep = ',') is export {
    use PDF::Lite;

    my $data   = read-csv($csv-file, :$sep);
    my @header = $data<header>;
    my @rows   = $data<rows>;

    my $doc  = PDF::Lite.new;
    my $page = $doc.page: :size<Letter>, :orientation<portrait>;

    my $m    = 36;
    my $x    = $m;
    my $y    = $page.height - $m;
    my $lh   = 14;

    # Title
    try { $page.set-font('Helvetica-Bold', 18) }
    txt($page, $x, $y, $title);
    $y -= 2*$lh;

    # Header
    try { $page.set-font('Helvetica', 10) }
    txt($page, $x, $y, "Fields: " ~ @header.join(', '));
    $y -= 1.5*$lh;

    # Rows
    try { $page.set-font('Helvetica', 11) }
    for @rows -> @r {
        if $y < $m + $lh {
            $page = $doc.page: :size<Letter>, :orientation<portrait>;
            $y = $page.height - $m;
            try { $page.set-font('Helvetica', 11) }; #CATCH { }
        }
        my $line = @r.join('  |  ');
        txt($page, $x, $y, $line);
        $y -= $lh;
    }

    # Footer count
    try { $page.set-font('Helvetica-Oblique', 10) }
    CATCH { }
    txt($page, $x, $m / 2, "Total records: " ~ @rows.elems);

    $doc.save-as($pdf-file);
    True
}
