/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Number theory.
 *
 * Copyright: Eugene Wissner 2017.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/math/nbtheory.d,
 *                 tanya/math/nbtheory.d)
 */
module tanya.math.nbtheory;

import tanya.math.mp;
import tanya.meta.trait;

/**
 * Calculates the absolute value of a number.
 *
 * Params:
 *  I = Value type.
 *  x = Value.
 *
 * Returns: Absolute value of $(D_PARAM x).
 */
I abs(I)(I x)
if (isIntegral!I)
{
    static if (isSigned!I)
    {
        return x >= 0 ? x : -x;
    }
    else
    {
        return x;
    }
}

///
pure nothrow @safe @nogc unittest
{
    int i = -1;
    assert(i.abs == 1);
    static assert(is(typeof(i.abs) == int));

    uint u = 1;
    assert(u.abs == 1);
    static assert(is(typeof(u.abs) == uint));
}

version (D_Ddoc)
{
    /// ditto
    I abs(I)(I x)
    if (isFloatingPoint!I);
}
else version (TanyaPhobos)
{
    import core.math;

    I abs(I)(I x)
    if (isFloatingPoint!I)
    {
        return fabs(cast(real) x);
    }
}
else
{
    extern I abs(I)(I number) pure nothrow @safe @nogc
    if (isFloatingPoint!I);
}

///
pure nothrow @safe @nogc unittest
{
    float f = -1.64;
    assert(f.abs == 1.64F);
    static assert(is(typeof(f.abs) == float));

    double d = -1.64;
    assert(d.abs == 1.64);
    static assert(is(typeof(d.abs) == double));

    real r = -1.64;
    assert(r.abs == 1.64L);
    static assert(is(typeof(r.abs) == real));
}

/// ditto
I abs(I : Integer)(const auto ref I x)
{
    auto result = Integer(x, x.allocator);
    result.sign = Sign.positive;
    return result;
}

/// ditto
I abs(I : Integer)(I x)
{
    x.sign = Sign.positive;
    return x;
}
