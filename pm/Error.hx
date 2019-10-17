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
        return '' + position + ': ' + switch message {
            case '': name;
            case _: '$name: $message';
        }
    }


/* === Instance Fields === */

    public var name(default, null): String;
    public var message(default, null): String;
    public var position(default, null): PosInfos;

/* === Statics === */

    public static function fromDynamic(x:Dynamic, ?pos:PosInfos):Error {
        if (Std.is(x, Error))
            return cast x;
        return new ErrorWrapper(""+x, x, pos);
    }
    public static function wrapDynamic(x:Dynamic, ?pos:PosInfos):Error {
        return switch Type.typeof(x) {
            case TClass(_)|TObject|TUnknown:
                @:privateAccess {
                    var err = fromDynamic(x, pos);
                    err.name = Helpers.nor(Reflect.getProperty(x, 'name'), err.name);
                    err.message = Helpers.nor(Reflect.getProperty(x, 'message'), err.message);
                    err;
                }
            case _: fromDynamic(x);
            // case 
        }
    }
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

class InvalidOperation<T> extends Error {
    private var _op(default, null): T;
    public var op(default, null): String;

    public function new(op, ?msg, ?type, ?pos) {
        super(msg, type, pos);
        this._op = op;
        this.op = '$_op';
    }
}

class ErrorWrapper extends pm.Error {
    public var innerError: Dynamic;
    
    public function new(message:String, inner, ?pos) {
        super(message, null, pos);
        this.innerError = inner;
    }
}