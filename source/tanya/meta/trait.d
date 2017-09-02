/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Type traits.
 *
 * Templates in this module are used to obtain type information at compile
 * time.
 *
 * Copyright: Eugene Wissner 2017.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/meta/trait.d,
 *                 tanya/meta/trait.d)
 */
module tanya.meta.trait;

import tanya.meta.metafunction;
import tanya.meta.transform;

/**
 * Determines whether $(D_PARAM T) is a wide string, i.e. consists of
 * $(D_KEYWORD dchar).
 *
 * The character type of the string can be qualified with $(D_KEYWORD const),
 * $(D_KEYWORD immutable) or $(D_KEYWORD inout), but an occurrence of
 * $(D_KEYWORD shared) in the character type results in returning
 * $(D_KEYWORD false).
 * The string itself (in contrast to its character type) can have any type
 * qualifiers.
 *
 * Static $(D_KEYWORD char) and $(D_KEYWORD wchar) arrays are not considered
 * strings.
 *
 * Params:
 *  T = A Type.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM T) is a wide string,
 *          $(D_KEYWORD false) otherwise.
 *
 * See_Also: $(D_PSYMBOL isNarrowString).
 */
enum bool isWideString(T) = is(T : const dchar[]) && !isStaticArray!T;

///
pure nothrow @safe @nogc unittest
{
    static assert(isWideString!(dchar[]));
    static assert(!isWideString!(char[]));
    static assert(!isWideString!(wchar[]));

    static assert(isWideString!dstring);
    static assert(!isWideString!string);
    static assert(!isWideString!wstring);

    static assert(isWideString!(const dstring));
    static assert(!isWideString!(const string));
    static assert(!isWideString!(const wstring));

    static assert(isWideString!(shared dstring));
    static assert(!isWideString!(shared string));
    static assert(!isWideString!(shared wstring));

    static assert(isWideString!(const(dchar)[]));
    static assert(isWideString!(inout(dchar)[]));
    static assert(!isWideString!(shared(const(dchar))[]));
    static assert(!isWideString!(shared(dchar)[]));
    static assert(!isWideString!(dchar[10]));
}

/**
 * Finds the type with the smallest size in the $(D_PARAM Args) list. If
 * several types have the same type, the leftmost is returned.
 *
 * Params:
 *  Args = Type list.
 *
 * Returns: The smallest type.
 *
 * See_Also: $(D_PSYMBOL Largest).
 */
template Smallest(Args...)
if (Args.length >= 1)
{
    static assert(is(Args[0]), T.stringof ~ " doesn't have .sizeof property");

    static if (Args.length == 1)
    {
        alias Smallest = Args[0];
    }
    else static if (Smallest!(Args[1 .. $]).sizeof < Args[0].sizeof)
    {
        alias Smallest = Smallest!(Args[1 .. $]);
    }
    else
    {
        alias Smallest = Args[0];
    }
}

///
pure nothrow @safe @nogc unittest
{
    static assert(is(Smallest!(int, ushort, uint, short) == ushort));
    static assert(is(Smallest!(short) == short));
    static assert(is(Smallest!(ubyte[8], ubyte[5]) == ubyte[5]));
    static assert(!is(Smallest!(short, 5)));
}

/**
 * Determines whether $(D_PARAM T) is a complex type.
 *
 * Complex types are:
 * $(UL
 *  $(LI cfloat)
 *  $(LI ifloat)
 *  $(LI cdouble)
 *  $(LI idouble)
 *  $(LI creal)
 *  $(LI ireal)
 * )
 *
 * Params:
 *  T = A type.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM T) is a complex type,
 *          $(D_KEYWORD false) otherwise.
 */
enum bool isComplex(T) = is(Unqual!(OriginalType!T) == cfloat)
                      || is(Unqual!(OriginalType!T) == ifloat)
                      || is(Unqual!(OriginalType!T) == cdouble)
                      || is(Unqual!(OriginalType!T) == idouble)
                      || is(Unqual!(OriginalType!T) == creal)
                      || is(Unqual!(OriginalType!T) == ireal);

///
pure nothrow @safe @nogc unittest
{
    static assert(isComplex!cfloat);
    static assert(isComplex!ifloat);
    static assert(isComplex!cdouble);
    static assert(isComplex!idouble);
    static assert(isComplex!creal);
    static assert(isComplex!ireal);

    static assert(!isComplex!float);
    static assert(!isComplex!double);
    static assert(!isComplex!real);
}

/**
 * POD (Plain Old Data) is a $(D_KEYWORD struct) without constructors,
 * destructors and member functions.
 *
 * Params:
 *  T = A type.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM T) is a POD type,
 *          $(D_KEYWORD false) otherwise.
 */
enum bool isPOD(T) = __traits(isPOD, T);

///
pure nothrow @safe @nogc unittest
{
    struct S1
    {
        void method()
        {
        }
    }
    static assert(!isPOD!S1);

    struct S2
    {
        void function() val; // Function pointer, not a member function.
    }
    static assert(isPOD!S2);

    struct S3
    {
        this(this)
        {
        }
    }
    static assert(!isPOD!S3);
}

/**
 * Returns size of the type $(D_PARAM T).
 *
 * Params:
 *  T = A type.
 *
 * Returns: Size of the type $(D_PARAM T).
 */
enum size_t sizeOf(T) = T.sizeof;

///
pure nothrow @safe @nogc unittest
{
    static assert(sizeOf!(bool function()) == size_t.sizeof);
    static assert(sizeOf!bool == 1);
    static assert(sizeOf!short == 2);
    static assert(sizeOf!int == 4);
    static assert(sizeOf!long == 8);
    static assert(sizeOf!(void[16]) == 16);
}

/**
 * Returns the alignment of the type $(D_PARAM T).
 *
 * Params:
 *  T = A type.
 *
 * Returns: Alignment of the type $(D_PARAM T).
 */
enum size_t alignOf(T) = T.alignof;

///
pure nothrow @safe @nogc unittest
{
    static assert(alignOf!bool == bool.alignof);
    static assert(is(typeof(alignOf!bool) == typeof(bool.alignof)));
}

/**
 * Tests whether $(D_INLINECODE Args[0]) and $(D_INLINECODE Args[1]) are the
 * same symbol.
 *
 * Params:
 *  Args = Two symbols to be tested.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM Args) are the same symbol,
 *          $(D_KEYWORD false) otherwise.
 */
template isSame(Args...)
if (Args.length == 2)
{
    enum bool isSame = __traits(isSame, Args[0], Args[1]);
}

///
pure nothrow @safe @nogc unittest
{
    static assert(isSame!("string", "string"));
    static assert(!isSame!(string, immutable(char)[]));
}

/**
 * Tests whether $(D_PARAM T) is a template.
 *
 * $(D_PSYMBOL isTemplate) isn't $(D_KEYWORD true) for template instances,
 * since the latter already represent some type. Only not instantiated
 * templates, i.e. that accept some template parameters, are considered
 * templates.
 *
 * Params:
 *  T = A symbol.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM T) is a template,
 *          $(D_KEYWORD false) otherwise.
 */
enum bool isTemplate(alias T) = __traits(isTemplate, T);

///
pure nothrow @safe @nogc unittest
{
    struct S(T)
    {
    }
    static assert(isTemplate!S);
    static assert(!isTemplate!(S!int));
}

/**
 * Determine whether $(D_PARAM T) is an interface.
 *
 * Params:
 *  T = A type.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM T) is an interface,
 *          $(D_KEYWORD false) otherwise.
 */
enum bool isInterface(T) = is(T == interface);

/**
 * Determine whether $(D_PARAM T) is a class.
 *
 * Params:
 *  T = A type.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM T) is a class
 *          $(D_KEYWORD false) otherwise.
 */
enum bool isClass(T) = is(T == class);

/**
 * Determine whether $(D_PARAM T) is a struct.
 *
 * Params:
 *  T = A type.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM T) is a struct,
 *          $(D_KEYWORD false) otherwise.
 */
enum bool isStruct(T) = is(T == struct);

/**
 * Params:
 *  T      = Aggregate type.
 *  member = Symbol name.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM member) is a static method of
 *          $(D_PARAM T), $(D_KEYWORD false) otherwise.
 */
template hasStaticMember(T, string member)
{
    static if (hasMember!(T, member))
    {
        alias Member = Alias!(__traits(getMember, T, member));

        static if (__traits(isStaticFunction, Member)
                || (!isFunction!Member && is(typeof(&Member))))
        {
            enum bool hasStaticMember = true;
        }
        else
        {
            enum bool hasStaticMember = false;
        }
    }
    else
    {
        enum bool hasStaticMember = false;
    }
}

///
pure nothrow @safe @nogc unittest
{
    struct S
    {
         int member1;
         void member2()
         {
         }
         static int member3;
         static void member4()
         {
         }
         static void function() member5;
    }
    static assert(!hasStaticMember!(S, "member1"));
    static assert(!hasStaticMember!(S, "member2"));
    static assert(hasStaticMember!(S, "member3"));
    static assert(hasStaticMember!(S, "member4"));
    static assert(hasStaticMember!(S, "member5"));
}

