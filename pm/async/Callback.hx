package pm.async;

import pm.Noise;
import pm.Assert.assert;
import pm.Error;

@:forward
@:callable
abstract Callback<T> (T -> Void) from (T -> Void) {
    /* Constructor Function */
    public inline function new(fn) {
        this = fn;
    }

    @:to
    inline function toFunction():T->Void return this;

    static var depth = 0;
    static inline var MAX_DEPTH = #if (interp && !eval) 100 #elseif python 200 #else 1000 #end;

    /**
      call [this] callback
     **/
    public function invoke(data: T):Void {
        if (depth < MAX_DEPTH) {
            depth++;
            //TODO: consider handling exceptions here (per opt-in?) to avoid a failing callback from taking down the whole app
            (this)(data);
            depth--;
        }
        else {
            Callback.defer(invoke.bind( data ));
        }
    }

    @:from 
    //inlining this seems to cause recursive implicit casts
    static function fromNiladic<A>(f: Void->Void):Callback<A> {
        return #if js cast f #else function (_) f() #end;
    }

    @:from 
    static function fromMany<A>(callbacks:Array<Callback<A>>):Callback<A> {
        return function (v: A) {
            for (callback in callbacks)
                callback.invoke( v );
        }
    }

    @:noUsing 
    static public inline function defer(fn: Void->Void):Void {
        // pm.concurrent.RunLoop.current.work( fn );
        #if macro
            fn();
        #elseif tink_runloop
            tink.RunLoop.current.work( fn );
        #elseif hxnodejs
            js.Node.process.nextTick( fn );
        #elseif luxe
            Luxe.timer.schedule(0, fn);
        #elseif snow
            snow.api.Timer.delay(0, fn);
        #elseif java
            //TODO: find something that leverages the platform better
            haxe.Timer.delay(fn, 1);
        #elseif ((haxe_ver >= 3.3) || js || flash || openfl)
            haxe.Timer.delay(fn, 0);
        #else
            f();
        #end
    }
}

interface LinkObject {
    function cancel():Void;
}


abstract CallbackLink(LinkObject) from LinkObject {
    inline function new(link: Void->Void) {
        this = new SimpleLink( link );
    }

    public inline function cancel():Void {
        if (this != null) {
            this.cancel();
        }
    }

    @:deprecated('Use cancel() instead')
    public inline function dissolve():Void {
        cancel();
    }

    static function noop() {}

    @:to 
    inline function toFunction():Void->Void {
        return if (this == null) noop else this.cancel;
    }

    @:to 
    inline function toCallback<A>():Callback<A> {
        return function (_) this.cancel();
    }
    @:from static inline function ofLink(lo: LinkObject):CallbackLink {
        return (untyped lo : CallbackLink);
    }

    @:from 
    static inline function fromFunction(fn: Void->Void) {
        return new CallbackLink( fn );
    }
    @:from
    static inline function fromAnon(dlo: DynLinkObject):CallbackLink {
        return AnonLink.make(dlo);
    }

    @:op(a & b)
    static public inline function join(a:CallbackLink, b:CallbackLink):CallbackLink {
        return new LinkPair(a, b);
    }

    @:from 
    static public function fromMany(callbacks: Array<CallbackLink>) {
        return fromFunction(function () for (cb in callbacks) cb.cancel());
    }
}

typedef DynLinkObject = {function cancel():Void;};
class AnonLink implements LinkObject {
    var d: DynLinkObject;
    function new(dlo: DynLinkObject) {
        d = dlo;
    }
    public function cancel() {
        if (d != null && d.cancel != null)
            d.cancel();
    }
    public static function make(anon: DynLinkObject):AnonLink {
        assert(!Std.is(anon, LinkObject), 'disallow');
        return new AnonLink(anon);
    }
}
class DynLink implements LinkObject {
    var d: Dynamic;
    public function new(dlo: Dynamic) {
        assert(
            dlo != null &&
            Reflect.hasField(dlo, 'cancel') &&
            Reflect.isFunction(dlo.cancel),
            '$dlo should be {function cancel();}'
        );
        this.d = dlo;
    }
    public function cancel():Void {
        try {
            Reflect.callMethod(d, Reflect.getProperty(d, 'cancel'), []);
        }
        catch (e: Dynamic) {
            #if js untyped console.error(e); #end
            trace('DynLink($d).cancel() threw an error...');
            throw e;
        }
    }
}

private class SimpleLink implements LinkObject {
    var fn: Void->Void;
    public inline function new(f) {
        fn = f;
    }

    public inline function cancel() {
        if (fn != null) {
            fn();
            fn = null;
        }
    }
}

class FwdLink implements LinkObject {
    var link(default, null): LinkObject;
    function new(l) {
        link = l;
    }

    public function cancel() {
        if (link != null) {
            link.cancel();
            link = null;
        }
    }
}

private class LinkPair implements LinkObject {
    var a:CallbackLink;
    var b:CallbackLink;
    var dissolved:Bool = false;

    public inline function new(a, b) {
        this.a = a;
        this.b = b;
    }

    public function cancel() {
        if ( !dissolved ) {
            dissolved = true;
            a.cancel();
            b.cancel();
            a = null;
            b = null;
        }
    }
}

private class ListCell<T> implements LinkObject {
    private var list: Array<ListCell<T>>;
    private var cb: Callback<T>;

    public function new(cb, list) {
        if (cb == null) 
            throw new Error('[cb] argument cannot be null');
        this.cb = cb;
        this.list = list;
    }

    public inline function invoke(data) {
        if (cb != null) 
            cb.invoke( data );
    }

    public function clear() {
        list = null;
        cb = null;
    }

    public function cancel() {
        switch list {
            case null:
                //
            case v:
                clear();
                v.remove( this );
        }
    }
}

/**
  abstract utility type
 **/
abstract CallbackList<T> (Array<ListCell<T>>) from Array<ListCell<T>> {

    inline public function new():Void {
        this = [];
    }

    public var length(get, never):Int;
    private inline function get_length():Int return this.length;  

    @:arrayAccess
    public function get(index: Int):ListCell<T> {
        assert((index >= 0 && index < length && Math.isFinite( index )), haxe.io.Error.OutsideBounds);
        return this[index];
    }

    public function add(cb: Callback<T>):CallbackLink {
        //var node = new ListCell(cb, this);
        //this.push(node);
        //return node;
        return this[this.push(new ListCell(cb, this)) - 1];
    }

    public function pre(cb: Callback<T>):CallbackLink {
        this.unshift(new ListCell(cb, this));
        return this[0];
    }

    //@:access(pmdb.async.Callback.Callback)
    public function copy():CallbackList<T> {
        var m:Array<ListCell<T>> = @:privateAccess this.map(cell -> new ListCell(cell.cb, this));
        for (idx in 0...length) @:privateAccess{
            m[idx].list = m;
        }
        return m;
    }

    public function invoke(data: T) {
        for (cell in this.copy()) {
            cell.invoke( data );
        }
    }

    public function clear():Void {
        for (cell in this.splice(0, this.length)) {
            cell.clear();
        }
    }

    public function invokeAndClear(data: T) {
        for (cell in this.splice(0, this.length)) {
            cell.invoke( data );
        }
    }
}
