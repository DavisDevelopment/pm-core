package pm.concurrent.rl;

import pm.LinkedQueue as Queue;
import pm.concurrent.rl.Worker;

class QueueWorker implements Worker {
    public var id(get, null):String;
    inline function get_id() return this.id;

    public var owner(get, null):RunLoop;
    inline function get_owner() return this.owner;

    var tasks: Array<Task>;
    
    public function new(owner, id) {
        this.id = id;
        this.tasks = [];
        this.owner = owner;
    }

    public inline function hasTaskList():Bool {
        return tasks != null;
    }

    public function log(v:Dynamic, ?p:haxe.PosInfos) {
        owner.log(v, p);
    }

    public function work(task: Task):Task {
        if (task.state == Pending) {
            tasks.push( task );
        }
        return task;
    }

    public function atNextStep(task:Task):Task {
        if (task.state == Pending)
            tasks.unshift( task );
        return task;
    }

    public function asap(task: Task):Task {
        /*
        if (this.thread == Thread.current) 
            task.perform();
        else 
            atNextStep(task);
        */
        /** [TODO] determine alternative method for deciding when to invoke `task` **/
        work( task );
        return task;
    }

    public function kill() {
        tasks = null;
    }

    function error(e:Dynamic, t:Task) {
        // owner.asap(function () owner.onError(e, t, this, haxe.CallStack.exceptionStack()));
        owner.asap(function() {
            throw e;
        });
    }

    function execute(t: Task):WorkResult {
        if (t == null) {
            return Idle;
        }
        else {
            try {
                t.perform();
                if ( t.recurring )
                    work( t );
            }
            catch (e: Dynamic) {
                #if js untyped console.error(e); #end
                error(e, t);
            }
            
            return Progressed;
        }
    }
        
    public function toString() { 
        return 'Worker:$id';
    }

    final public function step():WorkResult { 
        return doStep();
    }
        
    function doStep():WorkResult {
        if (tasks == null) {
            return Aborted;
        }
        else {
            trace('next task');
            var nt = tasks.shift();
            return execute( nt );
            // else {
            //     tasks = null;
            //     Aborted;
            // }
        }
    }
}