use v6;
unit module CSV::Kiosk::Record;

class Record is export {
    has Str $.name is rw;
    has Str $.email is rw;
    has Hash $.extra is rw = {}
 
    # "Alphabetic" key: letters/digits only, lowercased,
    method key(--> Str) {
        ($!name // '').trans(' ' => '').lc.subst(/<-[a..z 0..9]>+/, '', :g)
    }

    # Build from header list + row values (no quoting;
    method from-row(@header, @vals --> Record) {
        my %h = @header Z=> @vals>>.trim;
        self.bless(
            :name(%h<name> // ''),
            :email(%h<email> // ''),
            :extra(%h.grep({ .key ne 'name' and .key ne 'email' }).Hash),
        );
    }

    method as-row(@header --> List) {
        @header.map({
            $_ eq 'name' ?? $.name 
                         !! $_ eq 'email' ?? $.email 
                                          !! ($.extra{$_} // '')
        })
    }

    method Str() {
        "{$.name} <{$.email}>"
    }

}

