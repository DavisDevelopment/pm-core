package pm;

import haxe.io.ArrayBufferView.ArrayBufferViewData;
import haxe.io.BytesData;
import pm.Error;
import pm.Object;
import pm.utils.Uuid;

import haxe.DynamicAccess;
import haxe.ds.Either;
import haxe.ds.Option;
import haxe.extern.EitherType;
import haxe.PosInfos;
import haxe.io.Bytes;

import haxe.macro.Expr;
import haxe.macro.Context;

import Type.ValueType;
import pm.Numbers.Floats.min;

import Std.is as isType;
import Reflect.*;

using Lambda;
using StringTools;
using pm.Options;
using pm.Strings;

/**
  collection of methods that lay out the foundation for the overall architecture of the rest of the system
 **/
@:expose
class Arch {

    /**
      generate a unique identifier string
     **/
    public static inline function createNewIdString():String {
        return Uuid.create();
    }

    /**
      get a DotPath object for the given fieldName
     **/
    public static function getDotPath(fieldName: String):DotPath {
        if (!dotPathCache.exists( fieldName )) {
            dotPathCache[fieldName] = DotPath.fromPathName( fieldName );
        }
        return dotPathCache[fieldName];
    }

    /**
      resolve the given dot-path
     **/
    public static function getDotValue(o:DynamicAccess<Dynamic>, field:String):Dynamic {
        if (field.has('.'))
            return getDotPath(field).get(o, null);
        return o[field];
    }

    public static function setDotValue(o:DynamicAccess<Dynamic>, field:String, value:Dynamic):Void {
        if (field.has('.'))
            getDotPath(field).set(o, value);
        else
            o[field] = value;
    }

    public static function hasDotValue(o:DynamicAccess<Dynamic>, field:String):Bool {
        if (field.has('.'))
            return getDotPath(field).has(o, false);
        return o.exists( field );
    }

    public static function delDotValue(o:DynamicAccess<Dynamic>, field:String) {
        if (field.has('.'))
            return getDotPath(field).del(o, false);
        return o.remove( field );
    }

    /**
      check whether the two given values can be considered equivalent
     **/
    public static inline function areThingsEqual(left:Dynamic, right:Dynamic, ?strict:Bool):Bool {
        return _areThingsEqual(left, right);
    }

    static function _areThingsEqual(a:Dynamic, b:Dynamic, strict:Bool=false):Bool {
        if (isArray(a)) {
            if (isArray(b)) return areArraysEqual(a, b);
            return false;
        }
        if (isBool(a)) return isBool(b) ? a == b : false;
        if (isFloat(a)) return isFloat(b) ? a == b : false;
        if (isString(a)) return isString(b) ? a == b : false;
        if (a == null || b == null) return a == b;

        if (isDate(a)) return isDate(b) ? cast(a, Date).getTime() == cast(b, Date).getTime() : false;
        if (Reflect.isEnumValue(a)) return Reflect.isEnumValue(b) ? areEnumValuesEqual(cast a, cast b) : false;
        return areObjectsEqual2(a, b);
    }

    public static function areObjectsEqual(a:Dynamic, b:Dynamic):Bool {
        var aKeys = Reflect.fields( a ), bKeys = Reflect.fields( b );
        for (i in 0...aKeys.length) {
            if (!bKeys.has(aKeys[i])) {
                return false;
            }

            if (!areThingsEqual(Reflect.field(a, aKeys[i]), Reflect.field(b, bKeys[i]))) {
                return false;
            }
        }

        return true;
    }

    public static function areObjectsEqual2(a:Doc, b:Doc):Bool {
        var aKeys = a.keys(), bKeys = b.keys();
        if (aKeys.length != bKeys.length) return false;
        for (i in 0...aKeys.length) {
            if (bKeys.indexOf(aKeys[i]) == -1) return false;
            if (!areThingsEqual(a[aKeys[i]], b[bKeys[i]])) return false;
        }
        return true;
    }

    public static function areEnumValuesEqual(a:EnumValue, b:EnumValue):Bool {
        return (
            Type.getEnum( a ) == Type.getEnum( b ) &&
            a.getIndex() == b.getIndex() &&
            areArraysEqual(a.getParameters(), b.getParameters())
        );
    }

    public static function areArraysEqual(a:Array<Dynamic>, b:Array<Dynamic>):Bool {
        if (a.length != b.length) {
            return false;
        }

        for (i in 0...Math.floor(Math.max(a.length, b.length))) {
            if (!areThingsEqual(a[i], b[i])) {
                return false;
            }
        }

        return true;
    }