version (TanyaPhobos)
{
    public import std.traits : isFloatingPoint,
                               isSigned,
                               isUnsigned,
                               isIntegral,
                               isNumeric,
                               isBoolean,
                               isSomeChar,
                               isScalarType,
                               isBasicType,
                               isPointer,
                               isArray,
                               isStaticArray,
                               isDynamicArray,
                               isAssociativeArray,
                               isBuiltinType,
                               isAggregateType,
                               getUDAs,
                               isNarrowString,
                               isSomeString,
                               mostNegative,
                               Largest,
                               isCopyable,
                               isAbstractClass,
                               isFinalClass,
                               isAbstractFunction,
                               isFinalFunction,
                               isFunctionPointer,
                               isDelegate,
                               isFunction,
                               isSomeFunction,
                               isCallable,
                               hasMember,
                               isMutable,
                               isNested,
                               isNestedFunction,
                               mangledName,
                               isInstanceOf,
                               isImplicitlyConvertible,
                               BaseTypeTuple,
                               TransitiveBaseTypeTuple,
                               BaseClassesTuple,
                               InterfacesTuple,
                               isAssignable,
                               TemplateArgsOf,
                               Parameters,
                               ParameterIdentifierTuple,
                               functionAttributes,
                               ParameterDefaults,
                               hasElaborateDestructor,
                               hasElaborateCopyConstructor,
                               hasElaborateAssign,
                               EnumMembers,
                               classInstanceAlignment,
                               ifTestable,
                               isTypeTuple,
                               isExpressions;
}
else:

/**
 * Determines whether $(D_PARAM T) is a floating point type.
 *
 * Floating point types are:
 * $(UL
 *  $(LI float)
 *  $(LI double)
 *  $(LI real)
 * )
 *
 * Params:
 *  T = A type.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM T) is a floating point type,
 *          $(D_KEYWORD false) otherwise.
 */
enum bool isFloatingPoint(T) = is(Unqual!(OriginalType!T) == double)
                            || is(Unqual!(OriginalType!T) == float)
                            || is(Unqual!(OriginalType!T) == real);

///
pure nothrow @safe @nogc unittest
{
    static assert(isFloatingPoint!float);
    static assert(isFloatingPoint!double);
    static assert(isFloatingPoint!real);
    static assert(isFloatingPoint!(const float));
    static assert(isFloatingPoint!(shared float));
    static assert(isFloatingPoint!(shared const float));
    static assert(!isFloatingPoint!int);
}

/**
 * Determines whether $(D_PARAM T) is a signed numeric type.
 *
 * Signed numeric types are:
 * $(UL
 *  $(LI byte)
 *  $(LI short)
 *  $(LI int)
 *  $(LI long)
 *  $(LI float)
 *  $(LI double)
 *  $(LI real)
 * )
 *
 * Params:
 *  T = A type.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM T) is a signed numeric type,
 *          $(D_KEYWORD false) otherwise.
 *
 * See_Also: $(D_PSYMBOL isUnsigned).
 */
enum bool isSigned(T) = is(Unqual!(OriginalType!T) == byte)
                     || is(Unqual!(OriginalType!T) == short)
                     || is(Unqual!(OriginalType!T) == int)
                     || is(Unqual!(OriginalType!T) == long)
                     || isFloatingPoint!T;

///
pure nothrow @safe @nogc unittest
{
    static assert(isSigned!byte);
    static assert(isSigned!short);
    static assert(isSigned!int);
    static assert(isSigned!long);
    static assert(isSigned!float);
    static assert(isSigned!double);
    static assert(isSigned!real);

    static assert(!isSigned!ubyte);
    static assert(!isSigned!ushort);
    static assert(!isSigned!uint);
    static assert(!isSigned!ulong);
}

/**
 * Determines whether $(D_PARAM T) is an unsigned numeric type.
 *
 * Unsigned numeric types are:
 * $(UL
 *  $(LI ubyte)
 *  $(LI ushort)
 *  $(LI uint)
 *  $(LI ulong)
 * )
 *
 * Params:
 *  T = A type.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM T) is an unsigned numeric type,
 *          $(D_KEYWORD false) otherwise.
 *
 * See_Also: $(D_PSYMBOL isSigned).
 */
enum bool isUnsigned(T) = is(Unqual!(OriginalType!T) == ubyte)
                       || is(Unqual!(OriginalType!T) == ushort)
                       || is(Unqual!(OriginalType!T) == uint)
                       || is(Unqual!(OriginalType!T) == ulong);

///
pure nothrow @safe @nogc unittest
{
    static assert(isUnsigned!ubyte);
    static assert(isUnsigned!ushort);
    static assert(isUnsigned!uint);
    static assert(isUnsigned!ulong);

    static assert(!isUnsigned!byte);
    static assert(!isUnsigned!short);
    static assert(!isUnsigned!int);
    static assert(!isUnsigned!long);
    static assert(!isUnsigned!float);
    static assert(!isUnsigned!double);
    static assert(!isUnsigned!real);
}

/**
 * Determines whether $(D_PARAM T) is an integral type.
 *
 * Integral types are:
 * $(UL
 *  $(LI ubyte)
 *  $(LI ushort)
 *  $(LI uint)
 *  $(LI ulong)
 *  $(LI byte)
 *  $(LI short)
 *  $(LI int)
 *  $(LI long)
 * )
 *
 * Params:
 *  T = A type.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM T) is an integral type,
 *          $(D_KEYWORD false) otherwise.
 */
enum bool isIntegral(T) = isUnsigned!T
                       || is(Unqual!(OriginalType!T) == byte)
                       || is(Unqual!(OriginalType!T) == short)
                       || is(Unqual!(OriginalType!T) == int)
                       || is(Unqual!(OriginalType!T) == long);

///
pure nothrow @safe @nogc unittest
{
    static assert(isIntegral!ubyte);
    static assert(isIntegral!byte);
    static assert(!isIntegral!float);
}

/**
 * Determines whether $(D_PARAM T) is a numeric (floating point, integral or
 * complex) type.
*
 * Params:
 *  T = A type.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM T) is a numeric type,
 *          $(D_KEYWORD false) otherwise.
 *
 * See_Also: $(D_PSYMBOL isIntegral!T),
 *           $(D_PSYMBOL isFloatingPoint),
 *           $(D_PSYMBOL isComplex).
 */
enum bool isNumeric(T) = isIntegral!T || isFloatingPoint!T || isComplex!T;

///
pure nothrow @safe @nogc unittest
{
    alias F = float;
    static assert(isNumeric!F);
    static assert(!isNumeric!bool);
    static assert(!isNumeric!char);
    static assert(!isNumeric!wchar);
}

/**
 * Determines whether $(D_PARAM T) is a boolean type, i.e. $(D_KEYWORD bool).
 *
 * Params:
 *  T = A type.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM T) is a boolean type,
 *          $(D_KEYWORD false) otherwise.
 */
enum bool isBoolean(T) = is(Unqual!(OriginalType!T) == bool);

///
pure nothrow @safe @nogc unittest
{
    static assert(isBoolean!bool);
    static assert(isBoolean!(shared const bool));
    static assert(!isBoolean!(ubyte));
    static assert(!isBoolean!(byte));

    enum E : bool
    {
        t = true,
        f = false,
    }
    static assert(isBoolean!E);

    struct S1
    {
        bool b;
        alias b this;
    }
    static assert(!isBoolean!S1);

    struct S2
    {
        bool opCast(T : bool)()
        {
            return true;
        }
    }
    static assert(!isBoolean!S2);
}

/**
 * Determines whether $(D_PARAM T) is a character type.
 *
 * Character types are:
 *
 * $(UL
 *  $(LI char)
 *  $(LI wchar)
 *  $(LI dchar)
 * )
 *
 * Params:
 *  T = A type.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM T) is a character type,
 *          $(D_KEYWORD false) otherwise.
 */
enum bool isSomeChar(T) = is(Unqual!(OriginalType!T) == char)
                       || is(Unqual!(OriginalType!T) == wchar)
                       || is(Unqual!(OriginalType!T) == dchar);

///
pure nothrow @safe @nogc unittest
{
    static assert(isSomeChar!char);
    static assert(isSomeChar!wchar);
    static assert(isSomeChar!dchar);

    static assert(!isSomeChar!byte);
    static assert(!isSomeChar!ubyte);
    static assert(!isSomeChar!short);
    static assert(!isSomeChar!ushort);
    static assert(!isSomeChar!int);
    static assert(!isSomeChar!uint);
}

/**
 * Determines whether $(D_PARAM T) is a scalar type.
 *
 * Scalar types are numbers, booleans and characters.
 *
 * Params:
 *  T = A type.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM T) is a scalar type,
 *          $(D_KEYWORD false) otherwise.
 *
 * See_Also: $(D_PSYMBOL isNumeric),
 *           $(D_PSYMBOL isBoolean),
 *           $(D_PSYMBOL isSomeChar).
 */
enum bool isScalarType(T) = isNumeric!T || isBoolean!T || isSomeChar!T;

///
pure nothrow @safe @nogc unittest
{
    static assert(isScalarType!int);
    static assert(!isScalarType!(int[]));
}

/**
 * Determines whether $(D_PARAM T) is a basic type.
 *
 * Basic types are scalar types and $(D_KEYWORD void).
 *
 * Params:
 *  T = A type.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM T) is a basic type,
 *          $(D_KEYWORD false) otherwise.
 *
 * See_Also: $(D_PSYMBOL isScalarType).
 */
enum bool isBasicType(T) = isScalarType!T || is(T : void);

