package pm;

class Pair<A, B> {
    public final left: A;
    public final right: B;

    public function new(a:A, b:B) {
        left = a;
        right = b;
    }

    public function toString():String {
        return 'Pair($left, $right)';
    }

    public static inline function of<L, R>(l:L, r:R):Pair<L, R> {
        return new Pair(l, r);
    }
}