    public static inline function boolEquality(a:Bool, b:Bool):Bool {
        return a ? b : !b;
    }

    public static inline function intEquality(a:Int, b:Int):Bool {
        return a == b;
    }

    public static inline function floatEquality(a:Float, b:Float, epsilon:Float=0.0):Bool {
        return (Math.abs(a - b) <= epsilon);
    }

    public static inline function stringEquality(a:String, b:String):Bool {
        return a == b;
    }

    public static inline function dateEquality(a:Date, b:Date):Bool {
        return a.getTime() == b.getTime();
    }

    public static function bytesEquality(a:Bytes, b:Bytes):Bool {
        if (a.length != b.length)
            return false;
        for (i in 0...a.length) {
            if (a.get( i ) != b.get( i )) {
                return false;
            }
        }
        return true;
    }

    public static function typedArrayEquality<T>(a:Array<T>, b:Array<T>, eq:T -> T -> Bool):Bool {
        var equivalent:Bool = true;
        if (a.length != b.length)
            equivalent = false;
        if ( equivalent ) {
            for (i in 0...a.length) {
                if (!eq(a[i], b[i])) {
                    equivalent = false;
                    break;
                }
            }
        }
        return equivalent;
    }

    /**
      check for deep equality between the two given Arrays
     **/
    public static function arrayEquality<T>(a:Array<T>, b:Array<T>):Bool {
        return typedArrayEquality(a, b, (a, b) -> areThingsEqual(a, b));
    }

    public static function enumValueEquality<T:EnumValue>(a:T, b:T):Bool {
        if (a.getIndex() != b.getIndex())
            return false;
        return arrayEquality(a.getParameters(), b.getParameters());
    }

    /**
      check for deep equality between the two given Objects
     **/
    public static function objectEquality(a:Object<Dynamic>, b:Object<Dynamic>, ?vEq:Dynamic->Dynamic->Bool):Bool {
        var aKeys = a.keys();
        var bKeys = b.keys();
        if (vEq == null) 
            vEq = ((x, y) -> areThingsEqual(x, y));

        var strCmp = (x, y) -> compareStrings(x, y);
        aKeys.sort( strCmp );
        bKeys.sort( strCmp );

        for (i in 0...Math.floor(Math.min(aKeys.length, bKeys.length))) {
            if (!(stringEquality(aKeys[i], bKeys[i]) && vEq(a[aKeys[i]], b[bKeys[i]]))) {
                return false;
            }
        }

        return intEquality(aKeys.length, bKeys.length);
    }

    /**
      numerically compare the two given values
      [= this is gonna get ugly.. =]
     **/
    public static function compareThings(a:Dynamic, b:Dynamic):Int {
        // null
        if (a == null) return b == null ? 0 : -1;
        if (b == null) return a == null ? 0 :  1;

        // numbers
        if (isFloat(a)) return isFloat(b) ? compareNumbers(a, b) : -1;
        if (isFloat(b)) return isFloat(a) ? compareNumbers(a, b) :  1;

        // strings
        if (isString(a)) return isString(b) ? compareStrings(a, b) : -1;
        if (isString(b)) return isString(a) ? compareStrings(a, b) :  1;

        // booleans
        if (isBool(a)) return isBool(b) ? compareBooleans(a, b) : -1;
        if (isBool(b)) return isBool(a) ? compareBooleans(a, b) :  1;

        // dates
        if (isDate(a)) return isDate(b) ? compareDates(a, b) : -1;
        if (isDate(b)) return isDate(a) ? compareDates(a, b) :  1;

        // arrays
        if (isArray(a)) return isArray(b) ? compareArrays(a, b) : -1;
        if (isArray(b)) return isArray(a) ? compareArrays(a, b) :  1;

        // anonymous objects
        if (isObject( a )) return isObject(b) ? compareObjects(a, b) : -1;
        if (isObject( b )) return isObject(a) ? compareObjects(a, b) :  1;

        // should never be reached
        return compareObjects(a, b);
    }