///
pure nothrow @safe @nogc unittest
{
    struct S;
    class C;
    enum E : int
    {
        i = 0,
    }

    static assert(isBasicType!void);
    static assert(isBasicType!(shared void));
    static assert(isBasicType!E);
    static assert(!isBasicType!(int*));
    static assert(!isBasicType!(void function()));
    static assert(!isBasicType!C);
}

/**
 * Determines whether $(D_PARAM T) is a pointer type.
 *
 * Params:
 *  T = A type.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM T) is a pointer type,
 *          $(D_KEYWORD false) otherwise.
 */
template isPointer(T)
{
    static if (is(T U : U*))
    {
        enum bool isPointer = true;
    }
    else
    {
        enum bool isPointer = false;
    }
}

///
pure nothrow @safe @nogc unittest
{
    static assert(isPointer!(bool*));
    static assert(isPointer!(const bool*));
    static assert(isPointer!(const shared bool*));
    static assert(!isPointer!bool);
}

/**
 * Determines whether $(D_PARAM T) is an array type (dynamic or static, but
 * not an associative one).
 *
 * Params:
 *  T = A type.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM T) is an array type,
 *          $(D_KEYWORD false) otherwise.
 *
 * See_Also: $(D_PSYMBOL isAssociativeArray).
 */
template isArray(T)
{
    static if (is(T U : U[]))
    {
        enum bool isArray = true;
    }
    else
    {
        enum bool isArray = false;
    }
}

///
pure nothrow @safe @nogc unittest
{
    static assert(isArray!(bool[]));
    static assert(isArray!(const bool[]));
    static assert(isArray!(shared bool[]));
    static assert(isArray!(bool[8]));
    static assert(!isArray!bool);
    static assert(!isArray!(bool[string]));
}

/**
 * Determines whether $(D_PARAM T) is a static array type.
 *
 * Params:
 *  T = A type.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM T) is a static array type,
 *          $(D_KEYWORD false) otherwise.
 *
 * See_Also: $(D_PSYMBOL isArray).
 */
template isStaticArray(T)
{
    static if (is(T U : U[L], size_t L))
    {
        enum bool isStaticArray = true;
    }
    else
    {
        enum bool isStaticArray = false;
    }
}

///
pure nothrow @safe @nogc unittest
{
    static assert(isStaticArray!(bool[8]));
    static assert(isStaticArray!(const bool[8]));
    static assert(isStaticArray!(shared bool[8]));
    static assert(!isStaticArray!(bool[]));
    static assert(!isStaticArray!bool);
    static assert(!isStaticArray!(bool[string]));
}

/**
 * Determines whether $(D_PARAM T) is a dynamic array type.
 *
 * Params:
 *  T = A type.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM T) is a dynamic array type,
 *          $(D_KEYWORD false) otherwise.
 *
 * See_Also: $(D_PSYMBOL isArray).
 */
enum bool isDynamicArray(T) = isArray!T && !isStaticArray!T;

///
pure nothrow @safe @nogc unittest
{
    static assert(isDynamicArray!(bool[]));
    static assert(isDynamicArray!(const bool[]));
    static assert(isDynamicArray!(shared bool[]));
    static assert(!isDynamicArray!(bool[8]));
    static assert(!isDynamicArray!bool);
    static assert(!isDynamicArray!(bool[string]));
}

/**
 * Determines whether $(D_PARAM T) is an associative array type.
 *
 * Params:
 *  T = A type.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM T) is an associative array type,
 *          $(D_KEYWORD false) otherwise.
 *
 * See_Also: $(D_PSYMBOL isArray).
 */
template isAssociativeArray(T)
{
    static if (is(T U : U[L], L))
    {
        enum bool isAssociativeArray = true;
    }
    else
    {
        enum bool isAssociativeArray = false;
    }
}

///
pure nothrow @safe @nogc unittest
{
    static assert(isAssociativeArray!(bool[string]));
    static assert(isAssociativeArray!(const bool[string]));
    static assert(isAssociativeArray!(shared const bool[string]));
    static assert(!isAssociativeArray!(bool[]));
    static assert(!isAssociativeArray!(bool[8]));
    static assert(!isAssociativeArray!bool);
}

/**
 * Determines whether $(D_PARAM T) is a built-in type.
 *
 * Built-in types are all basic types and arrays.
 *
 * Params:
 *  T = A type.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM T) is a built-in type,
 *          $(D_KEYWORD false) otherwise.
 *
 * See_Also: $(D_PSYMBOL isBasicType!T),
 *           $(D_PSYMBOL isArray),
 *           $(D_PSYMBOL isAssociativeArray).
 */
enum bool isBuiltinType(T) = isBasicType!T
                          || isArray!T
                          || isAssociativeArray!T;

///
pure nothrow @safe @nogc unittest
{
    static assert(isBuiltinType!int);
    static assert(isBuiltinType!(int[]));
    static assert(isBuiltinType!(int[int]));
    static assert(!isBuiltinType!(int*));
}

/**
 * Determines whether $(D_PARAM T) is an aggregate type.
 *
 * Aggregate types are:
 *
 * $(UL
 *  $(LI $(D_KEYWORD struct)s)
 *  $(LI $(D_KEYWORD class)es)
 *  $(LI $(D_KEYWORD interface)s)
 *  $(LI $(D_KEYWORD union)s)
 * )
 *
 * Params:
 *  T = A type.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM T) is an aggregate type,
 *          $(D_KEYWORD false) otherwise.
 */
enum bool isAggregateType(T) = is(T == struct)
                            || is(T == class)
                            || is(T == interface)
                            || is(T == union);

///
pure nothrow @safe @nogc unittest
{
    struct S;
    class C;
    interface I;
    union U;
    enum E;

    static assert(isAggregateType!S);
    static assert(isAggregateType!C);
    static assert(isAggregateType!I);
    static assert(isAggregateType!U);
    static assert(!isAggregateType!E);
    static assert(!isAggregateType!void);
}

/**
 * Determines whether $(D_PARAM T) is some type.
 *
 * Params:
 *  T = A symbol.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM T) is a type,
 *          $(D_KEYWORD false) otherwise.
 */
deprecated("Use isTypeTuple instead")
enum bool isType(alias T) = is(T);

/// Ditto.
deprecated("Use isTypeTuple instead")
enum bool isType(T) = true;

///
pure nothrow @safe @nogc unittest
{
    class C;
    enum E : bool;
    union U;
    struct T();

    static assert(isType!C);
    static assert(isType!E);
    static assert(isType!U);
    static assert(isType!void);
    static assert(isType!int);
    static assert(!isType!T);
    static assert(isType!(T!()));
    static assert(!isType!5);
    static assert(!isType!(tanya.meta.trait));
}

/**
 * Determines whether $(D_PARAM T) is a narrow string, i.e. consists of
 * $(D_KEYWORD char) or $(D_KEYWORD wchar).
 *
 * The character type of the string can be qualified with $(D_KEYWORD const),
 * $(D_KEYWORD immutable) or $(D_KEYWORD inout), but an occurrence of
 * $(D_KEYWORD shared) in the character type results in returning
 * $(D_KEYWORD false).
 * The string itself (in contrast to its character type) can have any type
 * qualifiers.
 *
 * Static $(D_KEYWORD char) and $(D_KEYWORD wchar) arrays are not considered
 * strings.
 *
 * Params:
 *  T = A Type.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM T) is a narrow string,
 *          $(D_KEYWORD false) otherwise.
 *
 * See_Also: $(D_PSYMBOL isWideString).
 */
enum bool isNarrowString(T) = (is(T : const char[]) || is (T : const wchar[]))
                           && !isStaticArray!T;

///
pure nothrow @safe @nogc unittest
{
    static assert(isNarrowString!(char[]));
    static assert(isNarrowString!(wchar[]));
    static assert(!isNarrowString!(dchar[]));

    static assert(isNarrowString!string);
    static assert(isNarrowString!wstring);
    static assert(!isNarrowString!dstring);

    static assert(isNarrowString!(const string));
    static assert(isNarrowString!(const wstring));
    static assert(!isNarrowString!(const dstring));

    static assert(isNarrowString!(shared string));
    static assert(isNarrowString!(shared wstring));
    static assert(!isNarrowString!(shared dstring));

    static assert(isNarrowString!(const(char)[]));
    static assert(isNarrowString!(inout(char)[]));
    static assert(!isNarrowString!(shared(const(char))[]));
    static assert(!isNarrowString!(shared(char)[]));
    static assert(!isNarrowString!(char[10]));
}

/**
 * Determines whether $(D_PARAM T) is a string, i.e. consists of
 * $(D_KEYWORD char), $(D_KEYWORD wchar) or $(D_KEYWORD dchar).
 *
 * The character type of the string can be qualified with $(D_KEYWORD const),
 * $(D_KEYWORD immutable) or $(D_KEYWORD inout), but an occurrence of
 * $(D_KEYWORD shared) in the character type results in returning
 * $(D_KEYWORD false).
 * The string itself (in contrast to its character type) can have any type
 * qualifiers.
 *
 * Static character arrays are not considered strings.
 *
 * Params:
 *  T = A Type.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM T) is a string,
 *          $(D_KEYWORD false) otherwise.
 *
 * See_Also: $(D_PSYMBOL isNarrowString), $(D_PSYMBOL isWideString).
 */
