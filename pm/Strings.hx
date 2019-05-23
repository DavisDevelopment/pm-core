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

    public static inline function beforeLast(s:String, del:String):String {
        return s.substring(0, s.lastIndexOf( del ));
    }

    public static inline function after(s:String, del:String):String {
        return s.substring(s.indexOf(del) + del.length);
    }
    public static inline function afterLast(s:String, del:String):String {
        return s.substring(s.lastIndexOf(del) + del.length);
    }
    public static inline function capitalize(s: String):String {
        return s.charAt(0).toUpperCase() + s.substring(1).toLowerCase();
    }

    public static inline function isUpperCase(s: String):Bool {
        return !~/[^A-Z]/.match( s );
    }
    public static inline function isLowerCase(s: String):Bool {
        return !~/[^a-z]/.match( s );
    }

    public static function camelCaseWords(s:String) {
        var words:Array<String> = new Array();
        var word:String = '';

        for (i in 0...s.length) {
            var c = s.charAt( i );
            if (isUpperCase( c )) {
                words.push( word  );
                word = c.toLowerCase();
            }
            else {
                word += c;
            }
        }

        if (!empty( word )) {
            words.push( word  );
        }

        return words;
    }

    public static function kebabCaseWords(s:String, sep:String = '-') {
        var words = [];
        var pat = new EReg(sep.split('').map(x -> '[$x]').join(''), '');
        return pat.split( s );
    }
    public static function snakeCaseWords(s: String) {
        return kebabCaseWords(s, '_');
    }

    public static function toPascalCase(s:String, sep:String = '-'):String {
        return StringArrays.pascalCase(kebabCaseWords(s, sep));
    }

    public static function toCamelCase(s:String, sep:String = '-'):String {
        return StringArrays.camelCase(kebabCaseWords(s, sep));
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
        return untyped php.Global.ltrim(s,charlist);
        #elseif (php && haxe_ver<4.0)
        return untyped __call__("ltrim", s, charlist);
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

    public static function trimCharsRight(s:String, charlist:String):String {
        #if (php && haxe_ver>=4.0)
            return untyped php.Global.rtrim(s, charlist);
        #elseif (php && haxe_ver<4.0)
            return untyped __call__("rtrim", s, charlist);
        #else
            var pos = s.length;
            var idx = s.length;
            while (--idx >= 0) {
                if (has(charlist, s.charAt(idx))) {
                    pos--;
                }
                else {
                    break;
                }
            }
            return s.substring(0, pos);
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

class StringArrays {
    public static function pascalCase(words:Array<String>):String {
        return words[0].toLowerCase()+words.slice(1).map(x -> Strings.capitalize(x)).join('');
    }
    public static function camelCase(words: Array<String>):String {
        return words.map(Strings.capitalize).join('');
    }
}

typedef Strs = StringTools;
