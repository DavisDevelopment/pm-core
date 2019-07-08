package pm.state;

import pm.async.Signal;
import pm.async.Callback;

using pm.Functions;

class Value<T> {
    private var state : T;
    private var _change_ : Signal<ValueUpdate<T>>;

    public function new(?state: T) {
        this.state = state;
        this._change_ = new Signal();
    }

    public function get():T {
        return this.state;
    }
    
    public function set(v: T):T {
        this.assign( v );
        return this.get();
    }

    public function assign(state: T) {
        var tmp = this.state;
        this.state = state;

        _schedule_(function() {
            _change_.broadcast(new ValueUpdate(tmp, this.state));
        });
    }

    public function observe():ValueObserver<T> {
        return new ValueObserver(this);
    }

    @:noCompletion
    public dynamic function _schedule_(f: Void->Void):Void {
        _staticDefaultSchedule_( f );
    }

    public static dynamic function _staticDefaultSchedule_(f: Void->Void):Void {
        return Callback.defer( f );
    }
}

class ValueObserver<T> {
    private var value: Value<T>;
    private var listeners: ImmutableList<pm.async.Callback.CallbackLink>;

    public function new(v: Value<T>) {
        value = v;
        listeners = [];
    }

    public function subscribe(f: Callback<ValueUpdate<T>>) {
        @:privateAccess {
            var link = value._change_.on( f );
            listeners = link & listeners;
        }
    }

    public function release() {
        listeners.iter(function(link) {
            link.cancel();
        });
    }
}

//enum ValueUpdate<T> {}
typedef ValueUpdate<T> = pm.Pair<T, T>;