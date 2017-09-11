/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * This package provides mathematical functions.
 *
 * Copyright: Eugene Wissner 2016-2017.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/math/package.d,
 *                 tanya/math/package.d)
 */
module tanya.math;

public import tanya.math.mp;
public import tanya.math.random;
import tanya.meta.trait;

/**
 * Computes $(D_PARAM x) to the power $(D_PARAM y) modulo $(D_PARAM z).
 *
 * If $(D_PARAM I) is an $(D_PSYMBOL Integer), the allocator of $(D_PARAM x)
 * is used to allocate the result.
 *
 * Params:
 *  I = Base type.
 *  G = Exponent type.
 *  H = Divisor type:
 *  x = Base.
 *  y = Exponent.
 *  z = Divisor.
 *
 * Returns: Reminder of the division of $(D_PARAM x) to the power $(D_PARAM y)
 *          by $(D_PARAM z).
 *
 * Precondition: $(D_INLINECODE z > 0)
 */
H pow(I, G, H)(in auto ref I x, in auto ref G y, in auto ref H z)
if (isIntegral!I && isIntegral!G && isIntegral!H)
in
{
    assert(z > 0, "Division by zero.");
}
body
{
    G mask = G.max / 2 + 1;
    H result;

    if (y == 0)
    {
        return 1 % z;
    }
    else if (y == 1)
    {
        return x % z;
    }
    do
    {
        immutable bit = y & mask;
        if (!result && bit)
        {
            result = x;
            continue;
        }

        result *= result;
        if (bit)
        {
            result *= x;
        }
        result %= z;
    }
    while (mask >>= 1);

    return result;
}

/// Ditto.
I pow(I)(const auto ref I x, const auto ref I y, const auto ref I z)
if (is(I == Integer))
in
{
    assert(z.length > 0, "Division by zero.");
}
body
{
    size_t i;
    auto tmp1 = Integer(x, x.allocator);
    auto result = Integer(x.allocator);
    bool firstBit;

    if (x.size == 0 && y.size != 0)
    {
        i = y.size;
    }
    else
    {
        result = 1;
    }
    while (i < y.size)
    {
        for (uint mask = 0x01; mask != 0x10000000; mask <<= 1)
        {
            if (y.rep[i] & mask)
            {
                result *= tmp1;
                result %= z;
            }
            auto tmp2 = tmp1;
            tmp1 *= tmp2;
            tmp1 %= z;
        }
        ++i;
    }
    return result;
}

///
pure nothrow @safe @nogc unittest
{
    assert(pow(3, 5, 7) == 5);
    assert(pow(2, 2, 1) == 0);
    assert(pow(3, 3, 3) == 0);
    assert(pow(7, 4, 2) == 1);
    assert(pow(53, 0, 2) == 1);
    assert(pow(53, 1, 3) == 2);
    assert(pow(53, 2, 5) == 4);
    assert(pow(0, 0, 5) == 1);
    assert(pow(0, 5, 5) == 0);
}

///
nothrow @safe @nogc unittest
{
    assert(pow(Integer(3), Integer(5), Integer(7)) == 5);
    assert(pow(Integer(2), Integer(2), Integer(1)) == 0);
    assert(pow(Integer(3), Integer(3), Integer(3)) == 0);
    assert(pow(Integer(7), Integer(4), Integer(2)) == 1);
    assert(pow(Integer(53), Integer(0), Integer(2)) == 1);
    assert(pow(Integer(53), Integer(1), Integer(3)) == 2);
    assert(pow(Integer(53), Integer(2), Integer(5)) == 4);
    assert(pow(Integer(0), Integer(0), Integer(5)) == 1);
    assert(pow(Integer(0), Integer(5), Integer(5)) == 0);
}

/**
 * Checks if $(D_PARAM x) is a prime.
 *
 * Params:
 *  x = The number should be checked.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM x) is a prime number,
 *          $(D_KEYWORD false) otherwise.
 */
bool isPseudoprime(ulong x) nothrow pure @safe @nogc
{
    return pow(2, x - 1, x) == 1;
}

///
pure nothrow @safe @nogc unittest
{
    assert(74623.isPseudoprime);
    assert(104729.isPseudoprime);
    assert(15485867.isPseudoprime);
    assert(!15485868.isPseudoprime);
}

private pure nothrow @safe @nogc unittest
{
    assert(74653.isPseudoprime);
    assert(74687.isPseudoprime);
    assert(74699.isPseudoprime);
    assert(74707.isPseudoprime);
    assert(74713.isPseudoprime);
    assert(74717.isPseudoprime);
    assert(74719.isPseudoprime);
    assert(74747.isPseudoprime);
    assert(74759.isPseudoprime);
    assert(74761.isPseudoprime);
    assert(74771.isPseudoprime);
    assert(74779.isPseudoprime);
    assert(74797.isPseudoprime);
    assert(74821.isPseudoprime);
    assert(74827.isPseudoprime);
    assert(9973.isPseudoprime);
    assert(49979693.isPseudoprime);
    assert(104395303.isPseudoprime);
    assert(593441861.isPseudoprime);
    assert(104729.isPseudoprime);
    assert(15485867.isPseudoprime);
    assert(49979693.isPseudoprime);
    assert(104395303.isPseudoprime);
    assert(593441861.isPseudoprime);
    assert(899809363.isPseudoprime);
    assert(982451653.isPseudoprime);
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
I abs(I : Integer)(const auto ref I x)
{
    auto result = Integer(x, x.allocator);
    result.sign = Sign.positive;
    return result;
}

/// Ditto.
I abs(I : Integer)(I x)
{
    x.sign = Sign.positive;
    return x;
}

/// Ditto.
I abs(I)(const I x)
if (isIntegral!I)
{
    return x >= 0 ? x : -x;
}
