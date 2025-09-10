use v6;
use Test;
use Text::CSV;

# Keep Thomas’s style: use and/or, avoid &&/||
plan 6;  # Will skip 2 if PDF::Lite is not available

# -- helpers -----------------------------------------------------------------
sub find-exe-containing(Str $needle --> IO::Path) {
    my $bindir = "bin".IO;
    die "No bin/ directory present" unless $bindir.d;
    for $bindir.dir -> $f {
        next unless $f.f and $f.basename.lc.contains($needle.lc);
        return $f if $f.s > 0;
    }
    die "Cannot find an executable in bin/ matching: {$needle}";
}

sub read-csv(Str $path, :$sep = ',') {
    my $csv = Text::CSV.new(:separator($sep));
    my $fh  = open $path, :r or die "Cannot open $path";
    my $hdr = $csv.getline($fh) or die "CSV has no header";
    my @rows;
    while my $r = $csv.getline($fh) {
        @rows.push($r.Array);
    }
    $fh.close;
    return $hdr.Array, @rows;
}

# -- locate executables ------------------------------------------------------
my $kiosk  = find-exe-containing('kiosk');
ok $kiosk.e, "found kiosk bin at {$kiosk}";

my $report = find-exe-containing('report');
ok $report.e, "found report bin at {$report}";

# -- setup a temp CSV with header -------------------------------------------
my $tmpdir = "t/tmp".IO;
$tmpdir.mkdir unless $tmpdir.e;
my $csv = $tmpdir.add("attendees.csv").Str;
spurt $csv, "name,email\nAlice,alice\@example.com\nBob,bob\@example.com\n";

# -- run kiosk once: add a single row, then quit ----------------------------
my $stdin = "Charlie\ncharlie\@example.com\nq\n";
my $p = Proc::Async.new($kiosk.Str, "--csv", $csv);
my @stderr;
$p.stderr.tap(-> $b { @stderr.push($b.decode) });
$p.start;
$p.write($stdin);
$p.close-stdin;
await $p;
is $p.result.exitcode, 0, 'kiosk exited cleanly';
diag @stderr.join if @stderr.elems;

my ($hdr, @rows) = read-csv($csv);
ok @rows.grep({ .[0] eq 'Charlie' and .[1] eq 'charlie@example.com' }).elems == 1,
   'kiosk appended expected row';

# -- sort by header "name" ---------------------------------------------------
my $sp = Proc::Async.new($report.Str, "sort", "--csv", $csv, "--by", "name");
$sp.start; await $sp;
is $sp.result.exitcode, 0, 'report sort exited cleanly';

# -- generate PDF (skip if PDF::Lite not installed) -------------------------
my $pdf-okay = True;
CATCH { default { $pdf-okay = False } }
try require ::('PDF::Lite');

if $pdf-okay {
    my $out = $tmpdir.add("attendees.pdf").Str;
    my $pp = Proc::Async.new($report.Str, "pdf", "--csv", $csv, "--out", $out, "--title", "Attendees");
    $pp.start; await $pp;
    is $pp.result.exitcode, 0, 'report pdf exited cleanly';
    ok $out.IO.e and $out.IO.s; # , 'pdf file exists and is non-empty';
} 
else {
    skip "PDF::Lite not available; skipping PDF step", 2;
}
