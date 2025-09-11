
use v6;
use Test;
use Text::CSV;

# We avoid Proc::Async and run; only use shell to spawn commands.
plan *;  # flexible, we'll end with done-testing

# ---------- helpers ----------
sub raku() { $*EXECUTABLE.Str }     # current raku
sub libopt() { "-Ilib" }            # ensure local lib is on repo chain

sub find-exe(*@needles --> IO::Path) {
    my $bindir = "bin".IO;
    return Nil unless $bindir.d;
    my @cands = $bindir.dir.grep(*.f);
    for @needles -> $n {
        my $cand = @cands.first({ .basename.lc.contains($n.lc) });
        return $cand if $cand.defined;
    }
    Nil
}

# Run a shell command, capturing exit + logs to tmp files
sub sh-run(Str $cmd, Str :$label = "cmd") {
    my $tmpdir = "t/tmp".IO; $tmpdir.mkdir unless $tmpdir.e;
    my $outf = $tmpdir.add("{$label}.out").Str;
    my $errf = $tmpdir.add("{$label}.err").Str;
    my $full = "{$cmd} 1> {$outf} 2> {$errf}";
    my $ec = shell $full;
    my $out = $outf.IO.e ?? $outf.IO.slurp !! "";
    my $err = $errf.IO.e ?? $errf.IO.slurp !! "";
    return $ec, $out, $err;
}

# ---------- locate report bin (we'll bypass kiosk entirely) ----------
my $report = find-exe('csvk-report','csv-report','report');
ok $report.defined, "found report bin" or diag "No report-like executable in ./bin";
if !$report {
    done-testing; exit 0;
}

# ---------- seed CSV ----------
my $tmpdir = "t/tmp".IO; $tmpdir.mkdir unless $tmpdir.e;
my $csv = $tmpdir.add("attendees.csv").Str;
spurt $csv, "name,email\nAlice,alice\@example.com\nBob,bob\@example.com\n";
ok $csv.IO.e, "seed CSV created at $csv";

# ---------- append one row using *shell* (no Raku subprocess APIs) ----------
# Use printf to avoid extra spaces; mirror your CSV "no quotes" rule.
my $aline = "Charlie,charlie\@example.com";
my $appcmd = sprintf("printf '%s\n' '%s' >> '%s'",
                     $aline.subst("'","'\"'\"'", :g),
                     $aline.subst("'","'\"'\"'", :g),
                     $csv.subst("'","'\"'\"'", :g));
my ($aec,$aout,$aerr) = sh-run($appcmd, :label("append"));
is $aec, 0, "appended a CSV row via shell";

# ---------- sort via shell (through raku -Ilib) ----------
my $scmd = sprintf("%s %s %s sort --csv=%s --by=name",
                   raku, libopt, $report.Str, $csv.subst("'","'\"'\"'", :g));
my ($sec,$sout,$serr) = sh-run($scmd, :label("sort"));
diag "sort cmd: {$scmd}";
diag "sort stderr:\n{$serr}" if $serr.chars;
is $sec, 0, "report sort exited cleanly (shell)" or diag "sort stdout:\n{$sout}";

# ---------- pdf via shell (through raku -Ilib) ----------
my $pdf = $tmpdir.add("attendees.pdf").Str;
my $pcmd = sprintf("%s %s %s pdf --csv=%s --out=%s --title=%s",
                   raku, libopt, $report.Str,
                   $csv.subst("'","'\"'\"'", :g),
                   $pdf.subst("'","'\"'\"'", :g),
                   "Attendees".subst("'","'\"'\"'", :g));
my ($pec,$pout,$perr) = sh-run($pcmd, :label("pdf"));
diag "pdf cmd: {$pcmd}";
diag "pdf stderr:\n{$perr}" if $perr.chars;
is $pec, 0, "report pdf exited cleanly (shell)" or diag "pdf stdout:\n{$pout}";

ok $pdf.IO.e && $pdf.IO.s > 0, "pdf file exists and is non-empty"
  or diag "No PDF at {$pdf}";

done-testing;
