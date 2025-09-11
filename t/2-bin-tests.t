
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

# sort (flags first, subcommand last)
my $scmd = sprintf("%s %s bin/csvk-report --csv=%s sort --by=name",
                   raku, libopt, $csv.subst("'", "'\"'\"'", :g));
my ($sec,$sout,$serr) = sh-run($scmd, :label("sort"));
diag "sort stderr:\n{$serr}" if $serr.chars;
is $sec, 0, "report sort exited cleanly (shell)" or diag "sort stdout:\n{$sout}";

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
