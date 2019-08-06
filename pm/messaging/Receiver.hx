package pm.messaging;

import pm.async.Callback;
import pm.async.Signal;

using pm.Options;
using pm.Functions;

@:forward
abstract Receiver<Msg> (AReceiver<Msg>) from AReceiver<Msg> {
    
}

class UReceiver<Msg> extends AReceiver<Msg> {
    private var underlying(default, set): AReceiver<Dynamic>;
    private var validate: Dynamic -> Bool;
    private var transform: Dynamic -> Msg;
    
    private var _conn : CallbackLink = null;

    public function new(r, ?isValid, ?transform) {
        //this.underlying = r;
        
        switch [isValid, transform] {
            case [null, null]:
                throw new pm.Error('Either "isValid" or "transform" must be provided');

            case [null, transform]:
                var tmp = transform;// cooked:pm.Ref<haxe.ds.Option<Msg>> = Ref.to(None);
                isValid = function(raw: Dynamic) {
                    try {
                        var thaw = tmp(raw);

                        return true;
                    }
                    catch (err : Dynamic) {
                        return false;
                    }
                };
                
                transform = function(raw: Dynamic):Msg {
                    return transform(raw);
                }

            case [validate, transform]:
                //...
        }

        this.validate = isValid;
        this.transform = transform;

        this._bridge = 

        this.underlying = r;
        _bindTo(this.underlying);
    }

    function _bridge(raw: Dynamic) {
        if (validate( raw )) {
            push(transform(raw));
        }
    }

    function _bindTo(r: AReceiver<Dynamic>) {
        r.received.listen(this._bridge);
    }

    override function open() {
        
        underlying.open();
    }
}

class AReceiver<Msg> {
    public final key:Int = pm.HashKey.next();
    public final received: Signal<Msg> = new Signal();

    public function open() {
        throw new AbstractMethodError();
    }
    
    public function close() {
        throw new AbstractMethodError();
    }

    public function push(message: Msg) {
        received.broadcast( message );
    }
}

class AbstractMethodError extends pm.Error {
    public function new(?msg:String, ?pos:haxe.PosInfos) {
        if (msg == null) {
            super('${pos.className}::${pos.methodName}', pos);
        }
        else {
            super('${pos.className}::${pos.methodName} - $msg', pos);
        }
    }
}