    public static function compareObjects(a:Dynamic, b:Dynamic, ?vCmp:Dynamic->Dynamic->Int):Int {
        var comp: Int;
        var aKeys = fields( a );
        var bKeys = fields( b ); 
        var strCmp = ((x, y) -> compareStrings(x, y));
        //trace(aKeys.concat(bKeys).unique().isort(strCmp));
        if (vCmp == null) 
            vCmp = ((x, y) -> compareThings(x, y));

        // here is where the difference in attribute-lists between [a] and [b] affects the comparison
        aKeys.sort( strCmp );
        bKeys.sort( strCmp );

        for (i in 0...min(aKeys.length, bKeys.length)) {
            comp = vCmp(field(a, aKeys[i]), field(b, bKeys[i]));
            if (comp != 0) {
                trace('cmp(${field(a, aKeys[i])}, ${field(b, bKeys[i])}) == $comp');
                return comp;
            }
        }

        return compareNumbers(aKeys.length, bKeys.length);
    }

    public static inline function compareTypedArrays<T>(a:Array<T>, b:Array<T>, fn:(a:T, b:T)->Int):Int {
        var comp: Int = 0;
        for (i in 0...min(a.length, b.length)) {
            comp = fn(a[i], b[i]);
            if (comp != 0)
                break;
        }
        return comp == 0 ? compareNumbers(a.length, b.length) : comp;
    }

    public static function compareArrays(a:Array<Dynamic>, b:Array<Dynamic>):Int {
        return compareTypedArrays(a, b, function(a:Dynamic, b:Dynamic) {
            return compareThings(a, b);
        });
    }

    /**
      compare two EnumValue values
     **/
    public static function compareEnumValues<E:EnumValue>(a:E, b:E):Int {
        var comp:Int = compareNumbers(a.getIndex(), b.getIndex());
        if (comp != 0) 
            return comp;
        return compareArrays(a.getParameters(), b.getParameters());
    }

    /**
      compare two Date instances
     **/
    public static inline function compareDates(a:Date, b:Date):Int {
        return compareNumbers(a.getTime(), b.getTime());
    }

    /**
      compare two Booleans
     **/
    public static inline function compareBooleans(a:Bool, b:Bool):Int {
        return compareNumbers(a ? 1 : 0, b ? 1 : 0);
    }

    /**
      compare two numbers
     **/
    public static inline function compareNumbers(a:Float, b:Float):Int {
        return
            if (a < b) -1
            else if (a > b) 1
            else 0;
    }

    /**
      compare two String instances
     **/
    public static inline function compareStrings(a:String, b:String):Int {
        return Reflect.compare(a, b);
    }

    /**
      compare two Bytes objects
     **/
    public static function compareBytes(a:Bytes, b:Bytes):Int {
        var comp: Int;

        for (i in 0...Math.floor(Math.min(a.length, b.length))) {
            comp = compareNumbers(a.get(i), b.get(i));
            if (comp != 0)
                return comp;
        }

        return compareNumbers(a.length, b.length);
    }

    /**
      do dat type-checking
     **/
    public static macro function isType(value, type) {
        return macro Std.is($value, ${type});
    }

    /**
      Tells whether a value is an "atomic" (true primitive) value
     **/
    public static inline function isAtomic(x: Dynamic):Bool {
        return (
            isNull( x ) ||
            isString( x ) ||
            isBool( x ) ||
            isFloat( x )
        );
    }

    /**
      check whether the given value is iterable
     **/
    public static inline function isIterable(x: Dynamic):Bool {
        return x.is_iterable();
    }

    /**
      check whether the given value is an iterator
     **/
    public static function isIterator(x: Dynamic):Bool {
        return x.is_iterator();
    }

    public static inline function isNull(x: Dynamic):Bool return x == null;

    public static inline function isBool(x: Dynamic):Bool {
        return isType(x, Bool);
    }

    public static inline function isFloat(x: Dynamic):Bool {
        return isType(x, Float);
    }

    public static inline function isInt(x: Dynamic):Bool {
        return isType(x,  Int);
    }

    public static inline function isString(x: Dynamic):Bool {
        return isType(x, String);
    }

    public static inline function isBinary(x: Dynamic):Bool {
        return isType(x, Bytes);
    }

    /**
      Tells if an object is a primitive type or a "real" object
      Arrays are considered primitive
     **/
    public static inline function isPrimitiveType(x: Dynamic):Bool {
        return (
            isBool( x )
            || isFloat( x )
            || isString( x )
            || isNull( x )
            || isArray( x )
            || isDate( x )
        );
    }

    /**
      check whether the given value is an Array value
     **/
    public static inline function isArray(x: Dynamic):Bool {
        return (x is Array);
    }

