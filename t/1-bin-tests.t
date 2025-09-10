use Test;

use CSV::Kiosk;
use CSV::Kiosk::Report;

my $prog1 = "csvk-kiosk";
my $prog2 = "csvk-report";

lives-ok {
    run "raku", "-I.", "bin/$prog1";
}, "bin 1: $prog1";

lives-ok {
    run "raku", "-I.", "bin/$prog2";
}, "bin 1: $prog2";




done-testing;
