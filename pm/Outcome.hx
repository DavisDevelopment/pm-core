package pm;

import haxe.ds.Option;

using pm.Options;

@:using(pm.Outcome.Outcomes)
@:using(pm.Outcome.OptionOutcomes)
enum Outcome<Result, Error> {
    Success(result: Result);
    Failure(error: Error);
}

class Outcomes {
    /**
      check if the given Outcome is a success
     **/
    public static function isSuccess<T, Err>(o:Outcome<T, Err>):Bool {
        return o.match(Success(_));
    }

    /**
      check if the given Outcome is a failure
     **/
    public static function isFailure<T, Err>(o:Outcome<T, Err>):Bool {
        return o.match(Failure(_));
    }

    /**
      if [o] is a success Outcome, return its value
      else if [o] is a failure Outcome, throw its value
     **/
    public static function manifest<T, Err>(o: Outcome<T, Err>):T {
        switch ( o ) {
            case Success( value ): 
                return value;

            case Failure( error ):
                throw error;
        }
    }
    public static inline function sure<D,F>(o: Outcome<D, F>):D {
        return manifest( o );
    }

    public static function toOption<D, F>(o: Outcome<D, F>):Option<D> {
        return switch o {
            case Success(x): Some(x);
            case Failure(_): None;
        }
    }

    public static function flatMap<D1,F1,D2>(o:Outcome<D1,F1>, f:D1->Outcome<D2, F1>):Outcome<D2, F1> {
        return switch o {
            case Success(res): f(res);
            case Failure(x): Failure(x);
        }
    }
    public static inline function map<A, B, Err>(o:Outcome<A, Err>, f:A -> B):Outcome<B, Err> {
        return switch o {
            case Success(a): Success(f(a));
            case Failure(err): Failure(err);
        }
    }
}

class OptionOutcomes {
    public static function map<A, B, Err>(o:Outcome<Option<A>, Err>, fn:A -> B):Outcome<Option<B>, Err> {
        return switch o {
            case Failure(e): Failure(e);
            case Success(o): Success(o.map(fn));
        }
    }
}