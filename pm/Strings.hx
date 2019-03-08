package pm;

using StringTools;

class Strings {
    public static inline function has(s:String, sub:String):Bool {
        return s.indexOf(sub) != -1;
    }

    public static inline function empty(s: String):Bool {
        return s == null || s.length == 0;
    }
}

typedef Strs = StringTools;
