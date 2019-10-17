package pm.async.impl;

import pm.async.impl.PromiseObject;
import pm.async.impl.Defer;

using pm.async.impl.CommonTypes;

import haxe.ds.Option;
import haxe.extern.EitherType as Or;

using pm.Maybe;
using pm.Lazy;

import pm.Arch;
import pm.Assert.assert;
import pm.Functions.noop;
import pm.Functions.fn as mkfn;

class BaseLazyPromise<T> {
    public var execute: Callback<LazyTrigger<T>>;
    public var status: LazyPromiseStatus<T>;

    function new() {
        execute = noop;
        status = Waiting;
    }

    public function run() {
        switch status {
            case Waiting:
                var trigger = new LazyTrigger();
                // init `trigger`
                execute(trigger);

            default:
                throw new pm.Error('Invalid Promise Status: $status');
        }
    }
}

@:allow(pm.async.impl.LazyPromiseObject.BaseLazyPromise)
class LazyTrigger<T> {
    public var outcome:Option<Outcome<T, Dynamic>> = None;
    public var isResolved(default, null): Bool = false;
    public var isCancelled(default, null): Bool = false;
    
    public function new() {
        //
    }

    public dynamic function resolve(outcome: Outcome<T, Dynamic>):Bool {

    }
    
    @:native('_return')
    public inline function yield(result: T):Void {
        //
    }

}

enum LazyPromiseStatus<T> {
    Waiting;
    Pending;
    Cancelled;
    Resolved(outcome: Outcome<T, Dynamic>);
}