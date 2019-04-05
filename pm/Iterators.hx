package pm;

import pm.iterators.*;

class Iterators {
    public static function reduce<T, TAcc>(it:Iterator<T>, fn:TAcc->T->TAcc, init:TAcc):TAcc {
        for (x in it)
            init = fn(init, x);
        return init;
    }

    public static function reduceInit<T>(it:Iterator<T>, fn:T->T->T):Null<T> {
        if (!it.hasNext()) return null;
        else {
            var agg = it.next();
            return if (it.hasNext()) reduce(it, fn, agg) else agg;
        }
    }

    public static function forEach<T>(it:Iterator<T>, fn:T -> Void) {
        for (x in it)
            fn( x );
    }

    public static inline function map<TIn, TOut>(it:Iterator<TIn>, fn:TIn->TOut):Iterator<TOut> {
        return new MappedIterator(it, fn);
    }

    public static inline function append<T>(a:Iterator<T>, b:Iterator<T>):Iterator<T> {
        return IteratorIterator.of([a, b]);
    }

    public static inline function flatten<T>(a: Iterator<Iterator<T>>):Iterator<T> {
        return new IteratorIterator( a );
    }

    public static inline function flatMap<A, B>(i:Iterator<A>, fn:A->Iterator<B>):Iterator<B> {
        return flatten(map(i, fn));
    }

    public static function zip<A, B, C>(a:Iterator<A>, b:Iterator<B>, fn:Null<A>->Null<B>->C):Iterator<C> {
        return {
            hasNext:()->(a.hasNext() || b.hasNext()),
            next: function() {
                return fn(
                    if (a.hasNext()) a.next() else null,
                    if (b.hasNext()) b.next() else null
                );
            }
        }
    }
}
