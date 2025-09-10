
use v6;
use Test;

plan 6;

sub find-exe(Str $base --> IO::Path) {
    for "bin/{$base}", "bin/{$base}.raku" -> $p {
        return $p.IO if $p.IO.e;
    }
    die "Cannot find executable {$base}";
}

my $kiosk = find-exe('csvk-kiosk');
ok $kiosk.e, "found kiosk bin";

my $report = find-exe('csvk-report');
ok $report.e, "found report bin";

my $tmpdir = "t/tmp".IO;
$tmpdir.mkdir unless $tmpdir.e;
my $csv = $tmpdir.add("attendees.csv").Str;
spurt $csv, "name,email\nAlice,alice\@ex.com\nBob,bob\@ex.com\n";

my $in = "Charlie\ncharlie\@ex.com\nq\n";
my $p = Proc::Async.new($kiosk.Str, "--csv", $csv);
$p.start; $p.write($in); $p.close-stdin; await $p;
is $p.result.exitcode, 0, "kiosk exited ok";

my $rows = slurp $csv;
ok $rows ~~ /Charlie/, "row added";

my $sp = Proc::Async.new($report.Str, "sort", "--csv", $csv, "--by", "name");
$sp.start; await $sp;
is $sp.result.exitcode, 0, "sort exited ok";
