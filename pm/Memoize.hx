package pm;

import haxe.macro.Compiler;
import haxe.ds.StringMap;
#if macro
import haxe.macro.Context;
import pm.macro.MemoizeMacro;
#end

import haxe.Constraints.IMap;
import haxe.Constraints.Constructible;
import haxe.Constraints.Function;

import haxe.ds.Option;

import pm.strings.HashCode.*;
import pm.strings.Resolver;
import pm.Helpers.nor;

using pm.Strings;
using pm.strings.HashCodeTools;
using pm.Arrays;
using pm.Functions;

class Memoize {
    // #if !macro
    public static macro function memoize<Funk:Function>(f:haxe.macro.Expr.ExprOf<Funk>, args:Array<haxe.macro.Expr>) {
        for (d=>v in Context.getDefines())
            Sys.println('-D $d=$v');

        if (!args.empty()) switch args[0].expr {
            case EArrayDecl(values):
                args = values;
            default:
        }

        switch Context.typeof(f) {
            case ft=TFun(_, _):
                return MemoizeMacro.apply(f, ft, args);

            case _:
                return macro throw "EAT MY ASS!";
        }
    }
    // #else
    // public static function memoize<F>(f:Dynamic, ?args:Array<Dynamic>):Dynamic {
    //     trace('Nigga naw');
    //     throw 'should never be called';
    // }
    // #end

    public static function dynamicMemoize<Funk:Function>(f:Funk, config:{?resolver:Resolver, ?cache:IMap<String, Dynamic>, ?proxy:(args: Array<Dynamic>)->Array<Dynamic>, ?target:Dynamic}):Funk {
        var cash = nor(config.cache, new StringMap());
        var resolver = nor(config.resolver, Resolver.DEFAULT);
        function varg(argList: Array<Dynamic>):Dynamic {
            var originalArgs = argList;
            if (config.proxy != null)
                argList = config.proxy(argList.copy());
            var mkey = resolver.resolve(argList);
            if (cash.exists(mkey))
                return cash.get(mkey);
            else {
                var v = Reflect.callMethod(config.target, f, originalArgs);
                cash.set(mkey, v);
                return v;
            }
        }
        return (Reflect.makeVarArgs(varg) : Funk);
    }
}