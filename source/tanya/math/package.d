/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * This package provides mathematical functions.
 *
 * The $(D_PSYMBOL tanya.math) package itself provides only representation
 * functions for built-in types, such as functions that provide information
 * about internal representation of floating-point numbers and low-level
 * operatons on these. Actual mathematical functions and additional types can
 * be found in its submodules. $(D_PSYMBOL tanya.math) doesn't import any
 * submodules publically, they should be imported explicitly.
 *
 * Copyright: Eugene Wissner 2016-2020.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/math/package.d,
 *                 tanya/math/package.d)
 */
module tanya.math;

import tanya.math.nbtheory;
import tanya.meta.trait;
import tanya.meta.transform;

/// Floating-point number precisions according to IEEE-754.
enum IEEEPrecision : ubyte
{
    single = 4, /// Single precision: 64-bit.
    double_ = 8, /// Single precision: 64-bit.
    doubleExtended = 10, /// Double extended precision: 80-bit.
}

/**
 * Tests the precision of floating-point type $(D_PARAM F).
 *
 * For $(D_KEYWORD float) $(D_PSYMBOL ieeePrecision) always evaluates to
 * $(D_INLINECODE IEEEPrecision.single); for $(D_KEYWORD double) - to
 * $(D_INLINECODE IEEEPrecision.double). It returns different values only
 * for $(D_KEYWORD real), since $(D_KEYWORD real) is a platform-dependent type.
 *
 * If $(D_PARAM F) is a $(D_KEYWORD real) and the target platform isn't
 * currently supported, static assertion error will be raised (you can use
 * $(D_INLINECODE is(typeof(ieeePrecision!F))) for testing the platform support
 * without a compilation error).
 *
 * Params:
 *  F = Type to be tested.
 *
 * Returns: Precision according to IEEE-754.
 *
 * See_Also: $(D_PSYMBOL IEEEPrecision).
 */
template ieeePrecision(F)
if (isFloatingPoint!F)
{
    static if (F.sizeof == float.sizeof)
    {
        enum IEEEPrecision ieeePrecision = IEEEPrecision.single;
    }
    else static if (F.sizeof == double.sizeof)
    {
        enum IEEEPrecision ieeePrecision = IEEEPrecision.double_;
    }
    else version (X86)
    {
        enum IEEEPrecision ieeePrecision = IEEEPrecision.doubleExtended;
    }
    else version (X86_64)
    {
        enum IEEEPrecision ieeePrecision = IEEEPrecision.doubleExtended;
    }
    else
    {
        static assert(false, "Unsupported IEEE 754 floating point precision");
    }
}

///
@nogc nothrow pure @safe unittest
{
    static assert(ieeePrecision!float == IEEEPrecision.single);
    static assert(ieeePrecision!double == IEEEPrecision.double_);
}

package(tanya) union FloatBits(F)
{
    Unqual!F floating;
    static if (ieeePrecision!F == IEEEPrecision.single)
    {
        uint integral;
        enum uint expMask = 0x7f800000;
    }
    else static if (ieeePrecision!F == IEEEPrecision.double_)
    {
        ulong integral;
        enum ulong expMask = 0x7ff0000000000000;
    }
    else static if (ieeePrecision!F == IEEEPrecision.doubleExtended)
    {
        struct // Little-endian.
        {
            ulong mantissa;
            ushort exp;
        }
        enum ulong mantissaMask = 0x7fffffffffffffff;
        enum uint expMask = 0x7fff;
    }
    else
    {
        static assert(false, "Unsupported IEEE 754 floating point precision");
    }
}

/**
 * Floating-point number classifications.
 */
enum FloatingPointClass : ubyte
{
    /**
     * Not a Number.
     *
     * See_Also: $(D_PSYMBOL isNaN).
     */
    nan,

    /// Zero.
    zero,

    /**
     * Infinity.
     *
     * See_Also: $(D_PSYMBOL isInfinity).
     */
    infinite,

    /**
     * Denormalized number.
     *
     * See_Also: $(D_PSYMBOL isSubnormal).
     */
    subnormal,