enum bool isSomeString(T) = isNarrowString!T || isWideString!T;

///
pure nothrow @safe @nogc unittest
{
    static assert(isSomeString!(dchar[]));
    static assert(isSomeString!(char[]));
    static assert(isSomeString!(wchar[]));

    static assert(isSomeString!dstring);
    static assert(isSomeString!string);
    static assert(isSomeString!wstring);

    static assert(isSomeString!(const dstring));
    static assert(isSomeString!(const string));
    static assert(isSomeString!(const wstring));

    static assert(isSomeString!(shared dstring));
    static assert(isSomeString!(shared string));
    static assert(isSomeString!(shared wstring));

    static assert(isSomeString!(const(char)[]));
    static assert(isSomeString!(inout(char)[]));
    static assert(!isSomeString!(shared(const(char))[]));
    static assert(!isSomeString!(shared(char)[]));
    static assert(!isSomeString!(char[10]));
}

/**
 * Returns the minimum value of type $(D_PARAM T). In contrast to
 * $(D_INLINECODE T.min) this template works with floating point and complex
 * types as well.
 *
 * Params:
 *  T = Integral, boolean, floating point, complex or character type.
 *
 * Returns: The minimum value of $(D_PARAM T).
 *
 * See_Also: $(D_PSYMBOL isIntegral),
 *           $(D_PSYMBOL isBoolean),
 *           $(D_PSYMBOL isSomeChar),
 *           $(D_PSYMBOL isFloatingPoint),
 *           $(D_PSYMBOL isComplex).
 */
template mostNegative(T)
{
    static if (isIntegral!T || isBoolean!T || isSomeChar!T)
    {
        enum T mostNegative = T.min;
    }
    else static if (isFloatingPoint!T || isComplex!T)
    {
        enum T mostNegative = -T.max;
    }
    else
    {
        static assert(false, T.stringof ~ " doesn't have the minimum value");
    }
}

///
pure nothrow @safe @nogc unittest
{
    static assert(mostNegative!char == char.min);
    static assert(mostNegative!wchar == wchar.min);
    static assert(mostNegative!dchar == dchar.min);

    static assert(mostNegative!byte == byte.min);
    static assert(mostNegative!ubyte == ubyte.min);
    static assert(mostNegative!bool == bool.min);

    static assert(mostNegative!float == -float.max);
    static assert(mostNegative!double == -double.max);
    static assert(mostNegative!real == -real.max);

    static assert(mostNegative!ifloat == -ifloat.max);
    static assert(mostNegative!cfloat == -cfloat.max);
}

/**
 * Finds the type with the largest size in the $(D_PARAM Args) list. If several
 * types have the same type, the leftmost is returned.
 *
 * Params:
 *  Args = Type list.
 *
 * Returns: The largest type.
 *
 * See_Also: $(D_PSYMBOL Smallest).
 */
template Largest(Args...)
if (Args.length >= 1)
{
    static assert(is(Args[0]), T.stringof ~ " doesn't have .sizeof property");

    static if (Args.length == 1)
    {
        alias Largest = Args[0];
    }
    else static if (Largest!(Args[1 .. $]).sizeof > Args[0].sizeof)
    {
        alias Largest = Largest!(Args[1 .. $]);
    }
    else
    {
        alias Largest = Args[0];
    }
}

///
pure nothrow @safe @nogc unittest
{
    static assert(is(Largest!(int, short, uint) == int));
    static assert(is(Largest!(short) == short));
    static assert(is(Largest!(ubyte[8], ubyte[5]) == ubyte[8]));
    static assert(!is(Largest!(short, 5)));
}

/**
 * Determines whether the type $(D_PARAM T) is copyable.
 *
 * Only structs can be not copyable if their postblit constructor or the
 * postblit constructor of one of its fields is disabled, i.e. annotated with
 * $(D_KEYWORD @disable).
 *
 * Params:
 *  T = A type.
 *
 * Returns: $(D_PARAM true) if $(D_PARAM T) can be copied,
 *          $(D_PARAM false) otherwise.
 */
enum bool isCopyable(T) = is(typeof({ T s1 = T.init; T s2 = s1; }));

///
pure nothrow @safe @nogc unittest
{
    struct S1
    {
    }
    struct S2
    {
        this(this)
        {
        }
    }
    struct S3
    {
        @disable this(this);
    }
    struct S4
    {
        S3 s;
    }
    class C
    {
    }

    static assert(isCopyable!S1);
    static assert(isCopyable!S2);
    static assert(!isCopyable!S3);
    static assert(!isCopyable!S4);

    static assert(isCopyable!C);
    static assert(isCopyable!bool);
}

/**
 * Determines whether $(D_PARAM T) is an abstract class.
 *
 * Abstract class is a class marked as such or a class that has any abstract
 * methods or doesn't implement all methods of abstract base classes.
 *
 * Params:
 *  T = A type.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM T) is an abstract class,
 *          $(D_KEYWORD false) otherwise.
 *
 * See_Also: $(D_PSYMBOL isAbstractFunction).
 */
enum bool isAbstractClass(T) = __traits(isAbstractClass, T);

///
pure nothrow @safe @nogc unittest
{
    class A
    {
    }
    abstract class B
    {
    }
    class C
    {
        abstract void func();
    }
    class D : C
    {
    }
    class E : C
    {
        override void func()
        {
        }
    }
    static assert(!isAbstractClass!A);
    static assert(isAbstractClass!B);
    static assert(isAbstractClass!C);
    static assert(isAbstractClass!D);
    static assert(!isAbstractClass!E);
}

/**
 * Determines whether $(D_PARAM Args) contains only types.
 *
 * Params:
 *  Args = Alias sequence.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM Args) consists only of types,
 *          $(D_KEYWORD false) otherwise.
 */
enum bool isTypeTuple(Args...) = allSatisfy!(isType, Args);

///
pure nothrow @safe @nogc unittest
{
    static assert(isTypeTuple!(int, uint, Object));
    static assert(isTypeTuple!());
    static assert(!isTypeTuple!(int, 8, Object));
    static assert(!isTypeTuple!(5, 8, 2));
}

/**
 * Tells whether $(D_PARAM Args) contains only expressions.
 *
 * An expression is determined by applying $(D_KEYWORD typeof) to an argument:
 *
 * ---
 * static if (is(typeof(Args[i])))
 * {
 *  // Args[i] is an expression.
 * }
 * else
 * {
 *  // Args[i] is not an expression.
 * }
 * ---
 *
 * Params:
 *  Args = Alias sequence.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM Args) consists only of expressions,
 *          $(D_KEYWORD false) otherwise.
 */
template isExpressions(Args...)
{
    static if (Args.length == 0)
    {
        enum bool isExpressions = true;
    }
    else static if (is(typeof(Args[0]) U))
    {
        enum bool isExpressions = !is(U == void)
                               && isExpressions!(Args[1 .. $]);
    }
    else
    {
        enum bool isExpressions = false;
    }
}

///
pure nothrow @safe @nogc unittest
{
    static assert(isExpressions!(5, 8, 2));
    static assert(isExpressions!());
    static assert(!isExpressions!(int, uint, Object));
    static assert(!isExpressions!(int, 8, Object));

    template T(U)
    {
    }
    static assert(!isExpressions!T);
}

/**
 * Determines whether $(D_PARAM T) is a final class.
 *
 * Params:
 *  T = A type.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM T) is a final class,
 *          $(D_KEYWORD false) otherwise.
 *
 * See_Also: $(D_PSYMBOL isFinalFunction).
 */
enum bool isFinalClass(T) = __traits(isFinalClass, T);

///
pure nothrow @safe @nogc unittest
{
    final class A
    {
    }
    class B
    {
    }

    static assert(isFinalClass!A);
    static assert(!isFinalClass!B);
}

/**
 * Determines whether $(D_PARAM T) is an abstract method.
 *
 * Params:
 *  F = A symbol.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM F) is an abstract method,
 *          $(D_KEYWORD false) otherwise.
 *
 * See_Also: $(D_PSYMBOL isAbstractClass).
 */
enum bool isAbstractFunction(alias F) = __traits(isAbstractFunction, F);

///
pure nothrow @safe @nogc unittest
{
    class A
    {
        void func()
        {
        }
    }
    class B
    {
        abstract void func();
    }
    class C : B
    {
        override void func()
        {
        }
    }
    static assert(!isAbstractFunction!(A.func));
    static assert(isAbstractFunction!(B.func));
    static assert(!isAbstractFunction!(C.func));
}

/**
 * Determines whether $(D_PARAM T) is a final method.
 *
 * Params:
 *  F = A symbol.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM F) is a final method,
 *          $(D_KEYWORD false) otherwise.
 *
 * See_Also: $(D_PSYMBOL isFinalClass).
 */
enum bool isFinalFunction(alias F) = __traits(isFinalFunction, F);

///
pure nothrow @safe @nogc unittest
{
    class A
    {
        void virtualFunc()
        {
        }
        final void finalFunc()
        {
        }
    }

    static assert(isFinalFunction!(A.finalFunc));
    static assert(!isFinalFunction!(A.virtualFunc));
}

/**
 * Function pointer is a pointer to a function. So a simple function is not
 * a function pointer, but getting the address of such function returns a
 * function pointer.
 *
 * A function pointer doesn't save the context pointer, thus cannot have access
 * to its outer scope.
 *
 * Params:
 *  F = A symbol.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM F) is a function pointer,
 *          $(D_KEYWORD false) otherwise.
 *
 * See_Also: $(LINK2 http://dlang.org/spec/function.html#closures,
 *                   Delegates, Function Pointers, and Closures).
 */
