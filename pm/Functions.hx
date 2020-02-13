package pm;

import haxe.Constraints.Function;

#if macro
import haxe.macro.Expr;
import pm.macro.SlambdaMacro;
#end

using pm.Arrays;

class Functions {
    public static function identity<T>(value: T):T {
        return value;
    }

    public static function equality<T>(a:T, b:T):Bool {
        return a == b;
    }

    public static function noop():Void {
        // betty
    }

    public static macro function fn(fn:ExprOf<Function>, rest:Array<Expr>) {
        return SlambdaMacro.f(fn, rest);
    }

    // public macro static function with(context:Expr, body:Expr) {
    //     var new_body:Expr = pmdb.utils.macro.Exprs.replace(body, macro _, context);
    //     return macro $new_body;
    // }

    @:noUsing
    public static macro function compose(args: Array<Expr>) {
        return args.reduce(function(out:Expr, arg:Expr):Expr {
            return macro Monads.compose($out, ${SlambdaMacro.f(arg, [])});
        }, SlambdaMacro.f(args.shift(), []));
    }
    
    public static function passTo<A, B>(a:A, f:A -> B):B {
        return f(a);
    }

	#if (js || flash)
	@:extern
	inline
    #end
	/**
	 * computes and returns the arity (number of positional arguments) of the given function pointer
     * [TODO] implementation for Python platform; most likely completely doable
	 * @param f the function whose arity is being computed
	 * @return Int
	 */
	public static function getNumberOfParameters(f: haxe.Constraints.Function):Int {
		#if php
		var rf = untyped __php__("new ReflectionMethod($f[0], $f[1])");
		return rf.getNumberOfParameters();
		#elseif (js || flash)
		return untyped f.length;
        #elseif cpp
        final sf = Std.string(f);
        // trace(sf);
        final i:Int = Std.parseInt(sf.substr(10));
        if (pm.Numbers.isValidNumericValue(i))
            return i;
        #elseif neko
		final sf = Std.string(f);
		return Std.parseInt(sf.split(':')[1]);
        #else
        //
		#end
		throw 'Function.getNumberOfParameters not implemented for current platform';
	}
}

class Nilads {
    public static function join(a:Void->Void, b:Void->Void):Void->Void {
        return function() {
            a();
            b();
        }
    }

    public static function wrap<A, B>(f:Void->A, wrapper:(Void->A)->B):Void->B {
        return function() {
            return wrapper( f );
        }
    }

    public inline static function call(fn: Void->Void) {
        return fn();
    }
}

class VNilads {
    public static function once<T>(fn:Void->T):Void->T {
       var a = [];
        return function() {
            if (a.length == 0)
                a.push(fn());
            return a[0];
        }
    }
}

class Monads {
    public static function identity<T>(x: T):T {
        return x;
    }

    public static function apply<A, B>(a:A, fn:A -> B):B {
        return fn( a );
    }

    public inline static function compose<TIn, TRet1, TRet2>(fa:TRet2->TRet1, fb:TIn->TRet2):TIn->TRet1 {
        return function(v : TIn) {
            return fa(fb(v));
        }
    }

    public static inline function wrap<A, B, ARet, BRet>(f:A->ARet, wrapper:(A->ARet)->B->BRet):B->BRet {
        return (function(b: B):BRet {
            return wrapper(f, b);
        });
    }

    public static inline function join<T>(fa:T->Void, fb:T->Void):T->Void {
        return function(x: T) {
            fa( x );
            fb( x );
        }
    }

    public static function curry<A, B>(fn: A -> B):A -> (Void -> B) {
        return function(a: A) {
            return function() {
                return fn( a );
            }
        }
    }

    public static inline function call<A,B>(f: A -> B, a:A):B {
        return f( a );
    }

    /**
     * The covariant functor for Function1<A, _>
     */
    public inline static function map<A, B, C>(fab:A->B, fbc:B->C):A->C {
        return function(a: A) {
            return fbc(fab(a));
        }
    }

