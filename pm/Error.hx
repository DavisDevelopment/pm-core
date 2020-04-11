package pm;

import pm.Lazy;
import haxe.ds.Option;

import haxe.PosInfos;

class Error {
    /* Constructor Function */
    public function new(?msg:String, ?type:String, ?position:PosInfos) {
        this.text = msg != null ? msg : '';
        this.name = type != null ? type : Type.getClassName(Type.getClass(this));
        this.position = position;

        this.message = this.toString();
    }

/* === Instance Methods === */

    @:keep
    public function toString():String {
        return '' + position + ': ' + switch text {
            case '': name;
            case _: '$name: $text';
        }
    }

/* === Instance Fields === */

    public var name(default, null): String;
    public var text(default, null): String;
    public var message(default, null): String;
    public var position(default, null): PosInfos;

    public var errorData:Any = null;

/* === Statics === */

    public static function withData<T>(d:T, ?msg, ?pos):Error return new ErrorWithData(d, msg, null, pos);

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
                    err.name = Helpers.nor(try Reflect.getProperty(x, 'name') catch(err:Dynamic) null, err.name);
                    err.message = Helpers.nor(try Reflect.getProperty(x, 'message') catch(err:Dynamic) null, err.message);
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

class ErrorWithData<T> extends Error {
    public var data(get, set):T;

    public function new(data:T, ?msg, ?name, ?pos) {
        super(msg, name, pos);
        this.data = data;
    }

    private inline function get_data():T return cast this.errorData;
    private inline function set_data(v: T):T {
        this.errorData = cast v;
        return v;
    }
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

class ErrorWrapper extends pm.Error.ErrorWithData<Dynamic> {
    public function new(?message:String, inner:Dynamic, ?pos) {
        // super(message, null, pos);
        // this.innerError = inner;
        super(inner, message, 'Error', pos);
        //
    }


    @:extern
    static inline function _extract(e: Dynamic) {
        var state = {message:'', name:''};
        if (Reflect.hasField(e, 'message')) {
            var msg = Reflect.field(e, 'message');
        }
        var inner_name = try e.name catch (x: Dynamic) null;
        inner_name;
    }
}