template isFunctionPointer(F...)
if (F.length == 1)
{
    static if ((is(typeof(F[0]) T : T*) && is(T == function))
            || (is(F[0] T : T*) && is(T == function)))
    {
        enum bool isFunctionPointer = true;
    }
    else
    {
        enum bool isFunctionPointer = false;
    }
}

///
pure nothrow @safe @nogc unittest
{
    static assert(isFunctionPointer!(void function()));
    static assert(!isFunctionPointer!(void delegate()));

    static assert(isFunctionPointer!(() {}));

    void func()
    {
    }
    static void staticFunc()
    {
    }
    interface I
    {
        @property int prop();
    }

    static assert(!isFunctionPointer!func);
    static assert(!isFunctionPointer!staticFunc);

    auto functionPointer = &staticFunc;
    auto dg = &func;

    static assert(isFunctionPointer!functionPointer);
    static assert(!isFunctionPointer!dg);

    static assert(!isFunctionPointer!(I.prop));
}

/**
 * Delegate stores the function pointer and function context.
 *
 * Params:
 *  F = A symbol.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM F) is a delegate,
 *          $(D_KEYWORD false) delegate.
 *
 * See_Also: $(LINK2 http://dlang.org/spec/function.html#closures,
 *                   Delegates, Function Pointers, and Closures).
 */
template isDelegate(F...)
if (F.length == 1)
{
    static if (is(F[0] == delegate)
            || is(typeof(F[0]) == delegate))
    {
        enum bool isDelegate = true;
    }
    else
    {
        enum bool isDelegate = false;
    }
}

///
pure nothrow @safe @nogc unittest
{
    static assert(isDelegate!(void delegate()));
    static assert(!isDelegate!(void function()));

    static assert(!isDelegate!(() {}));

    void func()
    {
    }
    static void staticFunc()
    {
    }
    interface I
    {
        @property int prop();
    }

    static assert(!isDelegate!func);
    static assert(!isDelegate!staticFunc);

    auto functionPointer = &staticFunc;
    auto dg = &func;

    static assert(!isDelegate!functionPointer);
    static assert(isDelegate!dg);

    static assert(!isDelegate!(I.prop));
}

/**
 * $(D_PSYMBOL isFunction) returns $(D_KEYWORD true) only for plain functions,
 * not function pointers or delegates. Use $(D_PSYMBOL isFunctionPointer) or
 * $(D_PSYMBOL isDelegate) to detect them or $(D_PSYMBOL isSomeFunction)
 * for detecting a function of any type.
 *
 * Params:
 *  F = A symbol.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM F) is a function,
 *          $(D_KEYWORD false) otherwise.
 *
 * See_Also: $(LINK2 http://dlang.org/spec/function.html#closures,
 *                   Delegates, Function Pointers, and Closures).
 */
template isFunction(F...)
if (F.length == 1)
{
    static if (is(F[0] == function)
            || is(typeof(&F[0]) T == delegate)
            || (is(typeof(&F[0]) T : T*) && is(T == function)))
    {
        enum bool isFunction = true;
    }
    else
    {
        enum bool isFunction = false;
    }
}

///
pure nothrow @safe @nogc unittest
{
    static assert(!isFunction!(void function()));
    static assert(!isFunction!(() {}));
    static assert(!isFunction!(void delegate()));

    void func()
    {
    }
    static void staticFunc()
    {
    }
    interface I
    {
        @property int prop();
    }

    static assert(isFunction!func);
    static assert(isFunction!staticFunc);

    auto functionPointer = &staticFunc;
    auto dg = &func;

    static assert(!isFunction!functionPointer);
    static assert(!isFunction!dg);

    static assert(isFunction!(I.prop));
}

/**
 * Params:
 *  F = A symbol.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM F) is a function, function pointer
 *           or delegate, $(D_KEYWORD false) otherwise.
 *
 * See_Also: $(D_PSYMBOL isFunction),
 *           $(D_PSYMBOL isDelegate),
 *           $(D_PSYMBOL isFunctionPointer).
 */
template isSomeFunction(F...)
if (F.length == 1)
{
    enum bool isSomeFunction = isFunctionPointer!F
                            || isFunction!F
                            || isDelegate!F;
}

///
pure nothrow @safe @nogc unittest
{
    static assert(isSomeFunction!(void function()));
    static assert(isSomeFunction!(() {}));
    static assert(isSomeFunction!(void delegate()));

    void func()
    {
    }
    static void staticFunc()
    {
    }

    static assert(isSomeFunction!func);
    static assert(isSomeFunction!staticFunc);

    auto functionPointer = &staticFunc;
    auto dg = &func;

    static assert(isSomeFunction!functionPointer);
    static assert(isSomeFunction!dg);

    static assert(!isSomeFunction!int);
}

/**
 * Params:
 *  F = A symbol.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM F) is callable,
 *          $(D_KEYWORD false) otherwise.
 */
template isCallable(F...)
if (F.length == 1)
{
    static if (isSomeFunction!F
            || (is(typeof(F[0].opCall)) && isFunction!(F[0].opCall)))
    {
        enum bool isCallable = true;
    }
    else
    {
        enum bool isCallable = false;
    }
}

///
pure nothrow @safe @nogc unittest
{
    struct S
    {
        void opCall()
        {
        }
    }
    class C
    {
        static void opCall()
        {
        }
    }
    interface I
    {
    }
    S s;

    static assert(isCallable!s);
    static assert(isCallable!C);
    static assert(isCallable!S);
    static assert(!isCallable!I);
}

private pure nothrow @safe @nogc unittest
{
    struct S
    {
        @property int opCall()
        {
            return 0;
        }
    }
    S s;
    static assert(isCallable!S);
    static assert(isCallable!s);
}

/**
 * Params:
 *  T      = Aggregate type.
 *  member = Symbol name.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM T) defines a symbol
 *          $(D_PARAM member), $(D_KEYWORD false) otherwise.
 */
enum bool hasMember(T, string member) = __traits(hasMember, T, member);

///
pure nothrow @safe @nogc unittest
{
    struct S
    {
         int member1;
         void member2()
         {
         }
         static int member3;
         static void member4()
         {
         }
    }
    static assert(hasMember!(S, "member1"));
    static assert(hasMember!(S, "member2"));
    static assert(hasMember!(S, "member3"));
    static assert(hasMember!(S, "member4"));
    static assert(!hasMember!(S, "member6"));
}

/**
 * Determines whether $(D_PARAM T) is mutable, i.e. has one of the following
 * qualifiers or a combination of them:
 *
 * $(UL
 *  $(LI $(D_KEYWORD const))
 *  $(LI $(D_KEYWORD immutable))
 *  $(LI $(D_KEYWORD const))
 * )
 *
 * Params:
 *  T = A type.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM T) is mutable,
 *          $(D_KEYWORD false) otherwise.
 */
template isMutable(T)
{
    static if (is(T U == const U)
            || is(T U == inout U)
            || is(T U == inout const U)
            || is(T U == immutable U)
            || is(T U == shared const U)
            || is(T U == shared inout U)
            || is(T U == shared inout const U))
    {
        enum bool isMutable = false;
    }
    else
    {
        enum bool isMutable = true;
    }
}

///
pure nothrow @safe @nogc unittest
{
    struct S
    {
        void method()
        {
            static assert(isMutable!(typeof(this)));
        }

        void method() inout
        {
            static assert(!isMutable!(typeof(this)));
        }

        void immMethod() const
        {
            static assert(!isMutable!(typeof(this)));
        }
        void immMethod() immutable
        {
            static assert(!isMutable!(typeof(this)));
        }
    }
}

/**
 * Params:
 *  T = $(D_KEYWORD class), $(D_KEYWORD struct) or $(D_KEYWORD union) type.
 *
 * Returns: $(D_KEYWORD true) if the argument is a nested type which internally
 *          stores a context pointer, $(D_KEYWORD false) otherwise.
 */
template isNested(T)
if (is(T == class) || is(T == struct) || is(T == union))
{
    enum bool isNested = __traits(isNested, T);
}

///
pure nothrow @safe unittest
{
    static struct S
    {
    }
    static assert(!isNested!S);

    class C
    {
        void method()
        {
        }
    }
    static assert(isNested!C);
}

/**
 * Params:
 *  F = A function.
 *
 * Returns $(D_KEYWORD true) if the $(D_PARAM T) is a nested function,
 *         $(D_KEYWORD false) otherwise.
 */
enum bool isNestedFunction(alias F) = __traits(isNested, F);

///
pure nothrow @safe @nogc unittest
{
    void func()
    {
        void nestedFunc()
        {
        }
        static assert(isNestedFunction!nestedFunc);
    }
}

deprecated("Use tanya.meta.transform.FunctionTypeOf instead")
alias FunctionTypeOf = tanya.meta.transform.FunctionTypeOf;

deprecated("Use tanya.meta.transform.ReturnType instead")
alias ReturnType = tanya.meta.transform.ReturnType;

/**
 * Returns the mangled name of the symbol $(D_PARAM T).
 *
 * Params:
 *  T = A symbol.
 *
 * Returns: Mangled name of $(D_PARAM T).
 */
