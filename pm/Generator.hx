package pm;

import haxe.ds.Option;

//use this for macros or other classes
@:forward
abstract Generator<T> (GeneratorObject<T>) from GeneratorObject<T> {
    /**
      build an Iterable<T> from [this] Generator<T>
     **/
    @:runtime @:to
    public function iterable():Iterable<T> {
        var g:Generator<T> = this;
        var que:Array<T> = new Array();
        var nxt:Option<T> = None;

        function processStep() {
            switch (g.next()) {
                case Fail(err):
                    throw err;

                case Link(x, tail):
                    que.push(x);
                    g = tail;

                case End:
                    return ;
            }
        }

        function processQue() {
            if (nxt.match(Some(_))) {
                return true;
            }
            else {
                if (que.length > 0) {
                    nxt = Some(que.shift());
                    return true;
                }
                else {
                    if ( !g.depleted ) {
                        processStep();
                        return processQue();
                    }
                    else {
                        return false;
                    }
                }
            }
        }

        function hasNext() {
            return processQue();
        }
        function next():T {
            return switch (nxt) {
                case Some(value):
                    nxt = None;
                    value;

                case None:
                    throw 'Should not be possible';
            }
        }

        return {
            iterator: () -> {
                hasNext: hasNext,
                next: next
            }
        };
    }

    public static inline function empty<T>():Generator<T> return Empty.make();

    @:from
    public static function single<T>(v: T):Generator<T> { return Single.make(v); }
    
    @:from
    public static inline function join<T>(gens: Array<Generator<T>>):Generator<T> {
        return Compound.make( gens );
    }
}

interface GeneratorObject<T> {
    function next():Step<T>;
    function forEach(h: Handler<T>):Conclusion<T>;
    function regroup<O>(regrouper: Regrouper<T>):RegroupResult<T>;

    function decompose(into: Array<Generator<T>>):Void;

    var depleted(get, never):Bool;
    //
}

class Empty<T> extends GeneratorBase<T> {
    function new() {}
    override function get_depleted() return true;
    override function next() return Step.End;
    override function forEach(h: Handler<T>):Conclusion<T> {
        return Conclusion.Depleted;
    }
    
    // add nothing
    override function decompose(into: Array<Generator<T>>) {
        return ;
    }

    public static inline function make<T>():Empty<T> {
        return new Empty();
    }
}

class Single<T> extends GeneratorBase<T> {
    public var value(default, null): T;
    function new(v) {
        this.value = v;
    }
    override function next() return Step.Link(value, Empty.make());
    override function forEach(h: Handler<T>):Conclusion<T> {
        return switch h.apply( value ) {
            case Handled.BackOff: Conclusion.Halted(this);
            case Handled.Finish: Conclusion.Halted(Empty.make());
            case Handled.Resume: Conclusion.Depleted;
            case Handled.Errored(err): Conclusion.Failed(err);
        }
    }
    public static function make<T>(val: T):Single<T> return new Single(val);
}

class Compound<T> extends GeneratorBase<T> {
    public var parts(default, null): Array<Generator<T>>;
    private var c(default, null): Int = 0;
    function new(vals) {
        this.parts = vals;
    }
    override function get_depleted() {
        return switch parts.length {
            case 0: true;
            case 1: parts[0].depleted;
            default: false;
        }
    }
    override function next():Step<T> {
        if (parts.length == 0) return End;
        switch parts[0].next() {
            case End:
                parts.shift();
                return next();

            case Fail(err):
                return Fail(err);

            case Link(v, tail):
                parts[0] = tail;
                return Link(v, this);
        }
    }
    override function forEach(h: Handler<T>):Conclusion<T> {
        if (parts.length == 0) return Depleted;
        switch (parts[0].forEach( h )) {
            case Depleted:
                parts.shift();
                return forEach( h );

            case Halted(rest):
                parts[0] = rest;
                return Halted(new Compound(parts));

            case Failed(err):
                return Failed(err);

            case Clog(err, at):
                if (at.depleted) {
                    //return Clog(err, new Compound())
                    parts = parts.slice( 1 );
                }
                else {
                    parts[0] = at;
                }
                return Clog(err, new Compound(parts));
        }
    }

