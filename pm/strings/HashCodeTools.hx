package pm.strings;

using pm.Strings;
using pm.Functions;

class HashCodeTools {
    public static inline function hash(f:String->Int, value:Dynamic):Int {
        return f(Std.string(value));
    }
}