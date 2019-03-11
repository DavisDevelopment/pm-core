package pm;

interface IStack<T> extends Collection<T> {
    function push(v: T):Void;
    function pop():T;
    function top():T;
}
