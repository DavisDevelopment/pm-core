package pm;

class Iterators {
    public static function reduce<T, TAcc>(it:Iterator<T>, fn:TAcc->T->TAcc, init:TAcc):TAcc {
        for (x in it)
            init = fn(init, x);
        return init;
    }

    public static function forEach<T>(it:Iterator<T>, fn:T -> Void) {
        for (x in it)
            fn( x );
    }
}
