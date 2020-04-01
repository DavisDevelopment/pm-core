package pm;

// import moon.core.Struct;
import pm.Object;

using StringTools;
using pm.Strings;

@:forward
abstract Url (UrlData) from UrlData to UrlData {
    public inline function new(url:String, strictMode=false) {
        this = new UrlData(url, strictMode);
    }
    @:from static inline function of(url: String):Url {
        return parse(url);
    }
    inline public static function parse(s:String, ?strictMode:Bool):Url {
        return new Url(s, strictMode);
    }
}

/**
 * http://blog.stevenlevithan.com/archives/parseuri
 * @author Munir Hussin
 */
class UrlData {
	private static var key:Array<String> = ["source", "protocol", "authority", "userInfo", "user", "password", "host", "port", "relative", "path", "directory", "file", "query", "anchor"];
	private static var strict:EReg = ~/^(?:([^:\/?#]+):)?(?:\/\/((?:(([^:@]*)(?::([^:@]*))?)?@)?([^:\/?#]*)(?::(\d*))?))?((((?:[^?#\/]*\/)*)([^?#]*))(?:\?([^#]*))?(?:#(.*))?)/;
	private static var loose:EReg = ~/^(?:(?![^:@]+:[^:@\/]*@)([^:\/?#.]+):)?(?:\/\/)?((?:(([^:@]*)(?::([^:@]*))?)?@)?([^:\/?#]*)(?::(\d*))?)(((\/(?:[^?#](?![^?#\/]*\.[^?#\/.]+(?:[?#]|$)))*\/?)?([^?#\/]*))(?:\?([^#]*))?(?:#(.*))?)/;
	private static var qrx:EReg = ~/(?:^|&)([^&=]*)=?([^&]*)/g;

	public var source(default, set):String = null;
	public var protocol(default, set):String = null;
	public var authority(default, set):String = null;
	public var userInfo(default, set):String = null;
	public var user(default, set):String = null;
	public var password(default, set):String = null;
	public var host(default, set):String = null;
	public var port(default, set):String = null;
	public var relative(default, set):String = null;
	public var path(default, set):String = null;
	public var directory(default, set):String = null;
	public var file(default, set):String = null;
	public var query(default, set):String = null;
	public var anchor(default, set):String = null;
	public var queryKey:Object<String> = null;

	private var strictMode: Bool;

	public inline function new(url:String, strictMode:Bool = false) {
		reparse(url, strictMode);
	}

	inline function reparse(url:String, strictMode:Bool = false):Void {
		this.strictMode = strictMode;

		var rx:EReg = strictMode ? strict : loose;
		var i:Int = 14;

		rx.match(url);

		while (i-- > 0)
			Reflect.setField(this, key[i], rx.matched(i));

        if (query != null) {
            queryKey = new Object<String>();
            qrx.map(query, function(x:EReg):String {
                var s:String = x.matched(1);

                if (s != null && s.length > 0) {
                    queryKey[x.matched(1)] = x.matched(2);
                }

                return "";
            });
        }
	}

	public function format():String {
		var s:String = "";

		if (protocol != null)
			s += protocol + "://";

		if (authority != null) {
			s += authority;
		}

		if (relative != null) {
			s += relative;
		}

		return s;
	}

	public function toString():String {
		var s:String = "";

		for (i in 0...key.length) {
			s += key[i] + ": " + Reflect.field(this, key[i]) + (i == key.length - 1 ? "" : "\n");
		}

		// Lib.println(this.queryKey);

		return s;
	}

	public static inline function parse(url:String):UrlData {
		return new UrlData(url);
	}

	private static inline function x(v:String):String {
		return (v != null) ? v : "";
	}

	private static inline function ax(v:String, a:String):String {
		return (v != null) ? a + v : "";
	}

	private static inline function xa(v:String, a:String):String {
		return (v != null) ? v + a : "";
	}

	private function set_source(value:String):String {
		source = value;
		reparse(source, strictMode);
		return value;
	}

	private function set_protocol(value:String):String {
		protocol = value;
		set_source(xa(protocol, ":") + ax(authority, "//") + x(relative));
		return value;
	}

	private function set_authority(value:String):String {
		authority = value;
		set_source(xa(protocol, ":") + ax(authority, "//") + x(relative));
		return value;
	}

	private function set_userInfo(value:String):String {
		userInfo = value;
		set_authority(xa(userInfo, "@") + x(host) + ax(port, ":"));
		return value;
	}

	private function set_user(value:String):String {
		user = value;
		set_userInfo(x(user) + ax(password, ":"));
		return value;
	}

	private function set_password(value:String):String {
		password = value;
		set_userInfo(x(user) + ax(password, ":"));
		return value;
	}

	private function set_host(value:String):String {
		host = value;
		set_authority(xa(userInfo, "@") + x(host) + ax(port, ":"));
		return value;
	}

	private function set_port(value:String):String {
		port = value;
		set_authority(xa(userInfo, "@") + x(host) + ax(port, ":"));
		return value;
	}

	private function set_relative(value:String):String {
		relative = value;
		set_source(xa(protocol, ":") + ax(authority, "//") + x(relative));
		return value;
	}

	private function set_path(value:String):String {
		path = value;
		set_relative(x(path) + ax(query, "?") + ax(anchor, "#"));
		return value;
	}

	private function set_directory(value:String):String {
		directory = value;
		set_path(x(directory) + x(file));
		return value;
	}

	private function set_file(value:String):String {
		file = value;
		set_path(x(directory) + x(file));
		return value;
	}

	private function set_query(value:String):String {
		query = value;
		set_relative(x(path) + ax(query, "?") + ax(anchor, "#"));
		return value;
	}

	private function set_anchor(value:String):String {
		anchor = value;
		set_relative(x(path) + ax(query, "?") + ax(anchor, "#"));
		return value;
	}
}
