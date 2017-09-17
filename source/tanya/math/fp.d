/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Copyright: Eugene Wissner 2017.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/math/fp.d,
 *                 tanya/math/fp.d)
 */
module tanya.math.fp;

import tanya.math.nbtheory;

/**
 * Floating-point number precisions according to IEEE-754.
 */
enum IEEEPrecision : ubyte
{
    /// Single precision: 64-bit.
    single = 4,

    /// Single precision: 64-bit.
    double_ = 8,

    /// Extended precision: 80-bit.
    extended = 10,
}

/**
 * Tests the precision of floating-point type $(D_PARAM F).
 *
 * For $(D_KEYWORD float), $(D_PSYMBOL ieeePrecision) always evaluates to
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
        enum IEEEPrecision ieeePrecision = IEEEPrecision.extended;
    }
    else version (X86_64)
    {
        enum IEEEPrecision ieeePrecision = IEEEPrecision.extended;
    }
    else
    {
        static assert(false, "Unsupported IEEE 754 floating point precision");
    }
}

private union FloatBits(F)
{
    F floating;
    static if (ieeePrecision!F == IEEEPrecision.single)
    {
        uint integral;
    }
    else static if (ieeePrecision!F == IEEEPrecision.double_)
    {
        ulong integral;
    }
    else static if (ieeePrecision!F == IEEEPrecision.extended)
    {
        struct // Little-endian.
        {
            ulong mantissa;
            ushort exp;
        }
    }
    else
    {
        static assert(false, "Unsupported IEEE 754 floating point precision");
    }
}

enum FloatingPointClass : ubyte
{
    nan,
    zero,
    infinite,
    subnormal,
    normal,
}

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
        if (bits.integral > 0x7f800000)
        {
            return FloatingPointClass.nan;
        }
        else if (bits.integral == 0x7f800000)
        {
            return FloatingPointClass.infinite;
        }
        else if (bits.integral < 0x800000)
        {
            return FloatingPointClass.subnormal;
        }
    }
    else static if (ieeePrecision!F == IEEEPrecision.double_)
    {
        if (bits.integral > 0x7ff0000000000000)
        {
            return FloatingPointClass.nan;
        }
        else if (bits.integral == 0x7ff0000000000000)
        {
            return FloatingPointClass.infinite;
        }
        else if (bits.integral < 0x10000000000000)
        {
            return FloatingPointClass.subnormal;
        }
    }
    else static if (ieeePrecision!F == IEEEPrecision.extended)
    {
        if (bits.exp == 0x7fff)
        {
            if ((bits.mantissa & 0x7fffffffffffffff) == 0)
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
        else if (bits.mantissa < 0x8000000000000000) // "Unnormal".
        {
            return FloatingPointClass.nan;
        }
    }

    return FloatingPointClass.normal;
}

bool isFinite(F)(F x)
if (isFloatingPoint!F)
{
    FloatBits!F bits;
    static if (ieeePrecision!F == IEEEPrecision.single)
    {
        bits.floating = x;
        bits.integral &= 0x7f800000;
        return bits.integral != 0x7f800000;
    }
    else static if (ieeePrecision!F == IEEEPrecision.double_)
    {
        bits.floating = x;
        bits.integral &= 0x7ff0000000000000;
        return bits.integral != 0x7ff0000000000000;
    }
    else static if (ieeePrecision!F == IEEEPrecision.extended)
    {
        bits.floating = abs(x);
        return (bits.exp != 0x7fff) && (bits.mantissa >= 0x8000000000000000);
    }
}

bool isNaN(F)(F x)
if (isFloatingPoint!F)
{
    FloatBits!F bits;
    bits.floating = abs(x);

    static if (ieeePrecision!F == IEEEPrecision.single)
    {
        return bits.integral > 0x7f800000;
    }
    else static if (ieeePrecision!F == IEEEPrecision.double_)
    {
        return bits.integral > 0x7ff0000000000000;
    }
    else static if (ieeePrecision!F == IEEEPrecision.extended)
    {
        if ((bits.exp == 0x7fff && (bits.mantissa & 0x7fffffffffffffff) != 0)
         || ((bits.exp != 0) && (bits.mantissa < 0x8000000000000000)))
        {
            return true;
        }
        return false;
    }
}

bool isInfinity(F)(F x)
if (isFloatingPoint!F)
{
    FloatBits!F bits;
    bits.floating = abs(x);
    static if (ieeePrecision!F == IEEEPrecision.single)
    {
        return bits.integral == 0x7f800000;
    }
    else static if (ieeePrecision!F == IEEEPrecision.double_)
    {
        return bits.integral == 0x7ff0000000000000;
    }
    else static if (ieeePrecision!F == IEEEPrecision.extended)
    {
        return (bits.exp == 0x7fff)
            && ((bits.mantissa & 0x7fffffffffffffff) == 0);
    }
}

bool isSubnormal(F)(F x)
if (isFloatingPoint!F)
{
    FloatBits!F bits;
    bits.floating = abs(x);
    static if (ieeePrecision!F == IEEEPrecision.single)
    {
        return bits.integral < 0x800000;
    }
    else static if (ieeePrecision!F == IEEEPrecision.double_)
    {
        return bits.integral < 0x10000000000000;
    }
    else static if (ieeePrecision!F == IEEEPrecision.extended)
    {
        return bits.exp == 0;
    }
}

bool isNormal(F)(F x)
if (isFloatingPoint!F)
{
    static if (ieeePrecision!F == IEEEPrecision.single)
    {
        FloatBits!F bits;
        bits.floating = x;
        bits.integral &= 0x7f800000;
        return bits.integral != 0 && bits.integral != 0x7f800000;
    }
    else static if (ieeePrecision!F == IEEEPrecision.double_)
    {
        FloatBits!F bits;
        bits.floating = x;
        bits.integral &= 0x7ff0000000000000;
        return bits.integral != 0 && bits.integral != 0x7ff0000000000000;
    }
    else static if (ieeePrecision!F == IEEEPrecision.extended)
    {
        return classify(x) == FloatingPointClass.normal;
    }
}

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
        return (bits.integral & (1 << 63)) != 0;
    }
    else static if (ieeePrecision!F == IEEEPrecision.extended)
    {
        return (bits.exp & (1 << 15)) != 0;
    }
}
