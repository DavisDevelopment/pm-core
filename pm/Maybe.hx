package pm;

import haxe.ds.Option;
import haxe.macro.Expr;
import haxe.macro.Context;

using pm.Options;

@:forward
abstract Maybe<T> (Option<T>) from Option<T> to Option<T> {

    @:op( a.field )
    public static macro function getattr<T>(self:ExprOf<Maybe<T>>, attr) {
        return macro ($self * (a -> a.$attr));
    }
    
    // @:to 
    // public inline function isSome():Bool return Maybe.asBoolean(this);

    /**
      ensures that `this` actually has an assigned value, and 
     **/
    @:to
    @:op(~A)
    public function unwrap():T {
        return this.extract(() -> new pm.Error.InvalidOperation(macro pm.Maybe.extract(None), 'Cannot unwrap VOID pointer'));
    }

    @:op( A! )
    public static function asBoolean<T>(m: Maybe<T>):Bool {
        return m.isSome();
    }
    
    @:to 
    public inline function isSome():Bool {
        return asBoolean(this);
    }

    @:op( !A ) 
    public inline function isNone():Bool return this.isNone();
    
    @:op(A | B)
    public function or(that: Maybe<T>):Maybe<T> {
        return if (isSome()) this else that;
    }

    @:op(A | B)
    public static function withDefaultValue<T>(maybe:Maybe<T>, defaultValue:Lazy<T>):Maybe<T> {
        return maybe | Some(defaultValue.get());
    }
    @:op(A | B) static function withDefaultConst<T>(maybe:Maybe<T>, c:T):Maybe<T> return withDefaultValue(maybe, c);
    @:op(A | B) static function withDefaultLazy<T>(maybe:Maybe<T>, c:Void->T):Maybe<T> return withDefaultValue(maybe, c);

    @:op(A & B)
    public function join<U>(that: Maybe<U>):Maybe<Pair<T, U>> {
        return switch [this, that] {
            case [Some(x), Some(y)]: Some(new Pair(x, y));
            case [None, _]|[_, None]: None;
        }
    }
    @:op(A * B)
    public static function applyCombinator<Left, Right, Result>(both:Maybe<Pair<Left, Right>>, merge:Left -> Right -> Result):Maybe<Result> {
        return both.map(_pair -> merge(_pair.left, _pair.right));
    }
    @:op(A * B)
    public static function applyMapping<I, O>(maybe:Maybe<I>, operation:I -> Maybe<O>):Maybe<O> {
        return maybe.flatMap(operation);
    }
    @:op(A * B)
    static inline function applyVMap<I,O>(m:Maybe<I>, f:I->O):Maybe<O> return m.map(f);

    @:op(A == B)
    static inline function equality<T>(a:Maybe<T>, b:Maybe<T>):Bool {
        return a.equals( b );
    }

    @:op(A && B)
    public static inline function and<A, B>(a:Maybe<A>, b:Maybe<B>):Bool return (a.isSome() && b.isSome());

    // @:op(A & B)
    // public static inline function 

    @:from
    public static inline function some<T>(value: T):Maybe<T> return Some(value);
}