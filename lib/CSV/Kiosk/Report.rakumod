unit module CSV::Kiosk::Report;
use Text::CSV;
use PDF::Lite;

sub read-csv(Str:D $csv-file, :$sep = ',') returns Hash is export {
    my $csv = Text::CSV.new(:separator($sep));
    my $fh  = open $csv-file, :r;
    my $header = $csv.getline($fh) or die "CSV has no header";
    my @rows;
    while my $r = $csv.getline($fh) {
        @rows.push($r);
    }
    $fh.close;
    { :header(@$header), :rows(@rows) }
}

sub sort-csv(Str:D $csv-file, Str :$by?, :$sep = ',') is export {
    my $data = read-csv($csv-file, :$sep);
    my @h = $data<header>;
    my %idx = @h.kv.invert;
    my $i = ($by.defined and %idx{$by}:exists) ?? %idx{$by} !! 0;
    my @sorted = $data<rows>.sort( -> $a, $b { $a[$i] leg $b[$i] });
    my $csv = Text::CSV.new(:separator($sep));
    my $tmp = "{$csv-file}.sorted.tmp";
    my $fh  = open $tmp, :w;
    $csv.print($fh, @h); $fh.say;
    for @sorted -> @r { $csv.print($fh, @r); $fh.say; }
    $fh.close;
    rename($tmp, $csv-file);
}

sub generate-pdf(Str:D $csv-file, Str:D $pdf-file, Str :$title = 'CSV List', :$sep = ',') is export {
    my $data = read-csv($csv-file, :$sep);
    my @header = $data<header>;
    my @rows   = $data<rows>;

    my $doc = PDF::Lite.new;
    my $page = $doc.page: :size<Letter>, :orientation<portrait>;
    my $m = 36;
    my $x = $m;
    my $y = $page.height - $m;

    $page.text: :at($x, $y), :font-size(16), :text("{$title}");
    $y -= 24;
    $page.text: :at($x, $y), :font-size(10), :text("Fields: " ~ @header.join(', '));
    $y -= 16;

    my $col-gap = 24;
    my $col-w   = ($page.width - 2*$m - $col-gap) div 2;
    my $left-x  = $x;
    my $right-x = $x + $col-w + $col-gap;
    my $line-h = 12;
    my $i = 0;
    for @rows».Array -> @r {
        my $text = @r[0];
        if $y < $m + $line-h {
            $page = $doc.page: :size<Letter>, :orientation<portrait>;
            $y = $page.height - $m;
        }
        my $cx = $i %% 2 ?? $left-x !! $right-x;
        $page.text: :at($cx, $y), :font-size(11), :text($text);
        $y -= $i %% 2 ?? 0 !! $line-h;
        $i++;
    }
    my $count = @rows.elems;
    $page.text: :at($page.width - $m - 100, $m/2), :font-size(10), :text("Total: {$count}");
    $doc.save-as($pdf-file);
}