    public static function isArrayLike(x: Dynamic):Bool {
        return (
            isArray(x)||
            isString(x)||
            #if (neko || python || flash || js)
            (x is BytesData)||
            #end
            isBinary(x)||
            (x is haxe.ds.IntMap)||
            /**
              `ArrayBufferViewData` is the root class for `UInt8Array`, `UInt16Array`, `Int32Array`, `Float32Array` and `Float64Array`
             **/
            (x is ArrayBufferViewData)
        );
    }

    /**
      check whether the given value is an Object
     **/
    public static inline function isObject(x: Dynamic):Bool {
        return Reflect.isObject( x );
    }

    /**
      check whether the given value is a regular expression
     **/
    public static function isRegExp(x: Dynamic):Bool {
        return isType(x, EReg);
    }

    /**
      check whether the given value is a Date
     **/
    public static function isDate(x: Dynamic):Bool {
        return isType(x, Date);
    }

    /**
      check whether the given value is a function 
     **/
    public static function isFunction(x: Dynamic):Bool {
        return Reflect.isFunction( x );
    }

    /**
      create and return an 'empty' instance of the same type as [value]
     **/
    public static function emptyCopy<T>(value: T):T {
        return emptyUntypedCopy( value );
    }

    /**
      create a new value of the same type as [value], but with no data yet attached
     **/
    public static function emptyUntypedCopy(value: Dynamic):Dynamic {
        var vClass:Null<Class<Dynamic>> = Type.getClass( value );
        if (vClass != null) {
            return Type.createEmptyInstance( vClass );
        }
        else {
            return {};
        }
    }

    public static function defaults<T>(a:T, b:T) {
        Object.unsafe( a ).pullDefault( b );
        return a;
    }

    public static function clone<T>(value:T, ?method:CloneMethod, ensureObjects:Bool=false):T {
        return dclone(value, method);
    }

    public static function dclone(value:Dynamic, ?method:CloneMethod):Dynamic {
        if (method == null)
            method = ShallowRecurse;

        if (isAtomic( value ))
            return value;

        if (isDate( value )) {
            var date:Date = cast(value, Date);
            return Date.fromTime(date.getTime());
        }

        if (isArray( value )) {
            return clone_uarray(cast(value, Array<Dynamic>), method);
        }

        if (isObject( value )) {
            return clone_object(value, method);
        }

        return value;
    }

    public static function clone_object<T>(o:T, ?method:CloneMethod, allObjects:Bool=false):T {
        if (method == null) method = Shallow;

        var cloned: Dynamic;
        final oClass:Null<Class<Dynamic>> = Type.getClass( o );
        switch ( method ) {
            case Shallow:
                if (oClass == null) {
                    #if (js && js_optimizations)
                        cloned = untyped {js.Object.assign(({}:Dynamic), (o : Dynamic));};
                    #else
                    cloned = Reflect.copy( o );
                    #end
                }
                else {
                    cloned = Type.createEmptyInstance(oClass);
                    #if (js && js_optimizations)
                        untyped js.Object.assign((cloned : Dynamic), (o : Dynamic));
                    #else
                    //
                    for (k in Reflect.fields(o)) {
                        Reflect.setField(cloned, k, Reflect.field(o, k));
                    }
                    #end
                }

            case ShallowRecurse:
                cloned = clone_object(o, Shallow);
                for (k in Reflect.fields(cloned)) {
                    final prop = Reflect.field(cloned, k);
                    Reflect.setField(cloned, k, clone(prop, method));
                }

            case JsonReparse:
                cloned = haxe.Json.parse(haxe.Json.stringify( o ));

            case HxSerialize:
                cloned = haxe.Unserializer.run(haxe.Serializer.run( o ));

            case Custom(cp):
                cloned = cp( o );

            case Deep(meth):
                cloned = clone_object(o, Shallow);
                //for (k in Reflect.fields(cloned)) {
                    //Reflect.setField(cloned, k, clone(Reflect.getField(cloned, k), method));
                //}
                trace('Warning: Not an actual deep-copy');
        }
        return cloned;
    }

    /**
      copy all data from [src] onto [dest]
     **/
    public static function clone_object_onto(src:Object<Dynamic>, dest:Object<Dynamic>, ?fields:Array<String>, ?copy_value:Dynamic->Dynamic):Void {
        if (fields == null)
            fields = src.keys();

        if (copy_value == null)
            copy_value = x -> x;

        for (k in fields) {
            dest[k] = copy_value(src[k]);
        }
    }

