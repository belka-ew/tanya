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
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/meta/traits.d,
 *                 tanya/meta/traits.d)
 */
module tanya.meta.traits;

import tanya.meta.transform;

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
 * Determines whether $(D_PARAM T) is a numeric (floating point, integral or
 * complex) type.
*
 * Params:
 *  T = A type.
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
 * Determines whether $(D_PARAM T) is a static array.
 *
 * Params:
 *  T = A type.
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
 * Determines whether $(D_PARAM T) is a dynamic array.
 *
 * Params:
 *  T = A type.
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
 * Determines whether $(D_PARAM T) is an associative array.
 *
 * Params:
 *  T = A type.
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
 *  T = Some symbol.
 */
enum bool isType(alias T) = is(T);

/// Ditto.
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
    static assert(!isType!(tanya.meta.traits));
}
