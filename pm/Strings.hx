package pm;

using StringTools;
using pm.Numbers;

class Strings {
    public static inline function has(s:String, sub:String):Bool {
        return s.indexOf(sub) != -1;
    }

    public static inline function empty(s: String):Bool {
        return s == null || s.length == 0;
    }

    public static inline function before(s:String, del:String):String {
        return s.substring(0, s.indexOf( del ));
    }

    public static inline function after(s:String, del:String):String {
        return s.substring(s.indexOf(del) + del.length);
    }

    public static function lstrip(s:String, ?del:String):String {
        return switch del {
            case null: s.ltrim();
            case _: after(s, del);
        }
    }

    public static function repeat(s:String, n:Int):String {
        var res = '';
        while (--n > 0)
            res += s;
        return res;
    }

    public static function trimCharsLeft(s:String, charlist:String):String {
        #if (php && haxe_ver>=4.0)
        return untyped php.Global.ltrim(value,charlist);
        #elseif (php && haxe_ver<4.0)
        return untyped __call__("ltrim", value, charlist);
        #else

        var pos = 0;
        for (i in 0...s.length) {
            if (has(charlist, s.charAt( i ))) {
                pos++;
            }
            else {
                break;
            }
        }
        return s.substring(pos);
        #end
    }

    public static inline function isNumeric(s: String):Bool {
        return !~/\D/gm.match( s );
    }

	/**
		Encode an URL by using the standard format.
	**/
    public #if php inline #end static function urlEncode( s : String ) : String untyped {
        #if flash9
            return __global__["encodeURIComponent"](s);
        #elseif flash
            return _global["escape"](s);
        #elseif neko
            return new String(_urlEncode(s.__s));
        #elseif js
            return encodeURIComponent(s);
        #elseif php
            return __call__("rawurlencode", s);
        #elseif cpp
            return s.__URLEncode();
        #else
            return null;
        #end
    }

	/**
		Decode an URL using the standard format.
	**/
	public #if php inline #end static function urlDecode( s : String ) : String untyped {
		#if flash9
			return __global__["decodeURIComponent"](s.split("+").join(" "));
		#elseif flash
			return _global["unescape"](s);
		#elseif neko
			return new String(_urlDecode(s.__s));
		#elseif js
			return decodeURIComponent(s.split("+").join(" "));
		#elseif php
			return __call__("urldecode", s);
		#elseif cpp
			return s.__URLDecode();
		#else
			return null;
		#end
	}

	/**
		Escape HTML special characters of the string.
	**/
	public static function htmlEscape( s : String ) : String {
		return s.split("&").join("&amp;").split("<").join("&lt;").split(">").join("&gt;");
	}

	/**
		Unescape HTML special characters of the string.
	**/
	public #if php inline #end static function htmlUnescape( s : String ) : String {
		#if php
		return untyped __call__("htmlspecialchars_decode", s);
		#else
		return s.split("&gt;").join(">").split("&lt;").join("<").split("&amp;").join("&");
		#end
	}

	#if neko
	private static var _urlEncode = neko.Lib.load("std","url_encode",1);
	private static var _urlDecode = neko.Lib.load("std","url_decode",1);
	#end
}

typedef Strs = StringTools;