    /**
     * Normalized number.
     *
     * See_Also: $(D_PSYMBOL isNormal).
     */
    normal,
}

/**
 * Returns whether $(D_PARAM x) is a NaN, zero, infinity, subnormal or
 * normalized number.
 *
 * This function doesn't distinguish between negative and positive infinity,
 * negative and positive NaN or negative and positive zero.
 *
 * Params:
 *  F = Type of the floating point number.
 *  x = Floating point number.
 *
 * Returns: Classification of $(D_PARAM x).
 */
FloatingPointClass classify(F)(F x)
if (isFloatingPoint!F)
{
    if (x == 0)
    {
        return FloatingPointClass.zero;
    }
    FloatBits!F bits;
    bits.floating = abs(x);

    static if (ieeePrecision!F == IEEEPrecision.single)
    {
        if (bits.integral > bits.expMask)
        {
            return FloatingPointClass.nan;
        }
        else if (bits.integral == bits.expMask)
        {
            return FloatingPointClass.infinite;
        }
        else if (bits.integral < (1 << 23))
        {
            return FloatingPointClass.subnormal;
        }
    }
    else static if (ieeePrecision!F == IEEEPrecision.double_)
    {
        if (bits.integral > bits.expMask)
        {
            return FloatingPointClass.nan;
        }
        else if (bits.integral == bits.expMask)
        {
            return FloatingPointClass.infinite;
        }
        else if (bits.integral < (1L << 52))
        {
            return FloatingPointClass.subnormal;
        }
    }
    else static if (ieeePrecision!F == IEEEPrecision.doubleExtended)
    {
        if (bits.exp == bits.expMask)
        {
            if ((bits.mantissa & bits.mantissaMask) == 0)
            {
                return FloatingPointClass.infinite;
            }
            else
            {
                return FloatingPointClass.nan;
            }
        }
        else if (bits.exp == 0)
        {
            return FloatingPointClass.subnormal;
        }
        else if (bits.mantissa < (1L << 63)) // "Unnormal".
        {
            return FloatingPointClass.nan;
        }
    }

    return FloatingPointClass.normal;
}

///
@nogc nothrow pure @safe unittest
{
    assert(classify(0.0) == FloatingPointClass.zero);
    assert(classify(double.nan) == FloatingPointClass.nan);
    assert(classify(double.infinity) == FloatingPointClass.infinite);
    assert(classify(-double.infinity) == FloatingPointClass.infinite);
    assert(classify(1.4) == FloatingPointClass.normal);
    assert(classify(1.11254e-307 / 10) == FloatingPointClass.subnormal);

    assert(classify(0.0f) == FloatingPointClass.zero);
    assert(classify(float.nan) == FloatingPointClass.nan);
    assert(classify(float.infinity) == FloatingPointClass.infinite);
    assert(classify(-float.infinity) == FloatingPointClass.infinite);
    assert(classify(0.3) == FloatingPointClass.normal);
    assert(classify(5.87747e-38f / 10) == FloatingPointClass.subnormal);

    assert(classify(0.0L) == FloatingPointClass.zero);
    assert(classify(real.nan) == FloatingPointClass.nan);
    assert(classify(real.infinity) == FloatingPointClass.infinite);
    assert(classify(-real.infinity) == FloatingPointClass.infinite);
}

/**
 * Determines whether $(D_PARAM x) is a finite number.
 *
 * Params:
 *  F = Type of the floating point number.
 *  x = Floating point number.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM x) is a finite number,
 *          $(D_KEYWORD false) otherwise.
 *
 * See_Also: $(D_PSYMBOL isInfinity).
 */
bool isFinite(F)(F x)
if (isFloatingPoint!F)
{
    FloatBits!F bits;
    static if (ieeePrecision!F == IEEEPrecision.single
            || ieeePrecision!F == IEEEPrecision.double_)
    {
        bits.floating = x;
        bits.integral &= bits.expMask;
        return bits.integral != bits.expMask;
    }
    else static if (ieeePrecision!F == IEEEPrecision.doubleExtended)
    {
        bits.floating = abs(x);
        return (bits.exp != bits.expMask)
            && (bits.exp == 0 || bits.mantissa >= (1L << 63));
    }
}

