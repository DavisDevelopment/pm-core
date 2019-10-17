package pm.concurrent.rl;

import pm.concurrent.RunLoop;

interface Worker {
    var id(get, never):String;
    var owner(get, never):RunLoop;
    
    /**
    * Schedules a task on the worker, performed after all previously scheduled tasks.
    */
    function work(task: Task):Task;
    
    /**
    * Performs the task as soon as possible.
    */
    function asap(task: Task):Task;
    
    /**
    * Performs the task when the worker performs its next step.
    */
    function atNextStep(task: Task):Task;
    
    /**
    * Gives a worker the opportunity to progress.
    */
    function step():WorkResult;
    
    function kill():Void;
}

enum WorkResult {
  Progressed;
//   Waiting(seconds: Float);
  /**
   * 
   */
  Idle;
  /**
   * 
   */
  Done;
  /**
   * 
   */
  Aborted;

  /**
   * Returned when attempting to cause a worker step from the wrong thread.
   */
//   WrongThread;
}