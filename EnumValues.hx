package pm;

class EnumValues {
    public static function copy<E>(value:#if macro Dynamic #else EnumValue #end, e:Enum<E>, ?args:Array<Dynamic>->Array<Dynamic>):E {
        if (args == null) args = pm.Functions.Monads.identity;
        return e.createByIndex(value.getIndex(), args(value.getParameters()));
    }
}
