package pm.async;

import haxe.DynamicAccess;
using pm.Functions;

import haxe.extern.Rest;
import haxe.ds.Either;
import haxe.ds.Option;

using pm.Options;
using pm.Outcome;
using pm.Arrays;

import pm.Helpers.*;
import pm.Assert.*;
import haxe.macro.Expr;

using Reflect;
using Type;
using pm.Functions;
using pm.Strings;
using pm.core.BaseTools;

abstract DynamicFunction(Dynamic)
 from CWrappedFunction
 from haxe.Constraints.Function
{
/* === Instance Methods === */

    public inline function _call(args: Arguments):Dynamic {
        return if ((this is CWrappedFunction)) cast(this, CWrappedFunction).apply(args) else Reflect.callMethod(null, this, args);
    }

    public inline function _tcall<T>(args: Arguments):T {
        return cast _call(args);
    }

    public function isWrapped():Bool {
        if ((this is CWrappedFunction)) {
            return true;
        }
        else if (hasField(this, 'hxWrapped')) {
            var w:Dynamic = this.hxWrapped;
            if ((w is CWrappedFunction)) {
                return true;
            }
        }
        return false;
    }

    public inline function isNativeFunction():Bool return Reflect.isFunction(this);

    @:to
    public inline function asNativeFunction():haxe.Constraints.Function {
        assert(isNativeFunction(), new pm.Error('Cast failed'));
        return cast this;
    }

    public function asWrapped(coerce=false):CWrappedFunction {
        var isNative = isNativeFunction();
        if (!coerce && isNative) throw new pm.Error('Cast failed');
        else if ((this is CWrappedFunction)) return cast(this, CWrappedFunction);
        else if (coerce && isNative) {
            return CWrappedFunction.wrap(this);
        }
        throw new pm.Error.WTFError();
    }

    public function wrap(wrapper: DynamicFunction):DynamicFunction {
        var self = this;
        function wrapped(args: Arguments):Dynamic {
            args.unshift(self);
            return wrapper._call(args);
        }
        return wrapped;
    }
	
    /**
		callback is passed in as argument
	**/
	public macro function call(self:ExprOf<DynamicFunction>, vargs:Array<haxe.macro.Expr>) {
        var args:Array<Expr> = vargs.map(e -> macro (untyped ${e}));
        var eargs:Expr = macro $a{args};
		return macro $self._tcall(${eargs});
	}

/* === Betty === */

    public static var metaSymbol = new pm.Symbol('pm.dynamic.DynamicFunction.MetaKey');

    @:noUsing
    public static function ffield(f:DynamicFunction, name:Key):Dynamic {
        if ((name is String)) {
            var name:String = cast(name, String);
            return Reflect.field(f, name);
        }
        throw new pm.Error('Invalid shit ass');
    }

    @:noUsing
    public static function hasField(f:DynamicFunction, field:Key):Bool {
        assert((field is String), new pm.Error('Invalid field-key $field'));

        if (Reflect.hasField(f, cast field)) return true;
        return false;
    }

    @:noUsing
    public static function setField(f:Dynamic, field:Key, value:Dynamic):Dynamic {
        if ((field is String)) {
            var field:String = cast field;
            Reflect.setField(f, field, value);
            return value;
        }
        else if (Symbol.is(field)) {
            var field:Symbol = cast field;
            #if js
            Reflect.setField(f, cast field.key, value);
            return value;
            #else
            throw new pm.Error.WTFError();
            #end
        }
        throw new pm.Error.WTFError();
    }

    @:noUsing
    public static function wrapFunction(f:haxe.Constraints.Function, nargs:Int=-1, returns:Bool=false):DynamicFunction {
        var w:CWrappedFunction = CWrappedFunction.wrap(f);
        return cast w;
    }

    @:from
    public static inline function ofVarargs(f: Arguments->Dynamic):DynamicFunction {
        return @:privateAccess new CWrappedFunction(f);
    }

    @:from
    public static inline function ofFunction(f: haxe.Constraints.Function):DynamicFunction {
        return CWrappedFunction.wrap(f);
    }
}

abstract Key(Dynamic) 
from pm.Symbol
from EnumValue
from String
from Int
{
    public inline function isValidFieldName():Bool {
        return (this is String) || Symbol.is(this);
    }
}

@:forward
abstract Arguments (Array<Dynamic>) from Array<Dynamic> to Array<Dynamic> {

}

enum Tk {
    Undefined;
}

class CWrappedFunction {
    public var id:Int = pm.HashKey.next();
    public var f: Arguments->Dynamic;
    public var _wrapped : Dynamic;

    private function new(f : Arguments->Dynamic) {
        this.f = f;

        this._wrapped = Reflect.makeVarArgs(a -> this.apply(a));
    }

    public function apply(args: Arguments):Dynamic {
        //TODO a little bit of boilerplate argument-parsing
        return f(args);
    }

