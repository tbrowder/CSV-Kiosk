
use v6;
use Test;
use Text::CSV;

plan *;  # flexible test count; we'll end with done-testing

# -------- helpers --------
sub find-exe-matching(*@needles --> IO::Path) {
    my $bindir = "bin".IO;
    return Nil unless $bindir.d;
    my @cands = $bindir.dir.grep(*.f);
    for @needles -> $n {
        my $cand = @cands.first({ .basename.lc.contains($n.lc) });
        return $cand if $cand.defined;
    }
    Nil
}

sub read-csv-safe(Str $path, :$sep = ',') {
    my $csv = Text::CSV.new(:separator($sep));
    try {
        my $fh  = open $path, :r;
        LEAVE { $fh.close if $fh }
        my $hdr = $csv.getline($fh) or return Nil;
        my @rows;
        while my $r = $csv.getline($fh) {
            @rows.push($r.Array);
        }
        return $hdr.Array, @rows;
    }
    CATCH { default { diag "read-csv-safe error: $_" } }
    Nil
}

sub pdf-lite-available() {
    my $ok = True;
    CATCH { default { $ok = False } }
    try require ::('PDF::Lite');
    $ok
}

# Read --help text and return combined out+err
sub help-text(IO::Path $exe --> Str) {
    my $p = run $exe.Str, "--help", :out, :err;
    return $p.out.slurp-rest ~ $p.err.slurp-rest;
}

sub csv-flag-for(Str $help --> Str) {
    return '--csv'   if $help.contains('--csv');
    return '--file'  if $help.contains('--file');
    return '--input' if $help.contains('--input');
    ''
}

# Run a candidate argv; feed stdin if provided
sub run-cmd(@argv, Str :$stdin = "") {
    my $p = run |@argv, :in, :out, :err;
    if $stdin.chars { $p.in.print($stdin) andthen $p.in.close }
    my $out = $p.out.slurp-rest;
    my $err = $p.err.slurp-rest;
    my $ec  = $p.exitcode // -1;
    return $ec, $out, $err;
}

# -------- locate bins --------
my $kiosk  = find-exe-matching('csvk-kiosk','csv-kiosk','kiosk');
ok $kiosk.defined, "found kiosk bin" or diag "No kiosk-like executable in ./bin";

my $report = find-exe-matching('csvk-report','csv-report','report');
ok $report.defined, "found report bin" or diag "No report-like executable in ./bin";

if !$kiosk or !$report {
    diag "Skipping remaining tests because required executables were not found.";
    done-testing; exit 0;
}

# -------- seed CSV --------
my $tmpdir = "t/tmp".IO; $tmpdir.mkdir unless $tmpdir.e;
my $csv = $tmpdir.add("attendees.csv").Str;
spurt $csv, "name,email\nAlice,alice\@example.com\nBob,bob\@example.com\n";
ok $csv.IO.e, "seed CSV created at $csv";

# -------- kiosk run --------
my $stdin = "Charlie\ncharlie\@example.com\nq\n";
my $khelp = help-text($kiosk);
my $kflag = csv-flag-for($khelp);
my @kargs = $kflag.chars ?? [$kiosk.Str, $kflag, $csv] !! [$kiosk.Str, $csv];
my ($kec,$kout,$kerr) = run-cmd(@kargs,:$stdin);
is $kec,0,"kiosk run exitcode ok";
diag "kiosk stderr:\n$kerr" if $kerr.chars;
diag "kiosk stdout:\n$kout" if $kout.chars;

my $parsed = read-csv-safe($csv);
ok $parsed.defined, 'CSV parsed after kiosk run';
if $parsed.defined {
    my ($hdr,@rows) = $parsed;
    ok @rows.grep({ .[0] eq 'Charlie' and .[1] eq 'charlie@example.com' }).elems==1,
       "kiosk appended expected row";
}

# -------- sort --------
my $rhelp = help-text($report);
my $rflag = csv-flag-for($rhelp);
my @sargs = $rflag.chars ?? [$report.Str,"sort",$rflag,$csv,"--by","name"]
                        !! [$report.Str,"sort",$csv,"--by","name"];
my ($sec,$sout,$serr)=run-cmd(@sargs);
is $sec,0,"report sort exitcode ok";
diag "report stderr:\n$serr" if $serr.chars;

# -------- pdf --------
my $out = $tmpdir.add("attendees.pdf").Str;
if pdf-lite-available() {
    my @pargs = $rflag.chars ?? [$report.Str,"pdf",$rflag,$csv,"--out",$out,"--title","Attendees"]
                             !! [$report.Str,"pdf",$csv,"--out",$out,"--title","Attendees"];
    my ($pec,$pout,$perr)=run-cmd(@pargs);
    is $pec,0,"report pdf exitcode ok";
    ok $out.IO.e && $out.IO.s>0,"pdf file exists";
    diag "report pdf stderr:\n$perr" if $perr.chars;
} else {
    skip "PDF::Lite not available",2;
}

done-testing;
