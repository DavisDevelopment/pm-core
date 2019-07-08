package pm;

import haxe.macro.Expr;

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

    public static function tap<T>(x:T, fn:T->Void):T {
        fn( x );
        return x;
    }
    public static inline function vtap<T>(x:T, fn:T -> Void):Void {
        return fn( x );
    }
}
