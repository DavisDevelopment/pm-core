package pm;

interface Itr<T> {
    function hasNext():Bool;
    function next():T;
    function remove():Void;
    function reset():Itr<T>;
}
