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

/**
 * Params:
 *  F = A function.
 *
 * Returns: Type of the function $(D_PARAM F).
 */
template FunctionTypeOf(F...)
if (isCallable!F)
{
    static if ((is(typeof(F[0]) T : T*) && is(T == function))
            || (is(F[0] T : T*) && is(T == function))
            || is(F[0] T == delegate)
            || is(typeof(F[0]) T == delegate)
            || is(F[0] T == function)
            || is(typeof(&F[0]) T == delegate)
            || (is(typeof(&F[0]) T : T*) && is(T == function)))
    {
        alias FunctionTypeOf = T;
    }
    else
    {
        alias FunctionTypeOf = FunctionTypeOf!(F[0].opCall);
    }
}

///
pure nothrow @safe @nogc unittest
{
    static assert(is(FunctionTypeOf!(void function()) == function));
    static assert(is(FunctionTypeOf!(() {}) == function));
}

private pure nothrow @safe @nogc unittest
{
    static assert(is(FunctionTypeOf!(void delegate()) == function));

    static void staticFunc()
    {
    }
    auto functionPointer = &staticFunc;
    static assert(is(FunctionTypeOf!staticFunc == function));
    static assert(is(FunctionTypeOf!functionPointer == function));

    void func()
    {
    }
    auto dg = &func;
    static assert(is(FunctionTypeOf!func == function));
    static assert(is(FunctionTypeOf!dg == function));

    interface I
    {
        @property int prop();
    }
    static assert(is(FunctionTypeOf!(I.prop) == function));

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
    S s;

    static assert(is(FunctionTypeOf!s == function));
    static assert(is(FunctionTypeOf!C == function));
    static assert(is(FunctionTypeOf!S == function));
}

private pure nothrow @safe @nogc unittest
{
    struct S2
    {
        @property int opCall()
        {
            return 0;
        }
    }
    S2 s2;
    static assert(is(FunctionTypeOf!S2 == function));
    static assert(is(FunctionTypeOf!s2 == function));
}

/**
 * Params:
 *  F = A callable object.
 *
 * Returns: Return type of $(D_PARAM F).
 */
template ReturnType(F...)
if (isCallable!F)
{
    static if (is(FunctionTypeOf!(F[0]) T == return))
    {
        alias ReturnType = T;
    }
    else
    {
        static assert(false, "Argument is not a callable");
    }
}