    override function decompose(into: Array<Generator<T>>) {
        for (s in parts)
            s.decompose(into);
    }

    public static function make<T>(gens: Array<Generator<T>>):Generator<T> {
        var parts = [];
        for (g in gens)
            g.decompose(parts);
        return new Compound( parts );
    }
}

class FwdGenerator<T> extends GeneratorBase<T> {
    var generator(default, null): Null<GeneratorObject<T>>;

    function new(g) {
        generator = g;
    }

    override function next():Step<T> return generator.next();
    override function forEach(h: Handler<T>):Conclusion<T> return generator.forEach( h );
    override function decompose(into: Array<Generator<T>>) return generator.decompose( into );

    override function get_depleted() return generator.depleted;
}

@:allow(pm.Generator.GeneratorObject)
class GeneratorBase<T> implements GeneratorObject<T> {
    public function next():Step<T> {
        throw 'Not implemented';
    }

    public function forEach(handler: Handler<T>):Conclusion<T> {
        throw 'Not implemented';
    }

    public function decompose(into: Array<Generator<T>>) {
        into.push( this );
    }

    public var depleted(get, never):Bool;
    function get_depleted() return false;
}

enum Step<T> {
    Link(value:T, next:Generator<T>);
    Fail(error: Dynamic);
    End;
}

enum Handled<T> {
    BackOff;
    Finish;
    Resume;
    Errored(err: Dynamic);
}

enum Conclusion<T> {
    Halted(rest: Generator<T>);
    Clog(err:Dynamic, at:Generator<T>);
    Failed(err:Dynamic);
    Depleted;
}

enum RegroupStatus {
    Ended;
    Flowing;
    Errored(e: Error);
}

enum RegroupResult<O> {
    Converted(data: Generator<O>): RegroupResult<O>;
    Terminated(data: Option<Generator<O>>): RegroupResult<O>;
    Untouched(): RegroupResult<O>;
    Errored<Error>(e: Error): RegroupResult<O, Error>;
}

abstract Handler<T> (T -> Handled<T>) from T -> Handled<T> to T -> Handled<T>{
    public inline function apply(item: T):Handled<T> {
        return this( item );
    }
}

@:forward
abstract Regrouper<I,O,Q> (RegrouperBase<I,O,Q>) from RegrouperBase<I,O,Q> to RegrouperBase<I,O,Q> {
    @:from
    public static function make<In, Out, Q>(f: Array<In> -> RegroupStatus<Q> -> RegroupResult<Out, Q>):Regrouper<In, Out, Q> {
        return new RegrouperBase( f );
    }

    @:from
    public static function sync<In, Out, Q>(f: Array<In> -> RegroupStatus<Q> -> RegroupResult<Out, Q>):Regrouper<In, Out, Q> {
        return make(function(i, s) {
            return f(i, s);
        });
    }

    @:from
    public static function makeNoStatus<In, Out, Q>(f: Array<In>->Next<RegroupResult<Out, Q>>):Regrouper<In, Out, Q> {
        return make(function(i, _) return f(i));
    }

    @:from
    public static function syncNoStatus<In, Out, Q>(f: Array<In>->RegroupResult<Out, Q>):Regrouper<In, Out, Q> {
        return sync(function(i, _) return f(i));
    }
}

class RegrouperBase<I, O, Q> {
    /* Constructor Function */
    public function new(fn: (i:Array<I>, rs:RegroupStatus<Q>) -> RegroupResult<O, Q>) {
        this.apply = fn;
    }

/* === Instance Methods === */

    public dynamic function apply(input:Array<I>, status:RegroupStatus<Q>):RegroupResult<O, Q> {
        throw 'Not Implemented';
    }
}
