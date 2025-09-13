use v6;
use Test;

plan *;

sub raku()   { $*EXECUTABLE.Str }
sub libopt() { "-Ilib" }

sub sh-run(Str $cmd, Str :$label = "cmd") {
    my $tmpdir = "t/tmp".IO; $tmpdir.mkdir unless $tmpdir.e;
    my $outf = $tmpdir.add("{$label}.out").Str;
    my $errf = $tmpdir.add("{$label}.err").Str;
    my $full = "{$cmd} 1> {$outf} 2> {$errf}";
    my $ps   = shell $full;
    my $ec   = $ps.can('exitcode') ?? $ps.exitcode !! $ps;
    my $out  = $outf.IO.e ?? $outf.IO.slurp !! "";
    my $err  = $errf.IO.e ?? $errf.IO.slurp !! "";
    return $ec, $out, $err;
}

# seed CSV
my $tmpdir = "t/tmp".IO; $tmpdir.mkdir unless $tmpdir.e;
my $csv = $tmpdir.add("attendees.csv").Str;
spurt $csv, "name,email\nAlice,alice\@example.com\nBob,bob\@example.com\nCharlie,charlie\@example.com\n";
ok $csv.IO.e, "seed CSV created at $csv";

# ---------- sort via shell (try both orders) ----------
my $scmd1 = sprintf("%s -Ilib bin/csvk-report sort --csv=%s --by=name",
                    $*EXECUTABLE,
                    $csv.subst("'", "'\\\"'\\\"'", :g));
my $scmd2 = sprintf("%s -Ilib bin/csvk-report --csv=%s sort --by=name",
                    $*EXECUTABLE,
                    $csv.subst("'", "'\\\"'\\\"'", :g));

my $sec = shell "$scmd1 1> t/tmp/sort1.out 2> t/tmp/sort1.err";
$sec = $sec.can('exitcode') ?? $sec.exitcode !! $sec;
if $sec != 0 {
    diag "sort1 (command-first) failed; stderr:\n" ~
        ("t/tmp/sort1.err".IO.e ?? "t/tmp/sort1.err".IO.slurp !! "");
    $sec = shell "$scmd2 1> t/tmp/sort2.out 2> t/tmp/sort2.err";
    $sec = $sec.can('exitcode') ?? $sec.exitcode !! $sec;
    diag "sort2 (flags-first) stderr:\n" ~
        ("t/tmp/sort2.err".IO.e ?? "t/tmp/sort2.err".IO.slurp !! "")
        if $sec != 0;
}
is $sec, 0, "report sort exited cleanly (shell)";


# pdf (positional .text fix in module)
my $pdf = $tmpdir.add("attendees.pdf").Str;
my $pcmd = sprintf("%s %s bin/csvk-report --csv=%s --out=%s --title=%s pdf",
                   raku, libopt,
                   $csv.subst("'", "'\"'\"'", :g),
                   $pdf.subst("'", "'\"'\"'", :g),
                   "Attendees".subst("'", "'\"'\"'", :g));
my ($pec,$pout,$perr) = sh-run($pcmd, :label("pdf"));
diag "pdf stderr:\n{$perr}" if $perr.chars;
is $pec, 0, "report pdf exited cleanly (shell)" or diag "pdf stdout:\n{$pout}";

ok $pdf.IO.e && $pdf.IO.s > 0, "pdf file exists and is non-empty"
  or diag "No PDF at {$pdf}";

done-testing;
