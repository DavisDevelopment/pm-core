package pm.async;

import pm.Pair;
//import tannus.ds.Delta;
import pm.Lazy;
import pm.Ref;
import pm.async.Signal;

import pm.async.Promise;
import pm.Outcome;
import pm.Error;
import pm.async.Stream;

import haxe.ds.Option;
import haxe.ds.Either;
import haxe.Constraints.Function;
import haxe.extern.EitherType;
//import haxe.macro.Type;
//import haxe.macro.Expr;
//import haxe.macro.Context;

using pm.Arrays;
using pm.Iterators;
using pm.Functions;
using pm.Options;

//using haxe.macro.ExprTools; 
//using haxe.macro.TypeTools;
//using haxe.macro.ComplexTypeTools;
//using tannus.macro.MacroTools;

class StreamBase<Item, Quality> implements StreamObject<Item, Quality> {
    public function next():Next<Step<Item, Quality>> {
        throw 'not implemented';
    }

    public function forEach<Safety>(handler: Handler<Item, Safety>):Next<Conclusion<Item, Safety, Quality>> {
        throw 'not implemented';
    }

    public function destroy() {
        //
    }

    public function decompose(into: Array<Stream<Item, Quality>>) {
        if (!depleted)
            into.push( this );
    }

    public function append(s: Stream<Item, Quality>):Stream<Item, Quality> {
        return depleted ? s : CompoundStream.of([this, s]);
    }

    public function prepend(s: Stream<Item, Quality>):Stream<Item, Quality> {
        return depleted ? s : CompoundStream.of([s, this]);
    }

    public function regroup<O>(regrouper: Regrouper<Item, O, Quality>):Stream<O, Quality> {
        return new RegroupStream(this, regrouper);
    }

    public function map<O>(m: Mapping<Item, O, Quality>):Stream<O, Quality> {
        return regroup( m );
    }

    public function filter(f: Filter<Item, Quality>):Stream<Item, Quality> {
        return regroup( f );
    }

    public function reduce<Safety, Acc>(initial:Acc, reducer:Reducer<Item, Safety, Acc>):Next<Reduction<Item, Safety, Quality, Acc>> {
        return new Promise<Reduction<Item, Safety, Quality, Acc>>(function(accept, reject) {
            forEach(function(item) {
                return reducer.apply(initial, item).map(function(o):Handled<Safety> {
                    return switch o {
                        case Progress(v):
                            initial = v;
                            Resume;

                        case Crash(e):
                            Clog(e);
                    }
                });
            }).then(function(c) {
                switch c {
                    case Failed(e):
                        accept(Reduction.Failed(e));

                    case Depleted:
                        accept(Reduced(initial));

                    case Halted(_):
                        throw 'assert';

                    case Clogged(e, rest):
                        accept(Crashed(e, rest));
                }
            });
        });
    }

    public function blend(other: Stream<Item, Quality>):Stream<Item, Quality> {
        throw 'Not Implemented';
        /*
        return
            if ( depleted )
                other;
            else
                new BlendStream(this, other);
        */
    }

    public var depleted(get, never):Bool;
    function get_depleted() return false;
}