    /**
     * The contravariant functor for Function1<_, B>. Equivalent to compose.
     */
    public inline static function contramap<A, B, C>(fbc: B -> C, fab: A -> B): A -> C {
        return function(a: A) {
            return fbc(fab(a));
        };
    }
}

class VMonads {
    public static function noop<T>(x: T):Void { }
    public static inline function apply<T>(x:T, f:T->Void):T {
        f(x);
        return x;
    }

    public static inline function once<T>(fn: T->Void):T->Void {
        return function(v: T) {
            var t = fn;
            fn = noop;
            t( v );
        }
    }

    public static inline function chain<T>(monad:T -> Void):T -> T {
        return function(x: T):T {
            monad( x );
            return x;
        }
    }
}

class Dyads {
    public static function curry<A, B, C>(f: A -> B -> C): A -> (B -> C) {
        return function(a: A) {
            return function(b) {
                return f(a, b);
            }
        };
    }

    public static function flipArguments<A,B,C>(fn:A->B->C):B->A->C {
        return function(b:B, a:A):C {
            return fn(a, b);
        }
    }

    /**
      `join` creates a function that calls the 2 functions passed as arguments in sequence
      and passes the same argument values to the both of them.
     **/
    public inline static function join<T1, T2>(fa : T1 -> T2 -> Void, fb : T1 -> T2 -> Void) {
        return function(v1 : T1, v2 : T2) {
            fa(v1, v2);
            fb(v1, v2);
        }
    }
    public static inline function wrap<A, B, ARet, BRet>(f:A->B->ARet, wrapper:(A->B->ARet)->A->B->BRet):A->B->BRet {
        return function(a:A, b:B) {
            return wrapper(f, a, b);
        }
    }
    public static inline function call<A,B,C>(f: A -> B -> C, a:A, b:B):C {
        return f(a, b);
    }
}

class Fn3 {
    public inline static function curry<A, B, C, D>(f: A -> B -> C -> D): A -> B -> (C -> D) {
        return function(a: A, b: B) {
            return function(c) {
                return f(a, b, c);
            } 
        };
    }

    public static inline function wrap<A1, B1, C1, A2, B2, C2, Ret1, Ret2>(f:A1->B1->C1->Ret1, wrapper:(A1->B1->C1->Ret1)->A2->B2->C2->Ret2):A2->B2->C2->Ret2 {
        return function(a:A2, b:B2, c:C2):Ret2 {
            return wrapper(f, a, b, c);
        }
    }

    public static function flipArguments<A,B,C,D>(fn:A->B->C->D):C->B->A->D {
        return (c:C, b:B, a:A) -> fn(a, b, c);
    }

    public static inline function call<A,B,C,D>(f: A -> B -> C -> D, a:A, b:B, c:C):D {
        return f(a, b, c);
    }
}

/*
 from: {url}
*/

class Functions4 {
  public inline static function curry<A, B, C, D, E>(f: A -> B -> C -> D -> E): A -> B -> C -> (D -> E)
    return function(a: A, b: B, c: C) { return function(d) { return f(a, b, c, d); } };
}

class Functions5 {
  public inline static function curry<A, B, C, D, E, F>(f: A -> B -> C -> D -> E -> F): A -> B -> C -> D -> (E -> F)
    return function(a: A, b: B, c: C, d: D) { return function(e) { return f(a, b, c, d, e); } };
}

class Functions6 {
  public inline static function curry<A, B, C, D, E, F, G>(f: A -> B -> C -> D -> E -> F -> G): A -> B -> C -> D -> E -> (F -> G)
    return function(a: A, b: B, c: C, d: D, e: E) { return function(f0) { return f(a, b, c, d, e, f0); } };
}

