package pm.async.impl;

import pm.Error.WTFError;
import pm.async.impl.PromiseObject;
import pm.async.impl.AsyncPromiseObject;
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
    public var execute: AsyncPromiseExecutor<T>;
    public var status: LazyPromiseStatus<T>;
    public var asyncStatus: AsyncPromiseStatus<T>;

    function new() {
        execute = noop;
        status = Waiting;
    }

    private static inline function asyncStatusFromStatus<T>(status: LazyPromiseStatus<T>):Null<AsyncPromiseStatus<T>> {
        return switch status {
            case Waiting: null;
            case Pending: AsyncPromiseStatus.Pending;
            case Cancelled: throw new pm.Error('Unreachable');
            case Resolved(outcome): AsyncPromiseStatus.Resolved;
        }
    }

    private function exec() {
		var _resolve:Callback<Outcome<T, Dynamic>> = noop;
		_resolve = function(o:Outcome<T, Dynamic>) {
            this.status = Resolved(o);
            _resolve = function(o: Outcome<T, Dynamic>) {
                throw new WTFError();
            };
        };
        this.execute(_resolve);
    }

    public function run() {
        switch status {
            case Waiting:
                this.status = Pending;
                this.exec();

            default:
                throw new pm.Error('Invalid Promise Status: $status');
        }
    }
}

enum LazyPromiseStatus<T> {
    Waiting;
    Pending;
    Cancelled;
    Resolved(outcome: Outcome<T, Dynamic>);
}