///
@nogc nothrow pure @safe unittest
{
    assert(!isFinite(float.infinity));
    assert(!isFinite(-double.infinity));
    assert(isFinite(0.0));
    assert(!isFinite(float.nan));
    assert(isFinite(5.87747e-38f / 10));
    assert(isFinite(1.11254e-307 / 10));
    assert(isFinite(0.5));
}

/**
 * Determines whether $(D_PARAM x) is $(B n)ot $(B a) $(B n)umber (NaN).
 *
 * Params:
 *  F = Type of the floating point number.
 *  x = Floating point number.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM x) is not a number,
 *          $(D_KEYWORD false) otherwise.
 */
bool isNaN(F)(F x)
if (isFloatingPoint!F)
{
    FloatBits!F bits;
    bits.floating = abs(x);

    static if (ieeePrecision!F == IEEEPrecision.single
            || ieeePrecision!F == IEEEPrecision.double_)
    {
        return bits.integral > bits.expMask;
    }
    else static if (ieeePrecision!F == IEEEPrecision.doubleExtended)
    {
        const maskedMantissa = bits.mantissa & bits.mantissaMask;
        if ((bits.exp == bits.expMask && maskedMantissa != 0)
         || ((bits.exp != 0) && (bits.mantissa < (1L << 63))))
        {
            return true;
        }
        return false;
    }
}

///
@nogc nothrow pure @safe unittest
{
    assert(isNaN(float.init));
    assert(isNaN(double.init));
    assert(isNaN(real.init));
}

/**
 * Determines whether $(D_PARAM x) is a positive or negative infinity.
 *
 * Params:
 *  F = Type of the floating point number.
 *  x = Floating point number.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM x) is infinity, $(D_KEYWORD false)
 *          otherwise.
 *
 * See_Also: $(D_PSYMBOL isFinite).
 */
bool isInfinity(F)(F x)
if (isFloatingPoint!F)
{
    FloatBits!F bits;
    bits.floating = abs(x);
    static if (ieeePrecision!F == IEEEPrecision.single
            || ieeePrecision!F == IEEEPrecision.double_)
    {
        return bits.integral == bits.expMask;
    }
    else static if (ieeePrecision!F == IEEEPrecision.doubleExtended)
    {
        return (bits.exp == bits.expMask)
            && ((bits.mantissa & bits.mantissaMask) == 0);
    }
}

///
@nogc nothrow pure @safe unittest
{
    assert(isInfinity(float.infinity));
    assert(isInfinity(-float.infinity));
    assert(isInfinity(double.infinity));
    assert(isInfinity(-double.infinity));
    assert(isInfinity(real.infinity));
    assert(isInfinity(-real.infinity));
}

/**
 * Determines whether $(D_PARAM x) is a denormilized number or not.
 *
 * Denormalized number is a number between `0` and `1` that cannot be
 * represented as
 *
 * <pre>
 * m*2<sup>e</sup>
 * </pre>
 *
 * where $(I m) is the mantissa and $(I e) is an exponent that fits into the
 * exponent field of the type $(D_PARAM F).
 *
 * `0` is neither normalized nor denormalized.
 *
 * Params:
 *  F = Type of the floating point number.
 *  x = Floating point number.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM x) is a denormilized number,
 *          $(D_KEYWORD false) otherwise.
 *
 * See_Also: $(D_PSYMBOL isNormal).
 */
bool isSubnormal(F)(F x)
if (isFloatingPoint!F)
{
    FloatBits!F bits;
    bits.floating = abs(x);
    static if (ieeePrecision!F == IEEEPrecision.single)
    {
        return bits.integral < (1 << 23) && bits.integral > 0;
    }
    else static if (ieeePrecision!F == IEEEPrecision.double_)
    {
        return bits.integral < (1L << 52) && bits.integral > 0;
    }
    else static if (ieeePrecision!F == IEEEPrecision.doubleExtended)
    {
        return bits.exp == 0 && bits.mantissa != 0;
    }
}