enum string mangledName(T) = T.mangleof;

///
enum string mangledName(alias T) = T.mangleof;

/**
 * Tests whether $(D_PARAM I) is an instance of template $(D_PARAM T).
 *
 * Params:
 *  T = Template.
 *  I = Template instance.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM I) is an instance of $(D_PARAM T),
 *          $(D_KEYWORD false) otherwise.
 */
enum bool isInstanceOf(alias T, I) = is(I == T!Args, Args...);

template isInstanceOf(alias T, alias I)
{
    static if (is(typeof(TemplateOf!I)))
    {
        enum bool isInstanceOf = isSame!(TemplateOf!I, T);
    }
    else
    {
        enum bool isInstanceOf = false;
    }
}

///
pure nothrow @safe @nogc unittest
{
    struct S(T)
    {
    }
    static assert(isInstanceOf!(S, S!int));

    static void func(T)();
    static assert(isInstanceOf!(func, func!int));

    template T(U)
    {
    }
    static assert(isInstanceOf!(T, T!int));
}

/**
 * Checks whether $(D_PARAM From) is implicitly (without explicit
 * $(D_KEYWORD cast)) to $(D_PARAM To).
 *
 * Params:
 *  From = Source type.
 *  To   = Conversion target type.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM From) is implicitly convertible to
 *          $(D_PARAM To), $(D_KEYWORD false) if not.
 */
enum bool isImplicitlyConvertible(From, To) = is(From : To);

///
pure nothrow @safe @nogc unittest
{
    static assert(isImplicitlyConvertible!(const(byte), byte));
    static assert(isImplicitlyConvertible!(byte, char));
    static assert(isImplicitlyConvertible!(byte, short));
    static assert(!isImplicitlyConvertible!(short, byte));
    static assert(isImplicitlyConvertible!(string, const(char)[]));
}

/**
 * Returns a tuple of base classes and interfaces of $(D_PARAM T).
 *
 * $(D_PSYMBOL BaseTypeTuple) returns only classes and interfaces $(D_PARAM T)
 * directly inherits from, but not the base classes and interfaces of its parents.
 *
 * Params:
 *  T = Class or interface type.
 *
 * Returns: A tuple of base classes or interfaces of ($D_PARAM T).
 *
 * See_Also: $(D_PSYMBOL TransitiveBaseTypeTuple).
 */
template BaseTypeTuple(T)
if (is(T == class) || (is(T == interface)))
{
    static if (is(T Tuple == super))
    {
        alias BaseTypeTuple = Tuple;
    }
    else
    {
        static assert(false, "Argument isn't a class or interface");
    }
}

///
pure nothrow @safe @nogc unittest
{
    interface I1
    {
    }
    interface I2
    {
    }
    interface I3 : I1, I2
    {
    }
    interface I4
    {
    }
    class A : I3, I4
    {
    }
    static assert(is(BaseTypeTuple!A == AliasSeq!(Object, I3, I4)));
    static assert(BaseTypeTuple!Object.length == 0);
}

/**
 * Returns a tuple of all base classes and interfaces of $(D_PARAM T).
 *
 * $(D_PSYMBOL TransitiveBaseTypeTuple) returns first the parent class, then
 * grandparent and so on. The last class is $(D_PSYMBOL Object). Then the interfaces
 * follow.
 *
 * Params:
 *  T = Class or interface type.
 *
 * Returns: A tuple of all base classes and interfaces of ($D_PARAM T).
 *
 * See_Also: $(D_PSYMBOL BaseTypeTuple).
 */
template TransitiveBaseTypeTuple(T)
if (is(T == class) || is(T == interface))
{
    private template Impl(T...)
    {
        static if (T.length == 0)
        {
            alias Impl = AliasSeq!();
        }
        else
        {
            alias Impl = AliasSeq!(BaseTypeTuple!(T[0]),
                                   Map!(ImplCopy, BaseTypeTuple!(T[0])));
        }
    }
    private alias ImplCopy = Impl; // To avoid recursive template expansion.
    private enum bool cmp(A, B) = is(B == interface) && is(A == class);

    alias TransitiveBaseTypeTuple = NoDuplicates!(Sort!(cmp, Impl!T));
}

///
pure nothrow @safe @nogc unittest
{
    interface I1
    {
    }
    interface I2 : I1
    {
    }
    class A : I2
    {
    }
    class B : A, I1
    {
    }
    class C : B, I2
    {
    }
    alias Expected = AliasSeq!(B, A, Object, I2, I1);
    static assert(is(TransitiveBaseTypeTuple!C == Expected));

    static assert(is(TransitiveBaseTypeTuple!Object == AliasSeq!()));
    static assert(is(TransitiveBaseTypeTuple!I2 == AliasSeq!(I1)));
}

/**
 * Returns all the base classes of $(D_PARAM T), the direct parent class comes
 * first, $(D_PSYMBOL Object) ist the last one.
 *
 * The only type that doesn't have any base class is $(D_PSYMBOL Object).
 *
 * Params:
 *  T = Class type.
 *
 * Returns: Base classes of $(D_PARAM T).
 */
template BaseClassesTuple(T)
if (is(T == class))
{
    static if (is(T == Object))
    {
        alias BaseClassesTuple = AliasSeq!();
    }
    else
    {
        private alias Parents = BaseTypeTuple!T;
        alias BaseClassesTuple = AliasSeq!(Parents[0], BaseClassesTuple!(Parents[0]));
    }
}

///
pure nothrow @safe @nogc unittest
{
    interface I1
    {
    }
    interface I2
    {
    }
    class A : I1, I2
    {
    }
    class B : A, I1
    {
    }
    class C : B, I2
    {
    }
    static assert(is(BaseClassesTuple!C == AliasSeq!(B, A, Object)));
    static assert(BaseClassesTuple!Object.length == 0);
}

/**
 * Returns all the interfaces $(D_PARAM T) inherits from.
 *
 * Params:
 *  T = Class or interface type.
 *
 * Returns: Interfaces $(D_PARAM T) inherits from.
 */
template InterfacesTuple(T)
if (is(T == class) || is(T == interface))
{
    alias InterfacesTuple = Filter!(isInterface, TransitiveBaseTypeTuple!T);
}

///
pure nothrow @safe @nogc unittest
{
    interface I1
    {
    }
    interface I2 : I1
    {
    }
    class A : I2
    {
    }
    class B : A, I1
    {
    }
    class C : B, I2
    {
    }
    static assert(is(InterfacesTuple!C == AliasSeq!(I2, I1)));

    static assert(is(InterfacesTuple!Object == AliasSeq!()));
    static assert(is(InterfacesTuple!I1 == AliasSeq!()));
}

/**
 * Tests whether a value of type $(D_PARAM Rhs) can be assigned to a variable
 * of type $(D_PARAM Lhs).
 *
 * If $(D_PARAM Rhs) isn't specified, $(D_PSYMBOL isAssignable) tests whether a
 * value of type $(D_PARAM Lhs) can be assigned to a variable of the same type.
 *
 * $(D_PSYMBOL isAssignable) tells whether $(D_PARAM Rhs) can be assigned by
 * value as well by reference.
 *
 * Params:
 *  Lhs = Variable type.
 *  Rhs = Expression type.
 *
 * Returns: $(D_KEYWORD true) if a value of type $(D_PARAM Rhs) can be assigned
 *          to a variable of type $(D_PARAM Lhs), $(D_KEYWORD false) otherwise.
 */
template isAssignable(Lhs, Rhs = Lhs)
{
    enum bool isAssignable = is(typeof({
        Lhs lhs = Lhs.init;
        Rhs rhs = Rhs.init;
        lhs = ((inout ref Rhs) => Rhs.init)(rhs);
    }));
}

///
pure nothrow @safe @nogc unittest
{
    struct S1
    {
        @disable this();
        @disable this(this);
    }
    struct S2
    {
        void opAssign(S1 s) pure nothrow @safe @nogc
        {
        }
    }
    struct S3
    {
        void opAssign(ref S1 s) pure nothrow @safe @nogc
        {
        }

    }
    static assert(isAssignable!(S2, S1));
    static assert(!isAssignable!(S3, S1));

    static assert(isAssignable!(const(char)[], string));
    static assert(!isAssignable!(string, char[]));

    static assert(isAssignable!int);
    static assert(!isAssignable!(const int, int));
}

/**
 * Returns template parameters of $(D_PARAM T).
 *
 * Params:
 *  T = Template instance.
 *
 * Returns: Template parameters of $(D_PARAM T).
 */
alias TemplateArgsOf(alias T : Base!Args, alias Base, Args...) = Args;

///
pure nothrow @safe @nogc unittest
{
    template T(A, B)
    {
    }
    static assert(is(TemplateArgsOf!(T!(int, uint)) == AliasSeq!(int, uint)));
}

/**
 * Returns a tuple with parameter types of a function.
 *
 * Params:
 *  F = A function.
 *
 * Returns: Tuple with parameter types of a function.
 */
template Parameters(F...)
if (isCallable!F)
{
    static if (is(FunctionTypeOf!F T == function))
    {
        alias Parameters = T;
    }
    else
    {
        static assert(false, "Function has no parameters");
    }
}

///
pure nothrow @safe @nogc unittest
{
    int func(Object, uint[]);
    static assert(is(Parameters!func == AliasSeq!(Object, uint[])));
}

