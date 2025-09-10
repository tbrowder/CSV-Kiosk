
#!/usr/bin/env raku
use CSV::Kiosk :ALL;

sub MAIN(
    Str :$csv! where *.IO.f,      # path to CSV with header
    Str :$sep = ',',              # custom separator if needed
) {
    interactive-session($csv, :$sep);
}
