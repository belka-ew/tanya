/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Type transformations.
 *
 * Templates in this module applied to a type produce a transformed type.
 *
 * Copyright: Eugene Wissner 2017.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/meta/transform.d,
 *                 tanya/meta/transform.d)
 */
module tanya.meta.transform;

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
 * If $(D_PARAM T) is an $(D_KEYWORD enum), $(D_INLINECODE OriginalType!T) evaluates to the
 * most base type of that $(D_KEYWORD enum) and to $(D_PARAM T) otherwise.
 *
 * Params:
 *  T = A type.
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
