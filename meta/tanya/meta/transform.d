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
 * Copyright: Eugene Wissner 2017-2020.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/meta/tanya/meta/transform.d,
 *                 tanya/meta/transform.d)
 */
module tanya.meta.transform;

import tanya.meta.metafunction;
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
    static if (is(T U == shared const U)
            || is(T U == shared inout U)
            || is(T U == shared inout const U)
            || is(T U == inout const U)
            || is(T U == const U)
            || is(T U == immutable U)
            || is(T U == inout U)
            || is(T U == shared U))
    {
        alias Unqual = U;
    }
    else
    {
        alias Unqual = T;
    }
}

///
@nogc nothrow pure @safe unittest
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
@nogc nothrow pure @safe unittest
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
@nogc nothrow pure @safe unittest
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
@nogc nothrow pure @safe unittest
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
@nogc nothrow pure @safe unittest
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
@nogc nothrow pure @safe unittest
{
    static assert(is(ValueType!(int[string]) == int));
    static assert(!is(ValueType!(int[15])));
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
@nogc nothrow pure @safe unittest
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
@nogc nothrow pure @safe unittest
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
@nogc nothrow pure @safe unittest
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
@nogc nothrow pure @safe unittest
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
@nogc nothrow pure @safe unittest
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
@nogc nothrow pure @safe unittest
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
@nogc nothrow pure @safe unittest
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
@nogc nothrow pure @safe unittest
{
    static assert(is(SharedInoutConstOf!int == shared inout const int));
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
if (isExpressions!T || __traits(isTemplate, T))
{
    alias TypeOf = typeof(T);
}

///
@nogc nothrow pure @safe unittest
{
    struct S(T)
    {
    }
    static assert(is(TypeOf!S == void));
    static assert(is(TypeOf!int == int));
    static assert(is(TypeOf!true == bool));
    static assert(!is(TypeOf!(tanya.meta)));
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
@nogc nothrow pure @safe unittest
{
    static assert(is(Smallest!(int, ushort, uint, short) == ushort));
    static assert(is(Smallest!(short) == short));
    static assert(is(Smallest!(ubyte[8], ubyte[5]) == ubyte[5]));
    static assert(!is(Smallest!(short, 5)));
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
@nogc nothrow pure @safe unittest
{
    static assert(is(Largest!(int, short, uint) == int));
    static assert(is(Largest!(short) == short));
    static assert(is(Largest!(ubyte[8], ubyte[5]) == ubyte[8]));
    static assert(!is(Largest!(short, 5)));
}
