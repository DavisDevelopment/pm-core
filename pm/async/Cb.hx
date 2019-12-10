package pm.async;

import pm.Error;
import pm.Assert.assert;

import haxe.macro.Expr;

import pm.Outcome;
import haxe.ds.Option;
import haxe.ds.Either;
using pm.Options;
using pm.Functions;

typedef CbThrowsMonad<Result, Failure> = (o: Outcome<Result, Failure>)->Void;
typedef CbThrowsDyad<R, E> = (error:Null<E>, result:Null<R>)->Void;

@:forward
abstract CbThrows<Res, Err>(Either<CbThrowsMonad<Res, Err>, CbThrowsDyad<Res, Err>>) from Either<CbThrowsMonad<Res, Err>, CbThrowsDyad<Res, Err>> {
    @:from public static inline function monad<R,E>(f: CbThrowsMonad<R, E>):CbThrows<R, E> {
        return Either.Left(f);
    }
	@:from public static inline function dyad<R, E>(f:CbThrowsDyad<R, E>):CbThrows<R, E> {
		return Either.Right(f);
	}
    public inline function merge():CbThrows<Res, Err> {
        return switch this {
            case Left(f): f;
            case Right(f):
                function _f(o: Outcome<Res, Err>) {
                    switch o {
                        case Success(r):
                            f(null, r);
                        case Failure(e):
                            f(e, null);
                    }
                }
                _f;
        }
    }
    public inline function split():CbThrows<Res, Err> {
        return switch this {
            case Right(f): f;
            case Left(f):
                function _f(error:Null<Err>, result:Null<Res>) {
                    if (error != null)
                        return f(Failure(error));
                    return f(Success((result : Res)));
                }
                _f;
        }
    }
    public function asMonad():Null<CbThrowsMonad<Res, Err>> {
        return switch this {
            case Left(f): f;
            default: null;
        }
    }
    public function asDyad():Null<CbThrowsDyad<Res, Err>> {
        return switch this {
            case Right(v): v;
            default: null;
        }
    }
    @:to
    public function toMonad():CbThrowsMonad<Res, Err> {
        return merge().asMonad();
    }
    @:to
    public function toDyad() {
        return split().asDyad();
    }

    public function call1(outcome:Outcome<Res, Err>, coerce=false) {
        var f = asMonad();
        if (coerce && f==null) {
            switch outcome {
                case Success(r):
                    call2(null, r);
                case Failure(e):
                    call2(e, null);
            }
            return ;
        }
        f(outcome);
    }

    public function call2(error:Null<Err>, result:Null<Res>, coerce=false) {
        var f = asDyad();
        if (coerce && f==null) {
            return call1(if (error != null) Failure((error : Err)) else Success((result : Res)));
        }
        return f(error, result);
    }

    public macro function call(self:ExprOf<CbThrows<Res, Err>>, args:Array<Expr>) {
        return switch args {
            case [a]: macro $self.call1(${a}, true);
            case [a, b]: macro $self.call2($a, $b, true);
        }
    }
}

typedef TCb<T> = CbThrows<T, Dynamic>;
@:forward
abstract Cb<T> (TCb<T>) from TCb<T> to TCb<T> {
    
}