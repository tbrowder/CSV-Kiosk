
use v6;
use Test;
use Text::CSV;

plan *;  # flexible test count

# -------- helpers --------
sub raku() { $*EXECUTABLE.Str }          # path to the running raku
sub libopt() { "-Ilib" }                 # ensure local lib/ is on REPO chain

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
    my $p = run raku, libopt, $exe.Str, "--help", :out, :err;
    return $p.out.slurp-rest ~ $p.err.slurp-rest;
}

sub csv-flag-for(Str $help --> Str) {
    return '--csv'        if $help.contains('--csv');
    return '--file'       if $help.contains('--file');
    return '--input'      if $help.contains('--input');
    return '--csv-file'   if $help.contains('--csv-file');
    return '--data'       if $help.contains('--data');
    return '--path'       if $help.contains('--path');
    ''
}

# Run a candidate argv under raku -Ilib; feed stdin if provided; return (ec,out,err)
sub run-cmd(@argv, Str :$stdin = "") {
    my $p = run raku, libopt, |@argv, :in, :out, :err;
    if $stdin.chars { $p.in.print($stdin) andthen $p.in.close }
    my $out = $p.out.slurp-rest;
    my $err = $p.err.slurp-rest;
    my $ec  = $p.exitcode // -1;
    return $ec, $out, $err;
}

# Try many arg patterns; return first success
sub try-variants(@variants, Str :$stdin = "") {
    my ($last-out,$last-err) = "","";
    for @variants -> @argv {
        my ($ec,$out,$err) = run-cmd(@argv, :$stdin);
        $last-out = $out; $last-err = $err;
        if $ec == 0 {
            return True, @argv, $out, $err;
        } else {
            diag "Variant failed (ec={$ec}): raku -Ilib {@argv.join(' ')}\n---stderr---\n$err\n---stdout---\n$out";
        }
    }
    return False, [], $last-out, $last-err;
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
my $khelp = help-text($kiosk); diag "kiosk --help:\n$khelp" if $khelp.chars;
my $kflag = csv-flag-for($khelp);

# Prefer --csv=<file> if help shows --csv
my @kiosk-variants =
    $kflag eq '--csv' ?? (
        [$kiosk.Str, "--csv={$csv}"],
        [$kiosk.Str, $csv],
    )
    !! (
        $kflag.chars ?? ( [$kiosk.Str, "{$kflag}={$csv}"], [$kiosk.Str, $kflag, $csv] )
                     !! ( [$kiosk.Str, $csv], [$kiosk.Str, "--csv", $csv] )
    );

my ($k-ok, @k-argv, $kout, $kerr) = try-variants(@kiosk-variants, :$stdin);
ok $k-ok, "kiosk run completed OK" or diag "kiosk stderr (last):\n$kerr\nstdout:\n$kout";

# verify appended row
my $parsed = read-csv-safe($csv);
ok $parsed.defined, 'CSV parsed after kiosk run';
if $parsed.defined {
    my ($hdr,@rows) = $parsed;
    ok @rows.grep({ .[0] eq 'Charlie' and .[1] eq 'charlie@example.com' }).elems==1,
       "kiosk appended expected row" or diag "Rows now: " ~ @rows.map(*.join(',')).join(' | ');
}

# -------- report sort --------
my $rhelp = help-text($report); diag "report --help:\n$rhelp" if $rhelp.chars;
my $rflag = csv-flag-for($rhelp);

my @sort-variants =
    $rflag eq '--csv' ?? (
        [$report.Str, "sort", "--csv={$csv}", "--by", "name"],
        [$report.Str, "sort", $csv, "--by", "name"],
    )
    !! (
        $rflag.chars ?? ( [$report.Str, "sort", "{$rflag}={$csv}", "--by", "name"],
                          [$report.Str, $rflag, $csv, "sort", "--by", "name"] )
                     !! ( [$report.Str, "sort", $csv, "--by", "name"],
                          [$report.Str, "sort", "--by", "name", $csv] )
    );

my ($s-ok, @s-argv, $sout, $serr) = try-variants(@sort-variants);
ok $s-ok, "report sort completed OK" or diag "report sort stderr (last):\n$serr\nstdout:\n$sout";

# -------- report pdf --------
my $out = $tmpdir.add("attendees.pdf").Str;
if pdf-lite-available() {
    my @pdf-variants =
        $rflag eq '--csv' ?? (
            [$report.Str, "pdf", "--csv={$csv}", "--out", $out, "--title", "Attendees"],
            [$report.Str, "pdf", $csv, "--out", $out, "--title", "Attendees"],
        )
        !! (
            $rflag.chars ?? ( [$report.Str, "pdf", "{$rflag}={$csv}", "--out", $out, "--title", "Attendees"],
                              [$report.Str, $rflag, $csv, "pdf", "--out", $out, "--title", "Attendees"] )
                         !! ( [$report.Str, "pdf", $csv, "--out", $out, "--title", "Attendees"],
                              [$report.Str, "pdf", "--out", $out, "--title", "Attendees", $csv] )
        );
    my ($p-ok, @p-argv, $pout, $perr) = try-variants(@pdf-variants);
    ok $p-ok, "report pdf completed OK" or diag "All pdf variants failed";
    if $p-ok {
        ok $out.IO.e && $out.IO.s>0, "pdf file exists" or diag "stderr:\n$perr\nstdout:\n$pout";
    } else {
        skip "pdf step failed; no file to check", 1;
    }
} else {
    skip "PDF::Lite not available", 2;
}

done-testing;
