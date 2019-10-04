package pm.strings;

import pm.ImmutableList.ListRepr;

using pm.Arrays;

typedef TResolverOf<From, To> = {
    function resolve(x: From):To;
}

typedef TResolver = TResolverOf<Array<Dynamic>, String>;

@:forward
abstract Resolver (TResolver) from TResolver {
    public static var DEFAULT:Resolver = new StringResolver();

    public static inline function indexed():IndexedResolver return new IndexedResolver();
    public static inline function signed(init, varArg):SignedResolver {
        return new SignedResolver(init, varArg);
    }
}

class StringResolver {
    public function new(){}
    public function resolve(args:Array<Dynamic>):String {
        return Std.string(args);
    }
}

class FnResolverOf<A, B> {
    public var f(default, null):(a: A)->B;
    public inline function new(f) {
        this.f = f;
    }
    public function resolve(a: A):B return f(a);
}
class SignedResolver {
    var signatures: ImmutableList<Array<TResolverOf<Dynamic, String>>>;
    var varArgResolver: Null<Resolver> = null;
    public function new(?s:Iterable<Iterable<TResolverOf<Dynamic, String>>>, ?varArgResolver) {
        this.signatures = null;
        if (s != null) {
            this.signatures = [for (y in s) [for (x in y) x]];
        }
        this.varArgResolver = varArgResolver;
    }

    function add(l: ImmutableList<TResolverOf<Dynamic, String>>) {
        signatures = Hd(l.toArray(), signatures);
    }

    public function resolve(args: Array<Dynamic>):String {
        var len = args.length;
        for (resList in signatures) {
            if (len == resList.length) {
                try {
                    return args.zip(resList, (v, r) -> r.resolve(v)).join(',');
                }
                catch (e: Dynamic) {
                    continue;
                }
            }
        }
        
        if (varArgResolver != null) {
            return varArgResolver.resolve(args);
        }

        throw 'Unhandled .resolve($args) call!';
    }
}

class IndexedResolver {
    public var argCache:Array<Dynamic> = [];

    public function new() {
        //
    }

    public function getIndex(arg: Dynamic):Int {
        var idx:Int = argCache.indexOf(arg);
        
        if (idx == -1) {
            idx = argCache.length;
            argCache.push(arg);
        }
        
        return idx;
    }

    public function resolve(args: Array<Dynamic>):String {
        var sbuf = new StringBuf();
        for (a in args) {
            sbuf.add(getIndex(a));
            sbuf.addChar(",".code);
        }
        
        return sbuf.toString();
    }
}