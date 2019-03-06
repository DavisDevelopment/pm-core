package pm;

using StringTools;

class Strings {
    public static inline function has(s:String, sub:String):Bool {
        return s.indexOf(sub) != -1;
    }
}

typedef Strs = StringTools;
