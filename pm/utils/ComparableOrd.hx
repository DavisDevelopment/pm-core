package pm.utils;

import pm.Ord;

typedef ComparableOrd<T> = {
  public function compareTo(that : T) : Ordering;
}
