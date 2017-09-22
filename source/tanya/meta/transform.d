/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Type transformations.
 *
 * Templates in this module can be used to modify type qualifiers or transform
 * types. They take some type as argument and return a different type after
 * perfoming the specified transformation.
 *
 * Copyright: Eugene Wissner 2017.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/meta/transform.d,
 *                 tanya/meta/transform.d)
 */
module tanya.meta.transform;

version (TanyaPhobos)
{
    public import std.traits : Unqual,
                               OriginalType,
                               CopyConstness,
                               CopyTypeQualifiers,
                               Unsigned,
                               Signed,
                               PointerTarget,
                               KeyType,
                               ValueType,
                               Promoted,
                               InoutOf,
                               ConstOf,
                               SharedOf,
                               SharedInoutOf,
                               SharedConstOf,
                               ImmutableOf,
                               QualifierOf;
}
else:

import tanya.meta.trait;

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
{
    static if (is(T U : U*))
    {
        alias PointerTarget = U;
    }
    else
    {
        static assert(T.stringof ~ " isn't a pointer type");
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

/**
 * Params:
 *  T = The type of the associative array.
 *
 * Returns: The key type of the associative array $(D_PARAM T).
 */
template KeyType(T)
{
    static if (is(T V : V[K], K))
    {
        alias KeyType = K;
    }
    else
    {
        static assert(false, T.stringof ~ " isn't an associative array");
    }
}

///
pure nothrow @safe @nogc unittest
{
    static assert(is(KeyType!(int[string]) == string));
    static assert(!is(KeyType!(int[15])));
}

/**
 * Params:
 *  T = The type of the associative array.
 *
 * Returns: The value type of the associative array $(D_PARAM T).
 */
template ValueType(T)
{
    static if (is(T V : V[K], K))
    {
        alias ValueType = V;
    }
    else
    {
        static assert(false, T.stringof ~ " isn't an associative array");
    }
}

///
pure nothrow @safe @nogc unittest
{
    static assert(is(ValueType!(int[string]) == int));
    static assert(!is(ValueType!(int[15])));
}

/**
 * Params:
 *  T = Scalar type.
 *
 * Returns: The type $(D_PARAM T) will promote to.
 *
 * See_Also: $(LINK2 https://dlang.org/spec/type.html#integer-promotions,
 *                   Integer Promotions).
 */
template Promoted(T)
if (isScalarType!T)
{
    alias Promoted = CopyTypeQualifiers!(T, typeof(T.init + T.init));
}

///
pure nothrow @safe @nogc unittest
{
    static assert(is(Promoted!bool == int));
    static assert(is(Promoted!byte == int));
    static assert(is(Promoted!ubyte == int));
    static assert(is(Promoted!short == int));
    static assert(is(Promoted!ushort == int));
    static assert(is(Promoted!char == int));
    static assert(is(Promoted!wchar == int));
    static assert(is(Promoted!dchar == uint));

    static assert(is(Promoted!(const bool) == const int));
    static assert(is(Promoted!(shared bool) == shared int));
}

/**
 * Adds $(D_KEYWORD inout) qualifier to the type $(D_PARAM T).
 *
 * Params:
 *  T = A type.
 *
 * Returns: $(D_INLINECODE inout(T)).
 */
alias InoutOf(T) = inout(T);

///
pure nothrow @safe @nogc unittest
{
    static assert(is(InoutOf!int == inout int));
}

/**
 * Adds $(D_KEYWORD inout) qualifier to the type $(D_PARAM T).
 *
 * Params:
 *  T = A type.
 *
 * Returns: $(D_INLINECODE inout(T)).
 */
alias ConstOf(T) = const(T);

///
pure nothrow @safe @nogc unittest
{
    static assert(is(ConstOf!int == const int));
}

/**
 * Adds $(D_KEYWORD inout) qualifier to the type $(D_PARAM T).
 *
 * Params:
 *  T = A type.
 *
 * Returns: $(D_INLINECODE inout(T)).
 */
alias SharedOf(T) = shared(T);

///
pure nothrow @safe @nogc unittest
{
    static assert(is(SharedOf!int == shared int));
}

/**
 * Adds $(D_KEYWORD inout) qualifier to the type $(D_PARAM T).
 *
 * Params:
 *  T = A type.
 *
 * Returns: $(D_INLINECODE inout(T)).
 */
alias SharedInoutOf(T) = shared(inout T);

///
pure nothrow @safe @nogc unittest
{
    static assert(is(SharedInoutOf!int == shared inout int));
}

/**
 * Adds $(D_KEYWORD shared const) qualifier to the type $(D_PARAM T).
 *
 * Params:
 *  T = A type.
 *
 * Returns: $(D_INLINECODE shared(const T)).
 */
alias SharedConstOf(T) = shared(const T);

///
pure nothrow @safe @nogc unittest
{
    static assert(is(SharedConstOf!int == shared const int));
}

/**
 * Adds $(D_KEYWORD immutable) qualifier to the type $(D_PARAM T).
 *
 * Params:
 *  T = A type.
 *
 * Returns: $(D_INLINECODE immutable(T)).
 */
alias ImmutableOf(T) = immutable(T);

///
pure nothrow @safe @nogc unittest
{
    static assert(is(ImmutableOf!int == immutable int));
}

/**
 * Adds $(D_KEYWORD inout const) qualifier to the type $(D_PARAM T).
 *
 * Params:
 *  T = A type.
 *
 * Returns: $(D_INLINECODE inout(const T)).
 */
alias InoutConstOf(T) = inout(const T);

///
pure nothrow @safe @nogc unittest
{
    static assert(is(InoutConstOf!int == inout const int));
}

/**
 * Adds $(D_KEYWORD shared inout const) qualifier to the type $(D_PARAM T).
 *
 * Params:
 *  T = A type.
 *
 * Returns: $(D_INLINECODE shared(inout const T)).
 */
alias SharedInoutConstOf(T) = shared(inout const T);

///
pure nothrow @safe @nogc unittest
{
    static assert(is(SharedInoutConstOf!int == shared inout const int));
}

/**
 * Returns a template with one argument which applies all qualifiers of
 * $(D_PARAM T) on its argument if instantiated.
 *
 * Params:
 *  T = A type.
 *
 * Returns: $(D_INLINECODE shared(inout const T)).
 */
template QualifierOf(T)
{
    static if (is(T U == const U))
    {
        alias QualifierOf = ConstOf;
    }
    else static if (is(T U == immutable U))
    {
        alias QualifierOf = ImmutableOf;
    }
    else static if (is(T U == inout U))
    {
        alias QualifierOf = InoutOf;
    }
    else static if (is(T U == inout const U))
    {
        alias QualifierOf = InoutConstOf;
    }
    else static if (is(T U == shared U))
    {
        alias QualifierOf = SharedOf;
    }
    else static if (is(T U == shared const U))
    {
        alias QualifierOf = SharedConstOf;
    }
    else static if (is(T U == shared inout U))
    {
        alias QualifierOf = SharedInoutOf;
    }
    else static if (is(T U == shared inout const U))
    {
        alias QualifierOf = SharedInoutConstOf;
    }
    else
    {
        alias QualifierOf(T) = T;
    }
}

///
pure nothrow @safe @nogc unittest
{
    alias MutableOf = QualifierOf!int;
    static assert(is(MutableOf!uint == uint));

    alias ConstOf = QualifierOf!(const int);
    static assert(is(ConstOf!uint == const uint));

    alias InoutOf = QualifierOf!(inout int);
    static assert(is(InoutOf!uint == inout uint));

    alias InoutConstOf = QualifierOf!(inout const int);
    static assert(is(InoutConstOf!uint == inout const uint));

    alias ImmutableOf = QualifierOf!(immutable int);
    static assert(is(ImmutableOf!uint == immutable uint));

    alias SharedOf = QualifierOf!(shared int);
    static assert(is(SharedOf!uint == shared uint));

    alias SharedConstOf = QualifierOf!(shared const int);
    static assert(is(SharedConstOf!uint == shared const uint));

    alias SharedInoutOf = QualifierOf!(shared inout int);
    static assert(is(SharedInoutOf!uint == shared inout uint));

    alias SharedInoutConstOf = QualifierOf!(shared inout const int);
    static assert(is(SharedInoutConstOf!uint == shared inout const uint));
}

/**
 * Determines the type of $(D_PARAM T). If $(D_PARAM T) is already a type,
 * $(D_PSYMBOL TypeOf) aliases itself to $(D_PARAM T).
 *
 * $(D_PSYMBOL TypeOf) evaluates to $(D_KEYWORD void) for template arguments.
 *
 * The symbols that don't have a type and aren't types cannot be used as
 * arguments to $(D_PSYMBOL TypeOf).
 *
 * Params:
 *  T = Expression, type or template.
 *
 * Returns: The type of $(D_PARAM T).
 */
alias TypeOf(T) = T;

/// ditto
template TypeOf(alias T)
if (isExpressions!T || isTemplate!T)
{
    alias TypeOf = typeof(T);
}

///
pure nothrow @safe @nogc unittest
{
    struct S(T)
    {
    }
    static assert(is(TypeOf!S == void));
    static assert(is(TypeOf!int == int));
    static assert(is(TypeOf!true == bool));
    static assert(!is(TypeOf!(tanya.meta)));
}