/**
 * Returns a string array with all parameter names of a function.
 *
 * If a parameter has no name, an empty string is placed into array.
 *
 * Params:
 *  F = A function.
 *
 * Returns: Function parameter names.
 */
template ParameterIdentifierTuple(F...)
if (isCallable!F)
{
    static if (is(FunctionTypeOf!F Params == __parameters))
    {
        enum string[] Impl()
        {
            string[] tuple;

            foreach (k, P; Params)
            {
                static if (is(typeof(__traits(identifier, Params[k .. $]))))
                {
                    tuple ~= __traits(identifier, Params[k .. $]);
                }
                else
                {
                    tuple ~= "";
                }
            }

            return tuple;
        }
        enum string[] ParameterIdentifierTuple = Impl();
    }
    else
    {
        static assert(false, "Function has no parameters");
    }
}

///
pure nothrow @safe @nogc unittest
{
    int func(ref Object stuff, uint[] = null, scope uint k = 1);
    alias P = ParameterIdentifierTuple!func;
    static assert(P[0] == "stuff");
    static assert(P[1] == "");
    static assert(P[2] == "k");
}

/// Attributes can be attached to a function.
enum FunctionAttribute : uint
{
    none = 0x0000,
    pure_ = 0x0001,
    nothrow_ = 0x0002,
    ref_ = 0x0004,
    property = 0x0008,
    trusted = 0x0010,
    safe = 0x0020,
    nogc = 0x0040,
    system = 0x0080,
    const_ = 0x0100,
    immutable_ = 0x0200,
    inout_ = 0x0400,
    shared_ = 0x0800,
    return_ = 0x1000,
    scope_ = 0x2000,
}

/**
 * Retrieves the attributes of the function $(D_PARAM F).
 *
 * The attributes are returned as a bit-mask of
 * $(D_PSYMBOL FunctionAttribute) values.
 *
 * Params: A function.
 *
 * Returns: Attributes of the function $(D_PARAM F).
 *
 * See_Also: $(D_PSYMBOL FunctionAttribute).
 */
template functionAttributes(F...)
if (isCallable!F)
{
    enum uint Impl()
    {
        uint attrs = FunctionAttribute.none;
        foreach (a; __traits(getFunctionAttributes, F[0]))
        {
            static if (a == "const")
            {
                attrs |= FunctionAttribute.const_;
            }
            else static if (a == "immutable")
            {
                attrs |= FunctionAttribute.immutable_;
            }
            else static if (a == "inout")
            {
                attrs |= FunctionAttribute.inout_;
            }
            else static if (a == "@nogc")
            {
                attrs |= FunctionAttribute.nogc;
            }
            else static if (a == "nothrow")
            {
                attrs |= FunctionAttribute.nothrow_;
            }
            else static if (a == "@property")
            {
                attrs |= FunctionAttribute.property;
            }
            else static if (a == "pure")
            {
                attrs |= FunctionAttribute.pure_;
            }
            else static if (a == "ref")
            {
                attrs |= FunctionAttribute.ref_;
            }
            else static if (a == "return")
            {
                attrs |= FunctionAttribute.return_;
            }
            else static if (a == "@safe")
            {
                attrs |= FunctionAttribute.safe;
            }
            else static if (a == "scope")
            {
                attrs |= FunctionAttribute.scope_;
            }
            else static if (a == "shared")
            {
                attrs |= FunctionAttribute.shared_;
            }
            else static if (a == "system")
            {
                attrs |= FunctionAttribute.system;
            }
            else static if (a == "@trusted")
            {
                attrs |= FunctionAttribute.trusted;
            }
        }
        return attrs;
    }
    enum uint functionAttributes = Impl();
}

///
pure nothrow @safe @nogc unittest
{
    @property ref int func1() pure nothrow @safe @nogc shared scope;
    static assert((functionAttributes!func1 & FunctionAttribute.pure_)
               == FunctionAttribute.pure_);
    static assert((functionAttributes!func1 & FunctionAttribute.nothrow_)
               == FunctionAttribute.nothrow_);
    static assert((functionAttributes!func1 & FunctionAttribute.safe)
               == FunctionAttribute.safe);
    static assert((functionAttributes!func1 & FunctionAttribute.nogc)
               == FunctionAttribute.nogc);
    static assert((functionAttributes!func1 & FunctionAttribute.shared_)
               == FunctionAttribute.shared_);
    static assert((functionAttributes!func1 & FunctionAttribute.ref_)
               == FunctionAttribute.ref_);
    static assert((functionAttributes!func1 & FunctionAttribute.property)
               == FunctionAttribute.property);
    static assert((functionAttributes!func1 & FunctionAttribute.scope_)
               == FunctionAttribute.scope_);
    static assert((functionAttributes!func1 & FunctionAttribute.system) == 0);
    static assert((functionAttributes!func1 & FunctionAttribute.trusted) == 0);
    static assert((functionAttributes!func1 & FunctionAttribute.return_) == 0);
}

/**
 * Returns a tuple with default values of the parameters to $(D_PARAM F).
 *
 * If a parameter doesn't have a default value, $(D_KEYWORD void) is returned.
 *
 * Params:
 *  F = A function.
 *
 * Returns: Default values of the parameters to $(D_PARAM F).
 */
template ParameterDefaults(F...)
if (isCallable!F)
{
    static if (is(FunctionTypeOf!F T == __parameters))
    {
        private template GetDefault(size_t i)
        {
            static if (i == T.length)
            {
                alias GetDefault = AliasSeq!();
            }
            else
            {
                enum getDefault(T[i .. i + 1] name)
                {
                    return name[0];
                }
                static if (is(typeof(getDefault())))
                {
                    alias Default = Alias!(getDefault());
                }
                else
                {
                    alias Default = void;
                }
                alias GetDefault = AliasSeq!(Default, GetDefault!(i + 1));
            }
        }

        alias ParameterDefaults = GetDefault!0;
    }
}

///
pure nothrow @safe @nogc unittest
{
    void func1(int k, uint b = 5, int[] = [1, 2]);
    alias Defaults = ParameterDefaults!func1;
    static assert(is(Defaults[0] == void));
    static assert(Defaults[1 .. 3] == AliasSeq!(5, [1, 2]));
}

/**
 * Determines whether $(D_PARAM T) has an elaborate destructor.
 *
 * Only $(D_KEYWORD struct)s and static arrays of $(D_KEYWORD struct)s with the
 * length greater than`0` can have elaborate destructors, for all other types
 * $(D_PSYMBOL hasElaborateDestructor) evaluates to $(D_KEYWORD false).
 *
 * An elaborate destructor is an explicitly defined destructor or one generated
 * by the compiler. The compiler generates a destructor for a
 * $(D_KEYWORD struct) if it has members with an elaborate destructor.
 *
 * Params:
 *  T = A type.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM T) has an elaborate destructor,
 *          $(D_KEYWORD false) otherwise.
 */
template hasElaborateDestructor(T)
{
    static if (is(T E : E[L], size_t L))
    {
        enum bool hasElaborateDestructor = L > 0 && hasElaborateDestructor!E;
    }
    else
    {
        enum bool hasElaborateDestructor = is(T == struct)
                                        && hasMember!(T, "__xdtor");
    }
}

///
pure nothrow @safe @nogc unittest
{
    class C
    {
        ~this()
        {
        }
    }
    static assert(!hasElaborateDestructor!C);

    static struct S
    {
        ~this()
        {
        }
    }
    static struct S1
    {
        S s;
    }
    static struct S2
    {
    }
    static assert(hasElaborateDestructor!S); // Explicit destructor.
    static assert(hasElaborateDestructor!S1); // Compiler-generated destructor.
    static assert(!hasElaborateDestructor!S2); // No destructor.

    static assert(hasElaborateDestructor!(S[1]));
    static assert(!hasElaborateDestructor!(S[0]));
}

/**
 * Determines whether $(D_PARAM T) has an elaborate postblit constructor.
 *
 * Only $(D_KEYWORD struct)s and static arrays of $(D_KEYWORD struct)s with the
 * length greater than`0` can have elaborate postblit constructors, for all
 * other types $(D_PSYMBOL hasElaborateCopyConstructor) evaluates to
 * $(D_KEYWORD false).
 *
 * An elaborate postblit constructor is an explicitly defined postblit
 * constructor or one generated by the compiler. The compiler generates a
 * postblit constructor for a
 * $(D_KEYWORD struct) if it has members with an elaborate postblit
 * constructor.
 *
 * Params:
 *  T = A type.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM T) has an elaborate postblit
 *          constructor, $(D_KEYWORD false) otherwise.
 */
template hasElaborateCopyConstructor(T)
{
    static if (is(T E : E[L], size_t L))
    {
        enum bool hasElaborateCopyConstructor = L > 0
                                             && hasElaborateCopyConstructor!E;
    }
    else
    {
        enum bool hasElaborateCopyConstructor = is(T == struct)
                                             && hasMember!(T, "__xpostblit");
    }
}

///
pure nothrow @safe @nogc unittest
{
    static assert(!hasElaborateCopyConstructor!int);

    static struct S
    {
        this(this)
        {
        }
    }
    static struct S1
    {
        S s;
    }
    static struct S2
    {
    }
    static assert(hasElaborateCopyConstructor!S); // Explicit destructor.
    static assert(hasElaborateCopyConstructor!S1); // Compiler-generated destructor.
    static assert(!hasElaborateCopyConstructor!S2); // No destructor.
    static assert(hasElaborateCopyConstructor!(S[1]));
    static assert(!hasElaborateCopyConstructor!(S[0]));
}

