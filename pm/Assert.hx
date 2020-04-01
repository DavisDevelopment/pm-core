package pm;

import pm.Lazy;

import haxe.PosInfos;

#if macro
import haxe.macro.Expr;
using haxe.macro.ExprTools;
#end

class Assert {
	public static inline function assert(condition:Bool, ?error:Dynamic, ?pos:#if !macro PosInfos #else Dynamic #end) {
        #if macro
        assertRelease(condition, error);
        #else
        assertDebug(condition, error, pos);
        #end
    }    
    
    public static inline function assertRelease(condition:Bool, ?error:Dynamic, ?pos:#if !macro PosInfos #else Dynamic #end):Void {
        if ( !condition )
            _toss(error, pos);
    }
    
    /**
     utility method for throwing an exception
     **/
     @:noCompletion
     public static function _toss(?error:Dynamic, ?pos:#if !macro PosInfos #else Dynamic #end) {
        if (error == null) {
            throw new AssertionFailureError(error, pos);
        }
        else {
                throw error;
        }
    }

    #if !macro
    /**
     throws an error if [condition] is not met
     **/
    
    public static inline function assertDebug(condition:Bool, ?error:Dynamic, ?pos:PosInfos) {
		#if (debug || keep_assertions)
		if (!condition)
			_toss(error, pos);
		#end
    }
    
    /**
     throws an error if [fn] doesn't cause an error to be thrown
     **/
     public static inline function assertThrows<E>(fn:Void->Void, ?msg:Lazy<E>, ?pos:PosInfos):Void {
        #if (debug || keep_assertions)
        try {
            fn();
            _toss(msg, pos);
        }
        catch (e: Dynamic) {
            //
        }
        #end
    }
    
#else

#if !display
    public static function massert(condition:Expr, rest:Array<Expr>):ExprOf<Bool> {
        var error:Expr = macro null;
        switch rest {
            case []:
                var txt = try condition.toString() catch (e: Dynamic) null;
                if (txt != null) {
                    error = macro $v{'AssertionFailed: $txt'};
                }
            
            case [err]:
                error = err;

            default:
        }
        return macro (@:mergeBlock {
            var b = $condition;
            if (!b) {
                pm.Assert._toss($error);
            }
            b;
        }) == true;
    }
#end

#end

    public static #if !macro macro #end function aassert(condition #if macro , rest:Array<Expr> #end) {
        return #if macro massert(condition, rest) #else assert(condition) #end;
    }
}
    
class AssertionFailureError extends Error {}