///
@nogc nothrow pure @safe unittest
{
    assert(!isSubnormal(0.0f));
    assert(!isSubnormal(float.nan));
    assert(!isSubnormal(float.infinity));
    assert(!isSubnormal(0.3f));
    assert(isSubnormal(5.87747e-38f / 10));

    assert(!isSubnormal(0.0));
    assert(!isSubnormal(double.nan));
    assert(!isSubnormal(double.infinity));
    assert(!isSubnormal(1.4));
    assert(isSubnormal(1.11254e-307 / 10));

    assert(!isSubnormal(0.0L));
    assert(!isSubnormal(real.nan));
    assert(!isSubnormal(real.infinity));
}

/**
 * Determines whether $(D_PARAM x) is a normilized number or not.
 *
 * Normalized number is a number that can be represented as
 *
 * <pre>
 * m*2<sup>e</sup>
 * </pre>
 *
 * where $(I m) is the mantissa and $(I e) is an exponent that fits into the
 * exponent field of the type $(D_PARAM F).
 *
 * `0` is neither normalized nor denormalized.
 *
 * Params:
 *  F = Type of the floating point number.
 *  x = Floating point number.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM x) is a normilized number,
 *          $(D_KEYWORD false) otherwise.
 *
 * See_Also: $(D_PSYMBOL isSubnormal).
 */
bool isNormal(F)(F x)
if (isFloatingPoint!F)
{
    static if (ieeePrecision!F == IEEEPrecision.single
            || ieeePrecision!F == IEEEPrecision.double_)
    {
        FloatBits!F bits;
        bits.floating = x;
        bits.integral &= bits.expMask;
        return bits.integral != 0 && bits.integral != bits.expMask;
    }
    else static if (ieeePrecision!F == IEEEPrecision.doubleExtended)
    {
        return classify(x) == FloatingPointClass.normal;
    }
}

///
@nogc nothrow pure @safe unittest
{
    assert(!isNormal(0.0f));
    assert(!isNormal(float.nan));
    assert(!isNormal(float.infinity));
    assert(isNormal(0.3f));
    assert(!isNormal(5.87747e-38f / 10));

    assert(!isNormal(0.0));
    assert(!isNormal(double.nan));
    assert(!isNormal(double.infinity));
    assert(isNormal(1.4));
    assert(!isNormal(1.11254e-307 / 10));

    assert(!isNormal(0.0L));
    assert(!isNormal(real.nan));
    assert(!isNormal(real.infinity));
}

/**
 * Determines whether the sign bit of $(D_PARAM x) is set or not.
 *
 * If the sign bit, $(D_PARAM x) is a negative number, otherwise positive.
 *
 * Params:
 *  F = Type of the floating point number.
 *  x = Floating point number.
 *
 * Returns: $(D_KEYWORD true) if the sign bit of $(D_PARAM x) is set,
 *          $(D_KEYWORD false) otherwise.
 */
bool signBit(F)(F x)
if (isFloatingPoint!F)
{
    FloatBits!F bits;
    bits.floating = x;
    static if (ieeePrecision!F == IEEEPrecision.single)
    {
        return (bits.integral & (1 << 31)) != 0;
    }
    else static if (ieeePrecision!F == IEEEPrecision.double_)
    {
        return (bits.integral & (1L << 63)) != 0;
    }
    else static if (ieeePrecision!F == IEEEPrecision.doubleExtended)
    {
        return (bits.exp & (1 << 15)) != 0;
    }
}

///
@nogc nothrow pure @safe unittest
{
    assert(signBit(-1.0f));
    assert(!signBit(1.0f));

    assert(signBit(-1.0));
    assert(!signBit(1.0));

    assert(signBit(-1.0L));
    assert(!signBit(1.0L));
}

/**
 * Computes $(D_PARAM x) to the power $(D_PARAM y) modulo $(D_PARAM z).
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
    assert(z > 0, "Division by zero");
}
do
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

///
@nogc nothrow pure @safe unittest
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
