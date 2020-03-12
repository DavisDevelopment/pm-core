package pm.utils;

import haxe.macro.Expr;
using haxe.macro.ExprTools;

class LazyConsole {
    public static function println(x: Dynamic):Void {
        #if (sys || hxnodejs)
        Sys.println(x);
        #else
        return ;
        #end
    }

    public static inline function log(x:Dynamic):Void {
        println(x);
    }
    public static inline function warn(x:Dynamic):Void {
        println(x);
    }
    public static inline function info(x:Dynamic):Void {
        println(x);
    }
    public static inline function error(x: Dynamic):Void {
        println(x);
    }

    public static inline function debug(x:Dynamic):Void {
        #if debug
        println(x);
        #end
    }

    public static inline function printlnFormatted(x:Dynamic) {
        println(x);
    }
	public static function success(a:Dynamic, ?b:Dynamic, ?c:Dynamic, ?d:Dynamic, ?e:Dynamic):Void {
		return ;
	}

	// public static function examine(a:Dynamic, ?b:Dynamic, ?c:Dynamic, ?d:Dynamic, ?e:Dynamic):Void {
    //     return ;
    // }
	public static macro function examine(args: Array<haxe.macro.Expr>) {
        var parts = [];
        for (e in args) {
            parts.push(macro $v{e.toString()});
            parts.push(macro ': ');
            parts.push(macro $e);
            parts.push(macro ",\n> ");
        }
        parts.pop();
        var sum = macro '';
        for (p in parts)
            sum = macro $sum + $p;
        return macro pm.utils.LazyConsole.println("> " + $sum);
    }
}