package pm.concurrent.rl;

#if macro
class Boot {
  static function boot() {
    tink.SyntaxHub.transformMain.whenever(function (e) { 
      return 
        macro 
            @:pos(e.pos)
            @:privateAccess 
            pm.concurrent.RunLoop.create(function () {
                #if !no_trace
                trace('runloop begins');
                #end
                
                $e;
            });
    });
  }
}
#else 
typedef Boot = Any;
#end