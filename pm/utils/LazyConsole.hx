package pm.utils;

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

	public static function examine(a:Dynamic, ?b:Dynamic, ?c:Dynamic, ?d:Dynamic, ?e:Dynamic):Void {
        return ;
    }
}