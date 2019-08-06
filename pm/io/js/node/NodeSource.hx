package pm.io.js.node;

import pm.async.Future;
import pm.async.Deferred;
import pm.async.Stream;
import pm.io.Chunk;
import pm.io.js.node.NodeSource;

import pm.Error;

// using tink.CoreApi;
using pm.Outcome;

class NodeSource extends Generator<Chunk, Error> {
    function new(target : WrappedReadable) {
        var me = new Future(function (cb) {
            target
            .read()
            .handle(function(o) {
                cb(switch o {
                    case Success(null): End;
                    case Success(chunk): Link(chunk, new NodeSource( target ));
                    case Failure(e): Fail( e );
                });
            });
        });

        super( me );
    }
    
    static public inline function wrap(name, native, chunkSize, onEnd) {
        return new NodeSource(
            new WrappedReadable(
                name,
                native, 
                chunkSize, 
                onEnd
            )
        );
    }
}