package pm.io;

import haxe.PosInfos;
import Type.ValueType;
import pm.Error;
import haxe.ds.Option;

using pm.Strings;
using pm.Options;

class IOError extends TypedIOError<Dynamic> {}
class AbstractError extends IOError {
    public function new(?msg, ?pos:PosInfos) {
        super(EAbstract, null, msg, pos);
    }
}
class InvalidError extends IOError {
    function new(i, ?value, ?msg, ?pos) {
        super(IOErrorType.EInvalid(i), value, msg, pos);
    }
}
class NullError extends InvalidError {
    public function new(?value, ?msg, ?pos) {
        super(INull, value, msg, pos);
    }
}
class OutsideBoundsError extends InvalidError {
    public function new(?value, ?msg, ?pos) {
        super(IOutsideBounds, value, msg, pos);
    }
}

class TypedIOError<T> extends ValueError<Option<T>> {
    public function new(type, ?value:T, ?msg, ?name, ?pos:haxe.PosInfos) {
        this.type = type;
        super(value.opt(), msg, name, pos);
    }

    override function toString():String {
        return '${label(type)}: ${msg()}';
    }

    function label(t: IOErrorType) {
        return switch type {
            case EAbstract: 'Abstract';
            case EInvalid(i): switch i {
                case INull: 'NullPointer';
                case IOutsideBounds: 'OutsideBounds';
                case IOverflow: 'Overflow';
                case IUnexpected(value): Std.string(value);
                case IType(type): switch type {
                    case TNull: 'Null<?>';
                    case TInt: 'Int';
                    case TFloat: 'Float';
                    case TBool: 'Bool';
                    case TClass(ctype): Type.getClassName(ctype);
                    case TEnum(etype): Type.getEnumName(etype);
                    case TFunction: 'Function';
                    case TObject: 'Object';
                    case TUnknown: 'Any';
                }
            }
        }
    }

    function msg() {
        return this.message;
    }

    public var type(default, null): IOErrorType;
}

enum IOErrorType {
    EAbstract;
    EInvalid(i: Invalid);
}

enum Invalid {
    INull;
    IOutsideBounds;
    IOverflow;
    IType(expected: Type.ValueType);
    IUnexpected<T>(value: T);
}