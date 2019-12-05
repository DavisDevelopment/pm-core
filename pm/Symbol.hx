package pm;

import pm.core.BaseTools;
#if js
import js.lib.Symbol as JsSymbol;
#end

@:forward
abstract Symbol(Sym) from Sym to Sym {
    public inline function new(?label) {
        this = new Sym(label);
    }

    public static inline function of(x: Dynamic):Symbol {
        return Sym.of(x);
    }

    public static inline function iterator():Iterator<Symbol> return cast Sym.iterator();

    @:op(A == B)
    public static inline function equality(a:Symbol, b:Symbol):Bool {
        #if js
        return Helpers.strictEq(a.key, b.key);
        #else
        return Helpers.strictEq(a.id, b.id);
        #end
    }

	public static var type = Sym;
	public static inline function is(x:Dynamic):Bool {
		#if js
		return js.Syntax.code('{0}.constructor && {0}.constructor === {1}', x, Symbol.type);
		#else
		return (x is Sym);
		#end
	}
}

private class Sym {
    public final id:Int = HashKey.next();
    public final label: String;
    #if js
    public final key: JsSymbol;
    #end

    public function new(?label: String) {
        if (label != null) {
            this.label = label;
        }
        else {
            this.label = 'Symbol#$id';
        }
        #if js
        this.key = new JsSymbol(this.label);
        #end
    }

    public inline function getKey() {
        return 
        #if js key #else '_hx_symbol_${BaseTools.toBase(id, 10, 'abcdefghijk')}' #end;
    }

/* === Statics === */


    private static var symbols:Map<String, Sym>;
    private static var symbolsById:Map<Int, String>;
    private static function __init__() {
        symbols = new Map();
        symbolsById = new Map();
    }
    public static function of(name: Dynamic):Sym {
        if ((name is Sym)) return cast(name, Sym);
        if ((name is Int)) throw new pm.Error('Unhandled');

        var name = Std.string(name);
        var symbol:Null<Sym> = symbols.get(name);
        if (symbol == null) {
            symbol = new Sym(name);
            symbols[symbol.label] = symbol;
        }
        return symbol;
    }
    public static function iterator() {
        return symbols.iterator();
    }
}