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

version (TanyaNative)
{
}
else
{
    import core.math : fabs;
    import std.math : log;
}

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
else version (TanyaNative)
{
    extern I abs(I)(I number) pure nothrow @safe @nogc
    if (isFloatingPoint!I);
}
else
{
    I abs(I)(I x)
    if (isFloatingPoint!I)
    {
        return fabs(cast(real) x);
    }
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

version (D_Ddoc)
{
    /**
     * Calculates natural logarithm of $(D_PARAM x).
     *
     * Params:
     *  x = Argument.
     *
     * Returns: Natural logarithm of $(D_PARAM x).
     */
    float ln(float x) pure nothrow @safe @nogc;
    /// ditto
    double ln(double x) pure nothrow @safe @nogc;
    /// ditto
    real ln(real x) pure nothrow @safe @nogc;
}
else version (TanyaNative)
{
    extern float ln(float x) pure nothrow @safe @nogc;
    extern double ln(double x) pure nothrow @safe @nogc;
    extern real ln(real x) pure nothrow @safe @nogc;
}
else
{
    float ln(float x) pure nothrow @safe @nogc
    {
        return log(x);
    }
    double ln(double x) pure nothrow @safe @nogc
    {
        return log(x);
    }
    alias ln = log;
}

///
pure nothrow @safe @nogc unittest
{
    import tanya.math;

    assert(isNaN(ln(-7.389f)));
    assert(isNaN(ln(-7.389)));
    assert(isNaN(ln(-7.389L)));

    assert(isInfinity(ln(0.0f)));
    assert(isInfinity(ln(0.0)));
    assert(isInfinity(ln(0.0L)));

    assert(ln(1.0f) == 0.0f);
    assert(ln(1.0) == 0.0);
    assert(ln(1.0L) == 0.0L);
}