/**
 * Determines whether $(D_PARAM T) has an elaborate assign.
 *
 * Only $(D_KEYWORD struct)s and static arrays of $(D_KEYWORD struct)s with the
 * length greater than`0` can have an elaborate assign, for all
 * other types $(D_PSYMBOL hasElaborateAssign) evaluates to $(D_KEYWORD false).
 *
 * An elaborate assign is defined with $(D_INLINECODE opAssign(typeof(this)))
 * or $(D_INLINECODE opAssign(ref typeof(this))). An elaborate assign can be
 * generated for a $(D_KEYWORD struct) by the compiler if one of the members of
 * this $(D_KEYWORD struct) has an elaborate assign.
 *
 * Params:
 *  T = A type.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM T) has an elaborate assign,
 *          $(D_KEYWORD false) otherwise.
 */
template hasElaborateAssign(T)
{
    static if (is(T E : E[L], size_t L))
    {
        enum bool hasElaborateAssign = L > 0 && hasElaborateAssign!E;
    }
    else static if (is(T == struct))
    {
        private enum bool valueAssign = is(typeof({ T.init.opAssign(T()); }));
        enum bool hasElaborateAssign = valueAssign || is(typeof({
            T s;
            s.opAssign(s);
        }));
    }
    else
    {
        enum bool hasElaborateAssign = false;
    }
}

pure nothrow @safe @nogc unittest
{
    static assert(!hasElaborateAssign!int);

    static struct S1
    {
        void opAssign(S1)
        {
        }
    }
    static struct S2
    {
        void opAssign(int)
        {
        }
    }
    static struct S3
    {
        S1 s;
        alias s this;
    }
    static assert(hasElaborateAssign!S1);
    static assert(!hasElaborateAssign!(const S1));
    static assert(hasElaborateAssign!(S1[1]));
    static assert(!hasElaborateAssign!(S1[0]));
    static assert(!hasElaborateAssign!S2);
    static assert(hasElaborateAssign!S3);

    static struct S4
    {
        void opAssign(S4)
        {
        }
        @disable this(this);
    }
    static assert(hasElaborateAssign!S4);
}

/**
 * Returns all members of $(D_KEYWORD enum) $(D_PARAM T).
 *
 * The members of $(D_PARAM T) are typed as $(D_PARAM T), not as a base type
 * of the enum.
 *
 * $(D_PARAM EnumMembers) returns all members of $(D_PARAM T), also if there
 * are some duplicates.
 *
 * Params:
 *  T = A $(D_KEYWORD enum).
 *
 * Returns: All members of $(D_PARAM T).
 */
template EnumMembers(T)
if (is(T == enum))
{
    private template getEnumMembers(Args...)
    {
        static if (Args.length == 1)
        {
            enum T getEnumMembers = __traits(getMember, T, Args[0]);
        }
        else
        {
            alias getEnumMembers = AliasSeq!(__traits(getMember, T, Args[0]), getEnumMembers!(Args[1 .. $]));
        }
    }
    alias EnumMembers = getEnumMembers!(__traits(allMembers, T));
}

///
pure nothrow @nogc @safe unittest
{
    enum E : int
    {
        one,
        two,
        three,
    }
    static assert([E.one, E.two, E.three] == [ EnumMembers!E ]);
}

/**
 * Different than $(D_INLINECODE T.alignof), which is the same for all class
 * types,  $(D_PSYMBOL classInstanceOf) determines the alignment of the class
 * instance and not of its reference.
 *
 * Params:
 *  T = A class.
 *
 * Returns: Alignment of an instance of the class $(D_PARAM T).
 */
template classInstanceAlignment(T)
if (is(T == class))
{
    private enum ptrdiff_t pred(U1, U2) = U1.alignof - U2.alignof;
    private alias Fields = typeof(T.tupleof);
    enum size_t classInstanceAlignment = Max!(pred, T, Fields).alignof;
}

///
pure nothrow @safe @nogc unittest
{
    class C1
    {
    }
    static assert(classInstanceAlignment!C1 == C1.alignof);

    struct S
    {
        align(8)
        uint s;

        int i;
    }
    class C2
    {
        S s;
    }
    static assert(classInstanceAlignment!C2 == S.alignof);
}

/**
 * Tests whether $(D_INLINECODE pred(T)) can be used as condition in an
 * $(D_KEYWORD if)-statement or a ternary operator.
 *
 * $(D_PARAM pred) is an optional parameter. By default $(D_PSYMBOL ifTestable)
 * tests whether $(D_PARAM T) itself is usable as condition in an
 * $(D_KEYWORD if)-statement or a ternary operator, i.e. if it a value of type
 * $(D_PARAM T) can be converted to a boolean.
 *
 * Params:
 *  T    = A type.
 *  pred = Function with one argument.
 *
 * Returns: $(D_KEYWORD true) if $(D_INLINECODE pred(T)) can be used as
 *          condition in an $(D_KEYWORD if)-statement or a ternary operator.
 */
template ifTestable(T, alias pred = a => a)
{
    enum bool ifTestable = is(typeof(pred(T.init) ? true : false));
}

///
pure nothrow @safe @nogc unittest
{
    static assert(ifTestable!int);

    struct S1
    {
    }
    static assert(!ifTestable!S1);

    struct S2
    {
        bool opCast(T : bool)()
        {
            return true;
        }
    }
    static assert(ifTestable!S2);
}

/**
 * Returns a compile-time tuple of user-defined attributes (UDA) attached to
 * $(D_PARAM symbol).
 *
 * $(D_PARAM symbol) can be:
 *
 * $(DL
 *  $(DT Template)
 *  $(DD The attribute is matched if it is an instance of the template
 *       $(D_PARAM attr).)
 *  $(DT Type)
 *  $(DD The attribute is matched if it its type is $(D_PARAM attr).)
 *  $(DT Expression)
 *  $(DD The attribute is matched if it equals to $(D_PARAM attr).)
 * )
 *
 * If $(D_PARAM attr) isn't given, all user-defined attributes of
 * $(D_PARAM symbol) are returned.
 *
 * Params:
 *  symbol = A symbol.
 *  attr   = User-defined attribute.
 *
 * Returns: A tuple of user-defined attributes attached to $(D_PARAM symbol)
 *          and matching $(D_PARAM attr).
 *
 * See_Also: $(LINK2 https://dlang.org/spec/attribute.html#uda,
 *                   User Defined Attributes).
 */
template getUDAs(alias symbol, alias attr)
{
    private template FindUDA(T...)
    {
        static if (T.length == 0)
        {
            alias FindUDA = AliasSeq!();
        }
        else static if ((isType!attr && is(TypeOf!(T[0]) == attr))
                     || (is(typeof(T[0] == attr)) && (T[0] == attr))
                     || isInstanceOf!(attr, TypeOf!(T[0])))
        {
            alias FindUDA = AliasSeq!(T[0], FindUDA!(T[1 .. $]));
        }
        else
        {
            alias FindUDA = FindUDA!(T[1 .. $]);
        }
    }
    alias getUDAs = FindUDA!(__traits(getAttributes, symbol));
}

///
alias getUDAs(alias symbol) = AliasSeq!(__traits(getAttributes, symbol));

///
pure nothrow @safe @nogc unittest
{
    struct Attr
    {
        int i;
    }
    @Attr int a;
    static assert(getUDAs!(a, Attr).length == 1);

    @Attr(8) int b;
    static assert(getUDAs!(b, Attr).length == 1);
    static assert(getUDAs!(b, Attr)[0].i == 8);
    static assert(getUDAs!(b, Attr(8)).length == 1);
    static assert(getUDAs!(b, Attr(7)).length == 0);

    @("string", 5) int c;
    static assert(getUDAs!(c, "string").length == 1);
    static assert(getUDAs!(c, 5).length == 1);
    static assert(getUDAs!(c, "String").length == 0);
    static assert(getUDAs!(c, 4).length == 0);

    struct T(U)
    {
        enum U s = 7;
        U i;
    }
    @T!int @T!int(8) int d;
    static assert(getUDAs!(d, T).length == 2);
    static assert(getUDAs!(d, T)[0].s == 7);
    static assert(getUDAs!(d, T)[1].i == 8);

    @T int e;
    static assert(getUDAs!(e, T).length == 0);
}

/**
 * Determines whether $(D_PARAM symbol) has user-defined attribute
 * $(D_PARAM attr) attached to it.
 *
 * Params:
 *  symbol = A symbol.
 *  attr   = User-defined attribute.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM symbol) has user-defined attribute
 *          $(D_PARAM attr), $(D_KEYWORD false) otherwise.
 *
 * See_Also: $(LINK2 https://dlang.org/spec/attribute.html#uda,
 *                   User Defined Attributes).
 */
template hasUDA(alias symbol, alias attr)
{
    enum bool hasUDA = getUDAs!(symbol, attr).length != 0;
}

///
pure nothrow @safe @nogc unittest
{
    struct Attr1
    {
    }
    struct Attr2
    {
    }
    @Attr1 int a;
    static assert(hasUDA!(a, Attr1));
    static assert(!hasUDA!(a, Attr2));
}
