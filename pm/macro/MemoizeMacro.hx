package pm.macro;

#if macro
import haxe.macro.Type;
import haxe.macro.Context;
import haxe.macro.Expr;
import haxe.macro.ExprTools;


using haxe.macro.ExprTools;
using pm.Strings;
using pm.Numbers;
using pm.Arrays;

using haxe.macro.TypeTools;
using haxe.macro.ComplexTypeTools;
using pmdb.utils.macro.Exprs;

class MemoizeMacro {
    public static function apply(expr:Expr, type:Type, rest:Array<Expr>) {
        trace('applying memoization transform');
        expr = macro ($expr);
        var cacheType = 'haxe.ds.StringMap';//.asTypePath();
        var resolverType = 'pm.strings.Resolver.IndexedResolver';
        var resolverExpr:Null<Expr> = null;// = macro new pm.strings.Resolver.IndexedResolver();
        
        switch rest {
            case []:
                //

            case rest:
                for (e in rest) switch e {
                    case macro ${_.toString()=>kw} = ${kwv}:
                        switch kw {
                            case 'resolver':
                                resolverExpr = kwv;

                            case 'resolverType' if (resolverExpr == null):
                                resolverType = kwv.getValue();

                            case 'cacheType':
                                cacheType = kwv.getValue();

                            case _:
                                throw kw;
                        }

                    default:
                        throw e;
                }
        }
        var rtp = resolverType.asTypePath();
        var resExpr:Expr = resolverExpr != null ? resolverExpr : (macro new $rtp());
        var cacheCtorCType = cacheType.asTypePath();
        
        switch type {
            case TFun(fargs, ret):
                var resArgs = macro $a{fargs.map(a -> macro untyped $i{a.name})};
                var wrapperFn = ExprDef.EFunction(null, {
                    args: fargs.map(a -> {
                        var arg:FunctionArg;
                        arg = {
                            name: a.name, 
                            opt: a.opt, 
                            type: a.t.toComplexType(),
                            value: null,
                            meta: null 
                        };
                        arg;
                    }),
                    ret: ret != null ? ret.toComplexType() : null,
                    expr: macro @:mergeBlock {
                        var memKey = resolver.resolve($resArgs);
                        if (cash.exists(memKey)) {
                            return cash.get(memKey);
                        }
                        else {
                            return {
                                var result = tmp($a{fargs.map(function(a) {
                                    return macro $i{a.name};
                                })});
                                cash.set(memKey, result);
                                result;
                            };
                        }
                        throw 'unreachable';
                    }
                });
                var output:Expr = macro @:pos(expr.pos) null;
                output.expr = wrapperFn;
                output = macro @:mergeBlock {
                    // macro @:mergeBlock {
                        var tmp = ${expr};
                        var resolver:pm.strings.Resolver = $resExpr;
                        var cash = new $cacheCtorCType();
                    // }
                    $output;
                };
                trace(output.toString());
                return output;

            default:
                throw 'Stuff';
        }
    }
}
#end