/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Type transformations.
 *
 * Templates in this module can be used to modify type qualifiers or transform
 * types.
 *
 * Copyright: Eugene Wissner 2017.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/meta/transform.d,
 *                 tanya/meta/transform.d)
 */
module tanya.meta.transform;

import tanya.meta.traits;

/**
 * Removes any type qualifiers from $(D_PARAM T).
 *
 * Removed qualifiers are:
 * $(UL
 *  $(LI const)
 *  $(LI immutable)
 *  $(LI inout)
 *  $(LI shared)
 * )
 * and combinations of these.
 *
 * If the type $(D_PARAM T) doesn't have any qualifieres,
 * $(D_INLINECODE Unqual!T) becomes an alias for $(D_PARAM T).
 *
 * Params:
 *  T = A type.
 *
 * Returns: $(D_PARAM T) without any type qualifiers.
 */
template Unqual(T)
{
    static if (is(T U == const U)
            || is(T U == immutable U)
            || is(T U == inout U)
            || is(T U == inout const U)
            || is(T U == shared U)
            || is(T U == shared const U)
            || is(T U == shared inout U)
            || is(T U == shared inout const U))
    {
        alias Unqual = U;
    }
    else
    {
        alias Unqual = T;
    }
}

///
pure nothrow @safe @nogc unittest
{
    static assert(is(Unqual!bool == bool));
    static assert(is(Unqual!(immutable bool) == bool));
    static assert(is(Unqual!(inout bool) == bool));
    static assert(is(Unqual!(inout const bool) == bool));
    static assert(is(Unqual!(shared bool) == bool));
    static assert(is(Unqual!(shared const bool) == bool));
    static assert(is(Unqual!(shared inout const bool) == bool));
}

/**
 * If $(D_PARAM T) is an $(D_KEYWORD enum), $(D_INLINECODE OriginalType!T)
 * evaluates to the most base type of that $(D_KEYWORD enum) and to
 * $(D_PARAM T) otherwise.
 *
 * Params:
 *  T = A type.
 *
 * Returns: Base type of the $(D_KEYWORD enum) $(D_PARAM T) or $(D_PARAM T)
 *          itself.
 */
template OriginalType(T)
{
    static if (is(T U == enum))
    {
        alias OriginalType = OriginalType!U;
    }
    else
    {
        alias OriginalType = T;
    }
}

///
pure nothrow @safe @nogc unittest
{
    enum E1 : const(int)
    {
        n = 0,
    }
    enum E2 : bool
    {
        t = true,
    }
    enum E3 : E2
    {
        t = E2.t,
    }
    enum E4 : const(E2)
    {
        t = E2.t,
    }

    static assert(is(OriginalType!E1 == const int));
    static assert(is(OriginalType!E2 == bool));
    static assert(is(OriginalType!E3 == bool));
    static assert(is(OriginalType!E4 == bool));
    static assert(is(OriginalType!(const E4) == bool));
}

/**
 * Copies constness of $(D_PARAM From) to $(D_PARAM To).
 *
 * The following type qualifiers affect the constness and hence are copied:
 * $(UL
 *  $(LI const)
 *  $(LI immutable)
 *  $(LI inout)
 *  $(LI inout const)
 * )
 *
 * Params:
 *  From = Source type.
 *  To   = Target type.
 *
 * Returns: $(D_PARAM To) with the constness of $(D_PARAM From).
 *
 * See_Also: $(D_PSYMBOL CopyTypeQualifiers).
 */
template CopyConstness(From, To)
{
    static if (is(From T == immutable T))
    {
        alias CopyConstness = immutable To;
    }
    else static if (is(From T == const T) || is(From T == shared const T))
    {
        alias CopyConstness = const To;
    }
    else static if (is(From T == inout T) || is(From T == shared inout T))
    {
        alias CopyConstness = inout To;
    }
    else static if (is(From T == inout const T)
                 || is(From T == shared inout const T))
    {
        alias CopyConstness = inout const To;
    }
    else
    {
        alias CopyConstness = To;
    }
}

///
pure nothrow @safe @nogc unittest
{
    static assert(is(CopyConstness!(int, char) == char));
    static assert(is(CopyConstness!(const int, char) == const char));
    static assert(is(CopyConstness!(immutable int, char) == immutable char));
    static assert(is(CopyConstness!(inout int, char) == inout char));
    static assert(is(CopyConstness!(inout const int, char) == inout const char));

    static assert(is(CopyConstness!(shared int, char) == char));
    static assert(is(CopyConstness!(shared const int, char) == const char));
    static assert(is(CopyConstness!(shared inout int, char) == inout char));
    static assert(is(CopyConstness!(shared inout const int, char) == inout const char));

    static assert(is(CopyConstness!(const int, shared char) == shared const char));
    static assert(is(CopyConstness!(const int, immutable char) == immutable char));
    static assert(is(CopyConstness!(immutable int, const char) == immutable char));
}

/**
 * Copies type qualifiers of $(D_PARAM From) to $(D_PARAM To).
 *
 * Type qualifiers copied are:
 * $(UL
 *  $(LI const)
 *  $(LI immutable)
 *  $(LI inout)
 *  $(LI shared)
 * )
 * and combinations of these.
 *
 * Params:
 *  From = Source type.
 *  To   = Target type.
 *
 * Returns: $(D_PARAM To) with the type qualifiers of $(D_PARAM From).
 *
 * See_Also: $(D_PSYMBOL CopyConstness).
 */