    @:noUsing
    public static function wrap(f: Dynamic):CWrappedFunction {
        if ((f is CWrappedFunction)) return cast(f, CWrappedFunction);

        if (f.isFunction()) {
            var fn:haxe.Constraints.Function = cast f;
            var ref:Dynamic = {r: null};
            // DynamicFunction.setField(cast fn, DynamicFunction.metaSymbol, ref);
            var apply = function(args: Arguments):Dynamic {
                return Reflect.callMethod(null, fn, args);
            };
            // DynamicFunction.setField(cast apply, DynamicFunction.metaSymbol, ref);
            var w = new CWrappedFunction(apply);
            ref.r = w;
            return w;
        }
        throw new pm.Error('Invalid function $f');
    }
}

abstract FunctionReference (haxe.Constraints.Function) from haxe.Constraints.Function {
    public static inline function unsafe(f: Dynamic):FunctionReference return (cast f : FunctionReference);
    public function _call(args: Arguments):Dynamic return Reflect.callMethod(null, this, args);
    public function _tcall<T>(args: Arguments):T return cast _call(args);
    public macro function call(self:ExprOf<FunctionReference>, vargs:Array<Expr>) {
        var eargs = macro $a{vargs.map(e -> macro (untyped $e))};
        return macro $self._tcall($eargs);
    }

    public var repr(get, never):String;
    private inline function get_repr():String {
        return Std.string(this);
    }

    // #if (python || java) inline #end
    public function hashCode():Int {
        #if js
		if (!o.exists('__hashCode__')) {
			o.set('__hashCode__', HashKey.next());
		}
		return cast(o.get('__hashCode__'), Int);
        #end
        #if python
            return (cast (untyped hash(this)) : Int);
            // return python.lib.Builtins.
        #end
        #if java
            return cast(this, java.lang.Object).hashCode();
        #elseif hl
            // throw new pm.Error.NotImplementedError();
            var hexId:String = repr.after('#');
            trace(hexId);
            var id:Int = hexId.fromBase(16);
            trace(id);
            return id;
        #elseif !eval
            if (!FMaps.referenceToHashCode.exists(this)) {
                FMaps.referenceToHashCode.set(this, HashKey.next());
            }
            return FMaps.referenceToHashCode.get(this);
        #else
            throw new pm.Error.NotImplementedError();
        #end
    }

    @:allow(pm.async.DynamicFunction.FunctionReferenceMetadata)
    public inline function getMetadataObject(create=false) {
        #if (js || python)
        return untyped this;
        #else
        final code = hashCode();
        if (FMaps.hashCodeToMeta.exists(code)) {
            return FMaps.hashCodeToMeta.get(code);
        }
        else if (create) {
            var r;
            FMaps.hashCodeToMeta.set(code, r={});
            return r;
        }
        else {
            throw new pm.Error('No metadata on $this');
        }
        #end
    }

    public var o(get, never):haxe.DynamicAccess<Dynamic>;
    private inline function get_o():haxe.DynamicAccess<Dynamic> {
        return (cast this : DynamicAccess<Dynamic>);
    }

#if !anus
    @:op(a.b)
    public static macro function dotGet(self:ExprOf<FunctionReference>, field:String) {
        return macro ($self.o.get($v{field}));
    }

    @:op(a.b)
    public static macro /*inline*/ function dotSet(self:ExprOf<FunctionReference>, field:String, value) {
        return macro ($self.o.set($v{field}, $value));
        // return self.o.set(field, value);
    }
#end
}

abstract FunctionReferenceMetadata (FunctionReference) from FunctionReference {
    private var target(get, never):Dynamic;
    private inline function get_target():Dynamic return this.getMetadataObject();

    public function getProperty(key: Key):Dynamic {
        if ((key is String)) {
            var key:String = cast key;
            return Reflect.field(target, key);
        }
        else if (Symbol.is(key)) {
            var key:pm.Symbol = cast key;
            return
            #if js
            return Reflect.field(target, cast key.key);
            #else
            return getProperty(key.getKey());
            #end
        }
        else {
            throw new pm.Error('Invalid field-key');
        }
    }
    public function setProperty(key:Key, value:Dynamic):Dynamic {
        inline function setattr(o:Dynamic, k:Dynamic, v:Dynamic):Dynamic {
            Reflect.setField(o, cast k, v);
            return v;
        }
        var o = target;
        if ((key is String)) {
            return setattr(o, key, value);
        }
        else if (Symbol.is(key)) {
            var key:pm.Symbol = cast key;
            return setattr(o, key.getKey(), value);
        }
        else {
            throw new pm.Error('Invalid field-key');
        }
    }
}

class FMaps {
	
	public static var referenceToHashCode:#if (java || cpp) haxe.ds.WeakMap<Dynamic, Int> #else haxe.ds.ObjectMap<Dynamic, Int> #end;
    public static var hashCodeToMeta:Map<Int, Dynamic>;

    public static function __init__() {
		referenceToHashCode = (new #if (java || cpp) haxe.ds.WeakMap<Dynamic, Int> #else haxe.ds.ObjectMap<Dynamic, Int> #end ());
        hashCodeToMeta = new Map();
    }
}