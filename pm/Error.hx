package pm;

import pm.Lazy;
import haxe.ds.Option;

import haxe.PosInfos;

class Error {
    /* Constructor Function */
    public function new(?msg:String, ?type:String, ?position:PosInfos) {
        this.message = msg != null ? msg : '';
        this.name = type != null ? type : Type.getClassName(Type.getClass(this));
        this.position = position;
    }

/* === Instance Methods === */

    @:keep
    public function toString():String {
        return switch message {
            case '': name;
            case _: '$name: $message';
        }
    }


/* === Instance Fields === */

    public var name(default, null): String;
    public var message(default, null): String;
    public var position(default, null): PosInfos;
}

class ValueError<T> extends Error {
    /* Constructor Function */
    public function new(value:T, ?msg, ?type, ?position:PosInfos) {
        super(msg, type, position);

        this.value = value;
    }

    public var value(default, null): T;
}

class NotImplementedError extends Error {}
class WTFError extends Error {}
