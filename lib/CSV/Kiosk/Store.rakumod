use v6;
unit module CSV::Kiosk::Store;
use CSV::Kiosk::Record;

class Store is export {
    has Str  $.sep    = ',';
    has List @.header = <name email>;
    has Record %.by-key;

    method load(Str $path) {
        die "No CSV at $path" unless $path.IO.e;
        my @lines = $path.IO.lines;
        die "CSV empty: $path" unless @lines;
        @.header = @lines.shift.split($!sep).map(*.trim);
        for @lines -> $line {
            next unless $line.chars;
            my @vals = $line.split($!sep);
            my $rec  = Record.from-row(@.header, @vals);
            %.by-key{$rec.key} = $rec if $rec.key.chars;
        }
        self
    }

    method save(Str $path) {
        my @rows = %.by-key.values.map(*.as-row(@.header));
        spurt $path,
          @.header.join($!sep) ~ "\n" ~
          @rows.map(*.join($!sep)).join("\n") ~ "\n";
        $path
    }

    method backup(Str $path --> Str) {
        my $bak = $path ~ '.' ~ DateTime.now.posix;
        $path.IO.copy($bak);
        $bak
    }

    method add(Record $rec, :$replace = False) {
        my $k = $rec.key;
        return False unless $k.chars;
        if !$replace {
            return False if %.by-key{$k}:exists;
        }
        %.by-key{$k} = $rec;
        True
    }

    method sorted(:$by = 'name', :$cmp = &infix:<leg>) {
        my &pick = $by eq 'email'
            ?? -> $r { $r.email // '' }
            !! -> $r { $r.name  // '' };

        %.by-key.values.sort( -> $a, $b { 
            $cmp( pick($a),  pick($b))
        } )
    }
}
