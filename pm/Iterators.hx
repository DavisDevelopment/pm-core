package pm;

import pm.iterators.*;

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

    public static inline function map<TIn, TOut>(it:Iterator<TIn>, fn:TIn->TOut):Iterator<TOut> {
        return new MappedIterator(it, fn);
    }
}