template CopyTypeQualifiers(From, To)
{
    static if (is(From T == immutable T))
    {
        alias CopyTypeQualifiers = immutable To;
    }
    else static if (is(From T == const T))
    {
        alias CopyTypeQualifiers = const To;
    }
    else static if (is(From T == shared T))
    {
        alias CopyTypeQualifiers = shared To;
    }
    else static if (is(From T == shared const T))
    {
        alias CopyTypeQualifiers = shared const To;
    }
    else static if (is(From T == inout T))
    {
        alias CopyTypeQualifiers = inout To;
    }
    else static if (is(From T == shared inout T))
    {
        alias CopyTypeQualifiers = shared inout To;
    }
    else static if (is(From T == inout const T))
    {
        alias CopyTypeQualifiers = inout const To;
    }
    else static if (is(From T == shared inout const T))
    {
        alias CopyTypeQualifiers = shared inout const To;
    }
    else
    {
        alias CopyTypeQualifiers = To;
    }
}

///
pure nothrow @safe @nogc unittest
{
    static assert(is(CopyTypeQualifiers!(int, char) == char));
    static assert(is(CopyTypeQualifiers!(const int, char) == const char));
    static assert(is(CopyTypeQualifiers!(immutable int, char) == immutable char));
    static assert(is(CopyTypeQualifiers!(inout int, char) == inout char));
    static assert(is(CopyTypeQualifiers!(inout const int, char) == inout const char));

    static assert(is(CopyTypeQualifiers!(shared int, char) == shared char));
    static assert(is(CopyTypeQualifiers!(shared const int, char) == shared const char));
    static assert(is(CopyTypeQualifiers!(shared inout int, char) == shared inout char));
    static assert(is(CopyTypeQualifiers!(shared inout const int, char) == shared inout const char));
}

/**
 * Evaluates to the unsigned counterpart of the integral type $(D_PARAM T) preserving all type qualifiers.
 * If $(D_PARAM T) is already unsigned, $(D_INLINECODE Unsigned!T) aliases $(D_PARAM T).
 *
 * Params:
 *  T = A type.
 *
 * Returns: Unsigned counterpart of $(D_PARAM T).
 *
 * See_Also: $(D_PSYMBOL isSigned).
 */
template Unsigned(T)
if (isIntegral!T)
{
    alias UnqualedType = Unqual!(OriginalType!T);
    static if (is(UnqualedType == byte))
    {
        alias Unsigned = CopyTypeQualifiers!(T, ubyte);
    }
    else static if (is(UnqualedType == short))
    {
        alias Unsigned = CopyTypeQualifiers!(T, ushort);
    }
    else static if (is(UnqualedType == int))
    {
        alias Unsigned = CopyTypeQualifiers!(T, uint);
    }
    else static if (is(UnqualedType == long))
    {
        alias Unsigned = CopyTypeQualifiers!(T, ulong);
    }
    else
    {
        alias Unsigned = T;
    }
}

///
pure nothrow @safe @nogc unittest
{
    static assert(is(Unsigned!byte == ubyte));
    static assert(is(Unsigned!short == ushort));
    static assert(is(Unsigned!int == uint));
    static assert(is(Unsigned!long == ulong));

    static assert(is(Unsigned!(const byte) == const ubyte));
    static assert(is(Unsigned!(shared byte) == shared ubyte));
    static assert(is(Unsigned!(shared const byte) == shared const ubyte));

    static assert(!is(Unsigned!float));
    static assert(is(Unsigned!ubyte == ubyte));
}

/**
 * Evaluates to the signed counterpart of the integral type $(D_PARAM T) preserving all type qualifiers.
 * If $(D_PARAM T) is already signed, $(D_INLINECODE Signed!T) aliases $(D_PARAM T).
 *
 * Params:
 *  T = A type.
 *
 * Returns: Signed counterpart of $(D_PARAM T).
 *
 * See_Also: $(D_PSYMBOL isUnsigned).
 */
template Signed(T)
if (isIntegral!T)
{
    alias UnqualedType = Unqual!(OriginalType!T);
    static if (is(UnqualedType == ubyte))
    {
        alias Signed = CopyTypeQualifiers!(T, byte);
    }
    else static if (is(UnqualedType == ushort))
    {
        alias Signed = CopyTypeQualifiers!(T, short);
    }
    else static if (is(UnqualedType == uint))
    {
        alias Signed = CopyTypeQualifiers!(T, int);
    }
    else static if (is(UnqualedType == ulong))
    {
        alias Signed = CopyTypeQualifiers!(T, long);
    }
    else
    {
        alias Signed = T;
    }
}

///
pure nothrow @safe @nogc unittest
{
    static assert(is(Signed!ubyte == byte));
    static assert(is(Signed!ushort == short));
    static assert(is(Signed!uint == int));
    static assert(is(Signed!ulong == long));

    static assert(is(Signed!(const ubyte) == const byte));
    static assert(is(Signed!(shared ubyte) == shared byte));
    static assert(is(Signed!(shared const ubyte) == shared const byte));

    static assert(!is(Signed!float));
    static assert(is(Signed!byte == byte));
}

/**
 * Retrieves the target type `U` of a pointer `U*`.
 *
 * Params:
 *  T = Pointer type.
 *
 * Returns: Pointer target type.
 */
template PointerTarget(T)
if (isPointer!T)
{
    static if (is(T U : U*))
    {
        alias PointerTarget = U;
    }
}

///
pure nothrow @safe @nogc unittest
{
    static assert(is(PointerTarget!(bool*) == bool));
    static assert(is(PointerTarget!(const bool*) == const bool));
    static assert(is(PointerTarget!(const shared bool*) == const shared bool));
    static assert(!is(PointerTarget!bool));
}