class Functions7 {
  public inline static function curry<A, B, C, D, E, F, G, H>(f: A -> B -> C -> D -> E -> F -> G -> H): A -> B -> C -> D -> E -> F -> (G -> H)
    return function(a: A, b: B, c: C, d: D, e: E, f0: F) { return function(g) { return f(a, b, c, d, e, f0, g); } };
}

class Functions8 {
  public inline static function curry<A, B, C, D, E, F, G, H, I>(f: A -> B -> C -> D -> E -> F -> G -> H -> I): A -> B -> C -> D -> E -> F -> G -> (H -> I)
    return function(a: A, b: B, c: C, d: D, e: E, f0: F, g: G) { return function(h) { return f(a, b, c, d, e, f0, g, h); } };
}

class Functions9 {
  public inline static function curry<A, B, C, D, E, F, G, H, I, J>(f: A -> B -> C -> D -> E -> F -> G -> H -> I -> J): A -> B -> C -> D -> E -> F -> G -> H -> (I -> J)
    return function(a: A, b: B, c: C, d: D, e: E, f0: F, g: G, h: H) { return function(i) { return f(a, b, c, d, e, f0, g, h, i); } };
}

class Functions10 {
  public inline static function curry<A, B, C, D, E, F, G, H, I, J, K>(f: A -> B -> C -> D -> E -> F -> G -> H -> I -> J -> K): A -> B -> C -> D -> E -> F -> G -> H -> I -> (J -> K)
    return function(a: A, b: B, c: C, d: D, e: E, f0: F, g: G, h: H, i: I) { return function(j) { return f(a, b, c, d, e, f0, g, h, i, j); } };
}

class Functions11 {
  public inline static function curry<A, B, C, D, E, F, G, H, I, J, K, L>(f: A -> B -> C -> D -> E -> F -> G -> H -> I -> J -> K -> L): A -> B -> C -> D -> E -> F -> G -> H -> I -> J -> (K -> L)
    return function(a: A, b: B, c: C, d: D, e: E, f0: F, g: G, h: H, i: I, j: J) { return function(k) { return f(a, b, c, d, e, f0, g, h, i, j, k); } };
}

class Functions12 {
  public inline static function curry<A, B, C, D, E, F, G, H, I, J, K, L, M>(f: A -> B -> C -> D -> E -> F -> G -> H -> I -> J -> K -> L -> M): A -> B -> C -> D -> E -> F -> G -> H -> I -> J -> K -> (L -> M)
    return function(a: A, b: B, c: C, d: D, e: E, f0: F, g: G, h: H, i: I, j: J, k: K) { return function(l) { return f(a, b, c, d, e, f0, g, h, i, j, k, l); } };
}

class Functions13 {
  public inline static function curry<A, B, C, D, E, F, G, H, I, J, K, L, M, N>(f: A -> B -> C -> D -> E -> F -> G -> H -> I -> J -> K -> L -> M -> N): A -> B -> C -> D -> E -> F -> G -> H -> I -> J -> K -> L -> (M -> N)
    return function(a: A, b: B, c: C, d: D, e: E, f0: F, g: G, h: H, i: I, j: J, k: K, l: L) { return function(m) { return f(a, b, c, d, e, f0, g, h, i, j, k, l, m); } };
}

class Functions14 {
  public inline static function curry<A, B, C, D, E, F, G, H, I, J, K, L, M, N, O>(f: A -> B -> C -> D -> E -> F -> G -> H -> I -> J -> K -> L -> M -> N -> O): A -> B -> C -> D -> E -> F -> G -> H -> I -> J -> K -> L -> M -> (N -> O)
    return function(a: A, b: B, c: C, d: D, e: E, f0: F, g: G, h: H, i: I, j: J, k: K, l: L, m : M) { return function(n) { return f(a, b, c, d, e, f0, g, h, i, j, k, l, m, n); } };
}