    public static function anon_copy(o:Dynamic, ?dest:Object<Dynamic>, ?copy_value:Dynamic->Dynamic):Dynamic {
        var o = o.asObject();
        //
        if (o.exists('hxGetState')) {
            try {
                return Reflect.callMethod(o, o.hxGetState, []);
            }
            catch (e: Dynamic) {}
        }

        if (dest == null)
            dest = new Object();
        clone_object_onto(o.asObject(), dest, copy_value);
        return dest;
    }

    /**
      given an object [o], ensures that the returned object is not a class instance, but has the same attributes as [o]
     **/
    public static function ensure_anon(o:Object<Dynamic>, copy=false):Object<Dynamic> {
        var value;
        if ( !copy ) value = x->x;
        else value = (x: Dynamic) -> dclone(x, ShallowRecurse);
        return (Type.getClass( o ) != null) ? anon_copy(o, value) : value( o );
    }

    public static function buildClassInstance<T>(type:Class<T>, state:Object<Dynamic>):T {
        var inst = Type.createEmptyInstance( type );
        if (Reflect.hasField(inst, 'hxSetState')) {
            Reflect.callMethod(inst, Reflect.field(inst, 'hxSetState'), [state]);
        }
        else {
            clone_object_onto(state, Object.unsafe(inst));
        }
        return inst;
    }

    public static function allInstanceFields(type: Class<Dynamic>):Array<String> {
        var fields = [];
        var set:Map<String, Bool> = new Map();
        inline function add(s: String) {
            if (!set.exists(s)) {
                set[s] = true;
                fields.push( s );
            }
        }

        var t = type;
        while (t != null) {
            for (field in Type.getInstanceFields(t)) {
                add( field  );
            }
            t = Type.getSuperClass( t  );
        }

        return fields;
    }

    /**
      create and return a 'clone' of the given [array]
     **/
    public static function clone_uarray(array:Array<Dynamic>, ?method:CloneMethod):Array<Dynamic> {
        if (method == null)
            method = ShallowRecurse;

        var cloned: Array<Dynamic>;
        switch ( method ) {
            case Shallow:
                cloned = array.copy();

            case ShallowRecurse:
                cloned = array.map(function(x: Dynamic) {
                    return clone(x, ShallowRecurse);
                });

            case JsonReparse:
                cloned = array.map(x -> haxe.Json.parse(haxe.Json.stringify( x )));

            case HxSerialize:
                cloned = array.map(x -> haxe.Unserializer.run(haxe.Serializer.run( x )));

            case Custom(cp):
                cloned = array.map(x -> cp( x ));

            case Deep(meth):
                cloned = array.map(x -> clone(x, meth));
        }
        return cloned;
    }

    /**
       attempt to get an iterator from [v]
     */
    public static function makeIterator(v : Dynamic):Iterator<Dynamic> {
        #if ((flash && !flash9) || (php && !php7 && haxe_ver < '4.0.0'))
            if (v.iterator != null)
                v = v.iterator();
        #else
            try {
                v = v.iterator();
            }
            catch (e : Dynamic) {}
        #end

        if (v.hasNext == null || v.next == null) {
            throw new ValueError(v, 'EInvalidIterator');
        }

        return v;
    }

    #if python
    @:keep 
    @:native('_foo_')
    private static function ensureCloneMethodGeneration(?cm: CloneMethod):CloneMethod {
        if (cm == null) {
            cm = CloneMethod.Custom(function(value) {
                return value;
            });
        }
        return CloneMethod.Deep( cm );
    }
    #end

/* === Variables === */

    private static var dotPathCache:Map<String, DotPath> = new Map();
}

/**
  algorithm used to create copies of values
 **/
@:keep
enum CloneMethod {
    Shallow;
    ShallowRecurse;

    JsonReparse;
    HxSerialize;

    /**
      Custom(fn) allows a custom cloning lambda to be specified. 
      Cloning lambdas are validated by testing:
      <pre><code>
        Arch.areThingsEqual(o, fn(o))
      </code></pre>
     **/
    Custom(fn: Dynamic -> Dynamic);
    Deep(recursionMethod: CloneMethod);
}

class Stuff {
    public static inline function isEqualTo(a:Dynamic, b:Dynamic):Bool {
        return Arch.areThingsEqual(a, b);
    }
}
