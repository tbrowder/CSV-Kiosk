
unit module CSV::Kiosk;
use Text::CSV;
use JSON::Fast;

sub sanitize(Str $s is copy --> Str) is export {
    # Remove surrounding quotes/spaces; normalize internal whitespace.
    $s ~~ s/^ \s* <['"]>? (.*?) <['"]>? \s* $/$0/;
    $s ~~ s:g/\s+/ /;
    # Replace commas to avoid forced CSV quoting; strip remaining quotes
    $s ~~ s:g/\,/ /;
    $s ~~ s:g/\,/ \/ /;
    $s ~~ s:g/<["']>/ /;
    $s.trim;
}

sub read-header(Str:D $csv-file, :$sep = ',') returns List is export {
    my $csv = Text::CSV.new(:separator($sep));
    my $fh  = open $csv-file, :r or die "Cannot open $csv-file for reading";
    my $hdr = $csv.getline($fh) or die "CSV file has no header!";
    $fh.close;
    return $hdr;
}

sub load-rows(Str:D $csv-file, :$sep = ',') returns Array is export {
    my $csv = Text::CSV.new(:separator($sep));
    my $fh  = open $csv-file, :r;
    my $header = $csv.getline($fh);
    my @rows;
    while my $r = $csv.getline($fh) {
        @rows.push(@$r);
    }
    $fh.close;
    @rows
}

sub backup(Str:D $csv-file --> Str) is export {
    my $ts = DateTime.now.strftime("%Y%m%d-%H%M%S");
    my $bak = "{$csv-file}.{$ts}.bak.csv";
    spurt $bak, slurp $csv-file;
    $bak
}

sub is-duplicate(@header, @existing, @new-row) returns Bool is export {
    # Simple duplicate: entire row matches existing row after sanitize
    my @clean-new = @new-row.map({ sanitize(.Str) });
    for @existing -> @row {
        my @clean = @row.map({ sanitize(.Str) });
        return True if @clean eqv @clean-new;
    }
    False
}

sub append-row(Str:D $csv-file, @row, :$sep = ',') is export {
    my $csv = Text::CSV.new(:separator($sep));
    my $fh  = open $csv-file, :a;
    $csv.print($fh, @row);
    $fh.say;
    $fh.close;
}

sub interactive-session(Str:D $csv-file, :$sep = ',') is export {
    my @header = read-header($csv-file, :$sep);
    my @existing = load-rows($csv-file, :$sep);
    my $bak = backup($csv-file);
    say "Backup written to: $bak";
    say "Fields: " ~ @header.join(', ');
    say "---------------------------------------";
    loop {
        my @row;
        for @header -> $field {
            print "{$field}: ";
            my $val = $*IN.get // '';
            $val = sanitize($val);
            @row.push($val);
        }
        if is-duplicate(@header, @existing, @row) {
            say "!! Duplicate detected. Record NOT added.";
        } else {
            append-row($csv-file, @row, :$sep);
            @existing.push(@row);
            say "✓ Record added.";
        }
        say "---------------------------------------";
        print "Next entry? (Enter to continue, 'q' to quit): ";
        my $ans = $*IN.get // '';
        last if $ans.lc eq 'q';
    }
}
