
use v6;
use Test;
use Text::CSV;

plan *;  # flexible

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

# Try a sequence of argv variants until one returns exit 0.
sub run-one(@argv --> List) {
    my $p = run |@argv, :in, :out, :err;
    return ($p.exitcode // -1, $p.out.slurp-rest, $p.err.slurp-rest);
}

sub try-argv(@variants, Str :$stdin = "") {
    for @variants -> @argv {
        my ($ec, $out, $err) = run-one(@argv);
        if $stdin.chars {
            # If the proc wants input, re-run with input
            my $p = run |@argv, :in, :out, :err;
            $p.in.print($stdin);
            $p.in.close;
            $out = $p.out.slurp-rest;
            $err = $p.err.slurp-rest;
            $ec  = $p.exitcode // -1;
        }
        return (True, @argv, $out, $err) if $ec == 0;
        diag "Variant failed (exit {$ec}): {@argv.join(' ')}\nstderr:\n$err\nstdout:\n$out";
    }
    return (False, [], "", "");
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

# -------- run kiosk (try both --csv and positional) --------
my $stdin = "Charlie\ncharlie\@example.com\nq\n";
my @kiosk-variants = (
    [$kiosk.Str, "--csv", $csv],
    [$kiosk.Str, $csv],
);
my ($ok1, @argv1, $kout, $kerr) = try-argv(@kiosk-variants, :$stdin);
ok $ok1, "kiosk run completed OK" or diag "All kiosk variants failed";

# verify appended row
my $parsed = read-csv-safe($csv);
ok $parsed.defined, 'CSV parsed after kiosk run';
if $parsed.defined {
    my ($hdr, @rows) = $parsed;
    my $added = @rows.grep({ .[0] eq 'Charlie' and .[1] eq 'charlie@example.com' }).elems;
    ok $added == 1, 'kiosk appended expected row' or diag "Rows now: " ~ @rows.map(*.join(',')).join(' | ');
}

# -------- sort (try a few CLI layouts) --------
my @sort-variants = (
    [$report.Str, "sort", "--csv", $csv, "--by", "name"],
    [$report.Str, "--csv", $csv, "sort", "--by", "name"],
    [$report.Str, "sort", $csv, "--by", "name"],
    [$report.Str, "sort", "--by", "name", $csv],
);
my ($ok2, @argv2, $sout, $serr) = try-argv(@sort-variants);
ok $ok2, "report sort completed OK" or diag "All sort variants failed";

# -------- pdf (similar flexibility) --------
my $out = $tmpdir.add("attendees.pdf").Str;
if pdf-lite-available() {
    my @pdf-variants = (
        [$report.Str, "pdf", "--csv", $csv, "--out", $out, "--title", "Attendees"],
        [$report.Str, "--csv", $csv, "pdf", "--out", $out, "--title", "Attendees"],
        [$report.Str, "pdf", $csv, "--out", $out, "--title", "Attendees"],
        [$report.Str, "pdf", "--out", $out, "--title", "Attendees", $csv],
    );
    my ($ok3, @argv3, $pout, $perr) = try-argv(@pdf-variants);
    ok $ok3, "report pdf completed OK" or diag "All pdf variants failed";
    if $ok3 {
        ok $out.IO.e and $out.IO.s > 0, 'pdf file exists and is non-empty'
            or diag "No PDF at {$out}. stderr:\n$perr\nstdout:\n$pout";
    } else {
        skip "pdf step failed; no file to check", 1;
    }
} else {
    skip "PDF::Lite not available; skipping PDF checks", 2;
}

done-testing;
