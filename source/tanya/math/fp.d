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
        struct
        {
            ulong mantissa;
            ushort exp;
        }
    }
    else
    {
        static assert(false, "Unsupported IEEE-754 floating point representation");
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
    }

    return FloatingPointClass.normal;
}

bool isFinite(F)(F x)
if (isFloatingPoint!F)
{
    static if (ieeePrecision!F == IEEEPrecision.single)
    {
        FloatBits!F bits;
        bits.floating = x;
        bits.integral &= 0x7f800000;
        return bits.integral != 0x7f800000;
    }
    else static if (ieeePrecision!F == IEEEPrecision.double_)
    {
        FloatBits!F bits;
        bits.floating = x;
        bits.integral &= 0x7ff0000000000000;
        return bits.integral != 0x7ff0000000000000;
    }
    else static if (ieeePrecision!F == IEEEPrecision.extended)
    {
        FloatBits!F bits;
        bits.floating = abs(x);
        return exponent != 0x7fff;
    }
}

bool isNaN(F)(F x)
if (isFloatingPoint!F)
{
    static if (ieeePrecision!F == IEEEPrecision.single)
    {
        FloatBits!F bits;
        bits.floating = abs(x);
        return bits.integral > 0x7f800000;
    }
    else static if (ieeePrecision!F == IEEEPrecision.double_)
    {
        FloatBits!F bits;
        bits.floating = abs(x);
        return bits.integral > 0x7ff0000000000000;
    }
    else static if (ieeePrecision!F == IEEEPrecision.extended)
    {
        FloatBits!F bits;
        bits.floating = abs(x);
        return bits.exponent == 0x7fff && bits.mantissa != 0;
    }
}

bool isInfinity(F)(F x)
if (isFloatingPoint!F)
{
    static if (ieeePrecision!F == IEEEPrecision.single)
    {
        FloatBits!F bits;
        bits.floating = abs(x);
        return bits.integral == 0x7f800000;
    }
    else static if (ieeePrecision!F == IEEEPrecision.double_)
    {
        FloatBits!F bits;
        bits.floating = abs(x);
        return bits.integral == 0x7ff0000000000000;
    }
    else static if (ieeePrecision!F == IEEEPrecision.extended)
    {
        FloatBits!F bits;
        bits.floating = abs(x);
        return bits.exponent == 0x7fff && bits.mantissa == 0;
    }
}

bool isSubnormal(F)(F x)
if (isFloatingPoint!F)
{
    static if (ieeePrecision!F == IEEEPrecision.single)
    {
        FloatBits!F bits;
        bits.floating = abs(x);
        return bits.integral < 0x800000;
    }
    else static if (ieeePrecision!F == IEEEPrecision.double_)
    {
        FloatBits!F bits;
        bits.floating = abs(x);
        return bits.integral < 0x10000000000000;
    }
    else static if (ieeePrecision!F == IEEEPrecision.extended)
    {
        FloatBits!F bits;
        bits.floating = abs(x);
        return bits.exponent == 0 && bits.mantissa != 0;
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
        FloatBits!F bits;
        bits.floating = abs(x);
        return bits.exponent != 0 && exponent != 0x7fff;
    }
}