class Functions15 {
  public inline static function curry<A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P>(f: A -> B -> C -> D -> E -> F -> G -> H -> I -> J -> K -> L -> M -> N -> O -> P): A -> B -> C -> D -> E -> F -> G -> H -> I -> J -> K -> L -> M -> N -> (O -> P)
    return function(a: A, b: B, c: C, d: D, e: E, f0: F, g: G, h: H, i: I, j: J, k: K, l: L, m : M, n : N) { return function(o) { return f(a, b, c, d, e, f0, g, h, i, j, k, l, m, n, o); } };
}

class Functions16 {
  public inline static function curry<A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q>(f: A -> B -> C -> D -> E -> F -> G -> H -> I -> J -> K -> L -> M -> N -> O -> P -> Q): A -> B -> C -> D -> E -> F -> G -> H -> I -> J -> K -> L -> M -> N -> O -> (P -> Q)
    return function(a: A, b: B, c: C, d: D, e: E, f0: F, g: G, h: H, i: I, j: J, k: K, l: L, m : M, n : N, o : O) { return function(p) { return f(a, b, c, d, e, f0, g, h, i, j, k, l, m, n, o, p); } };
}

class Functions17 {
  public inline static function curry<A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R>(f: A -> B -> C -> D -> E -> F -> G -> H -> I -> J -> K -> L -> M -> N -> O -> P -> Q -> R): A -> B -> C -> D -> E -> F -> G -> H -> I -> J -> K -> L -> M -> N -> O -> P -> (Q -> R)
    return function(a: A, b: B, c: C, d: D, e: E, f0: F, g: G, h: H, i: I, j: J, k: K, l: L, m : M, n : N, o : O, p : P) { return function(q) { return f(a, b, c, d, e, f0, g, h, i, j, k, l, m, n, o, p, q); } };
}

class Functions18 {
  public inline static function curry<A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R, S>(f: A -> B -> C -> D -> E -> F -> G -> H -> I -> J -> K -> L -> M -> N -> O -> P -> Q -> R -> S): A -> B -> C -> D -> E -> F -> G -> H -> I -> J -> K -> L -> M -> N -> O -> P -> Q -> (R -> S)
    return function(a: A, b: B, c: C, d: D, e: E, f0: F, g: G, h: H, i: I, j: J, k: K, l: L, m : M, n : N, o : O, p : P, q : Q) { return function(r) { return f(a, b, c, d, e, f0, g, h, i, j, k, l, m, n, o, p, q, r); } };
}

class Functions19 {
  public inline static function curry<A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R, S, T>(f: A -> B -> C -> D -> E -> F -> G -> H -> I -> J -> K -> L -> M -> N -> O -> P -> Q -> R -> S -> T): A -> B -> C -> D -> E -> F -> G -> H -> I -> J -> K -> L -> M -> N -> O -> P -> Q -> R -> (S -> T)
    return function(a: A, b: B, c: C, d: D, e: E, f0: F, g: G, h: H, i: I, j: J, k: K, l: L, m : M, n : N, o : O, p : P, q : Q, r : R) { return function(s) { return f(a, b, c, d, e, f0, g, h, i, j, k, l, m, n, o, p, q, r, s); } };
}

class Functions20 {
  public inline static function curry<A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R, S, T, U>(f: A -> B -> C -> D -> E -> F -> G -> H -> I -> J -> K -> L -> M -> N -> O -> P -> Q -> R -> S -> T -> U): A -> B -> C -> D -> E -> F -> G -> H -> I -> J -> K -> L -> M -> N -> O -> P -> Q -> R -> S -> (T -> U)
    return function(a: A, b: B, c: C, d: D, e: E, f0: F, g: G, h: H, i: I, j: J, k: K, l: L, m : M, n : N, o : O, p : P, q : Q, r : R, s : S) { return function(t) { return f(a, b, c, d, e, f0, g, h, i, j, k, l, m, n, o, p, q, r, s, t); } };
}

