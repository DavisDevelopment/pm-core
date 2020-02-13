package pm;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;

using haxe.macro.ExprTools;
#end

class Helpers {
    public static macro function matchFor<I, O>(e:ExprOf<Dynamic>, args:Array<Expr>) {
        switch args {
            case [pattern, ifMatched, ifElse], [macro $pattern => $ifMatched, ifElse], [macro $pattern ? $ifMatched : $ifElse]:
                return macro switch ($e) {
                    case $pattern:
                        $ifMatched;

                    default:
                        $ifElse;
                }

            case [pattern, ret]:
                return macro switch ($e) {
                    case $a{[pattern]}: $ret;
                    default: throw 'Match failed';
                }

            case [pattern]:
                return macro switch ($e) {
                    case $pattern: true;
                    default: false;
                }

            default:
                throw 'Nope';
        }
        return macro 'Ya done fucked up';
    }

    public static inline function nor<T>(a:Null<T>, b:Null<T>):Null<T> {
        return if (a == null) b else a;
    }

    public static inline function nn<T>(v:Null<T>):Bool
        return null != v;

    public static inline function nnSlow<T>(v: Null<T>):Bool {
        return !(Type.typeof(v).match(Type.ValueType.TNull));
    }

    public static function tap<T>(x:T, fn:T->Void):T {
        fn( x );
        return x;
    }
    public static inline function vtap<T>(x:T, fn:T -> Void):Void {
        return fn( x );
    }

    /**
      check for "strict equality" between `a` and `b`
      this is only different from the `==` operator on `js` & `python` targets as of now
        `js: a === b`
        `py:(a is b)`
     **/
    public static function same<T>(a:T, b:T):Bool {
        return
        #if js js.Syntax.strictEq(a, b);
        #elseif python untyped __python__('({0} is {1})', a, b);
        #else (a == b);
        #end
    }
    public static inline function strictEq<T>(a:T, b:T):Bool return inline Helpers.same(a, b);


}

class MacroHelpers {
    	/**
	 * with
	 * @author Simn <simon@haxe.org>
	 * @link https://gist.github.com/Simn/87948652a840ff544a22
	 */
	macro public static function with(e1:Expr, el:Array<Expr>): Expr {
		var tempName: String = 'tmp';
		var acc: Array<Expr> = [
			macro var $tempName = $e1
		];
		var eThis: Expr = macro $i{tempName};
		for (e in el) {
            var gs:String = null;
            // e = e.replace(macro _, eThis);
			var e = switch (e) {
				case macro $i{s}($a{args}):
                    gs = s;
                    macro $eThis.$s($a{args});
                
				case macro $i{s} = $e:
                    gs = s;
                    macro $eThis.$s = $e;
                    
				case macro $i{s} += $e:
                    gs = s;
                    macro $eThis.$s += $e;
                    
				case macro $i{s} -= $e:
                    gs = s;
                    macro $eThis.$s -= $e;
                    
				case macro $i{s} *= $e:
                    gs = s;
                    macro $eThis.$s *= $e;
                    
				case macro $i{s} /= $e:
                    gs = s;
                    macro $eThis.$s /= $e;
                    
				case _:
					Context.error("Don't know what to do with " + e.toString(), e.pos);
            }

            // var vars = Context.getLocalTVars();
            // for (name=>tvar in vars) {
            //     if (gs == name) {

            //     }
            // }
            // try {
            //     var tmp = macro @:pos(e.pos) $eThis.$s;
            //     var te = Context.typeExpr(tmp);
            //     trace(te);
            //     var t = Context.typeof(tmp);
            //     trace(t);
            // }
            // catch (err: Dynamic) {
            //     // trace('Not found: $e');
            //     Context.error('Not found: $err', e.pos);
            //     // continue;
            // }
            
			acc.push(e);
        }
        
		return macro $b{acc};
	}
}
