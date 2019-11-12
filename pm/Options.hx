package pm;

import haxe.ds.Option;

import pm.Lazy;
import pm.Error;

using pm.Options;

class Options {
    public static function isSome<T>(o: Option<T>):Bool {
        return o.match(Some(_));
    }

    public static function isNone<T>(o: Option<T>):Bool {
        return o.match(None);
    }

    public static function map<A, B>(o:Option<A>, fn:A -> B):Option<B> {
        return switch o {
            case None: None;
            case Some(a): Some(fn(a));
        }
    }

    public static function flatMap<A, B>(o:Option<A>, fn:A -> Option<B>):Option<B> {
        return switch o {
            case Some(a): fn(a);
            case None: None;
        }
    }

    public static function filter<T>(o:Option<T>, fn:T -> Bool):Option<T> {
        return flatMap(o, x -> fn(x) ? Some(x) : None);
    }

    public static function orOpt<T>(a:Option<T>, b:Option<T>):Option<T> {
        return switch a {
            case Some(_): a;
            case None: switch b {
                case Some(_): b;
                case None: None;
            }
        }
    }

    public static function lazyOr<T>(o:Option<T>, defaultValue:Lazy<T>):Option<T> {
        return switch o {
            case None: Some(defaultValue.get());
            default: o;
        }
    }

    public static function getValue<T>(o: Option<T>):Null<T> {
        return switch o {
            case Some(value): value;
            case None: null;
        }
    }

    public static function extract<T>(o:Option<T>, error:Lazy<Dynamic>):T {
        return switch o {
            case Some(v): v;
            case None: throw error.get();
        }
    }
}

class Options2 {
    public static function or<T>(o:Option<T>, defaultValue:OptionAlternative<T>):Option<T> {
        return switch o {
            case None: defaultValue.toOption();
            default: o;
        }
    }
    public static function touch<T>(o:Option<T>, notNull:Bool=true, ?pos:haxe.PosInfos):T {
        return switch o {
            case Some(null) if (notNull):
                throw new pm.Error('Option.Some\'s value was null', null, pos);
            case Some(value): value;
            case None:
                throw new pm.Error('Option.None', 'InvalidArgument', pos);
        }
    }
}

class Nullables {
    public static inline function opt<T>(v: Null<T>):Option<T> {
        return v == null ? None : Some( v );
    }
}

@:forward
abstract OptionAlternative<T> (Option<Lazy<T>>) from Option<Lazy<T>> {
    @:to public inline function toOption():Option<T> {
        return this.map(lazy -> lazy.get());
    }
    @:from public static inline function lazy<T>(value: Lazy<T>):OptionAlternative<T> {
        return Some(value);
    }
    @:from public static inline function getter<T>(getter: Void->T):OptionAlternative<T> {
        return Some(Lazy.ofFn(getter));
    }
    @:from public static inline function const<T>(value: T):OptionAlternative<T> {
        return lazy(Lazy.ofConst(value));
    }
}