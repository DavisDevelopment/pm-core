package pm;

import pm.Lazy;

import haxe.PosInfos;

class Assert {
    /**
      throws an error if [condition] is not met
     **/
    public static inline function assert(condition:Bool, ?error:Dynamic, ?pos:PosInfos):Void {
        #if (debug || keep_assertions)
        if ( !condition )
            _toss(error, pos);
        #end
    }

    /**
      throws an error if [fn] doesn't cause an error to be thrown
     **/
    public static inline function assertThrows<E>(fn:Void->Void, ?msg:Lazy<E>, ?pos:PosInfos):Void {
        #if (debug || keep_assertions)
        try {
            fn();
            _toss(msg, pos);
        }
        catch (e: Dynamic) {
            //
        }
        #end
    }

    /**
      utility method for throwing an exception
     **/
    private static function _toss(?error:Dynamic, ?pos:PosInfos) {
        if (error == null) {
            throw new AssertionFailureError(error, pos);
        }
        else {
            throw error;
        }
    }
}

class AssertionFailureError extends Error {}
