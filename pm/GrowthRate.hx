package pm;

import pm.Assert.assert;

enum abstract GrowthRate (Int) from Int to Int {
    var DOUBLE = -3;
    var NORMAL;
    var MILD;
    var FIXED;

    public inline function compute(capacity: Int):Int {
        return CGrowthRate.compute(this, capacity);
    }
}

class CGrowthRate {
	/**
		Fixed size; throws an error if additional space is requested.
	**/
	inline public static var FIXED = 0;
	
	/**
		Grows at a rate of 1.125x plus a constant.
	**/
	inline public static var MILD = -1;
	
	/**
		Grows at a rate of 1.5x (default value).
	**/
	inline public static var NORMAL = -2;
	
	/**
		Grows at a rate of 2.0x.
	**/
	inline public static var DOUBLE = -3;
	
	/**
		Computes a new capacity from the given growth `rate` constant and the current `capacity`.
		
		If `rate` > 0, `capacity` grows at a constant rate: `newCapacity = capacity + rate`
	**/
	public static function compute(rate:Int, capacity:Int):Int {
		assert(rate >= -3, "invalid growth rate");
		
		if (rate > 0) {
			capacity += rate;
        }
		else {
			switch (rate) {
				case FIXED: 
				    throw "out of space";
				
				case MILD:
					var newSize = capacity + 1;
					capacity = (newSize >> 3) + (newSize < 9 ? 3 : 6);
					capacity += newSize;
				
				case NORMAL: 
				    capacity = ((capacity * 3) >> 1) + 1;
				
				case DOUBLE: 
				    capacity <<= 1;
			}
		}
		return capacity;
	}
}
