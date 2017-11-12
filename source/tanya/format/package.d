/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * This package contains formatting and conversion functions.
 *
 * Copyright: Eugene Wissner 2017.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/format/package.d,
 *                 tanya/format/package.d)
 */
module tanya.format;

import tanya.container.string;
public import tanya.format.conv;
import tanya.math;
import tanya.memory.op;
import tanya.meta.metafunction;
import tanya.meta.trait;

// Integer and floating point to string conversion is based on stb_sprintf
// written by Jeff Roberts.

// Returns the last part of buffer with converted number.
package(tanya) char[] integral2String(T)(T number, return ref char[21] buffer)
if (isIntegral!T)
{
    // abs the integer.
    ulong n64 = number < 0 ? -cast(long) number : number;

    char* start = buffer[].ptr + buffer.sizeof - 1;

    while (true)
    {
        // Do in 32-bit chunks (avoid lots of 64-bit divides even with constant
        // denominators).
        char* o = start - 8;
        uint n;
        if (n64 >= 100000000)
        {
            n = n64 % 100000000;
            n64 /= 100000000;
        }
        else
        {
            n = cast(uint) n64;
            n64 = 0;
        }

        while (n)
        {
            *--start = cast(char) (n % 10) + '0';
            n /= 10;
        }
        // Ignore the leading zero if it was the last part of the integer.
        if (n64 == 0)
        {
            if ((start[0] == '0')
             && (start != (buffer[].ptr + buffer.sizeof -1)))
            {
                ++start;
            }
            break;
        }
        // Copy leading zeros if it wasn't the most significant part of the
        // integer.
        while (start != o)
        {
            *--start = '0';
        }
    }

    // Get the length that we have copied.
    uint l = cast(uint) ((buffer[].ptr + buffer.sizeof - 1) - start);
    if (l == 0)
    {
        *--start = '0';
        l = 1;
    }
    else if (number < 0) // Set the sign.
    {
        *--start = '-';
        ++l;
    }

    return buffer[$ - l - 1 .. $ - 1];
}

// Converting an integer to string.
@nogc nothrow pure @system unittest
{
    char[21] buf;

    assert(integral2String(80, buf) == "80");
    assert(integral2String(-80, buf) == "-80");
    assert(integral2String(0, buf) == "0");
    assert(integral2String(uint.max, buf) == "4294967295");
    assert(integral2String(int.min, buf) == "-2147483648");
}

/*
 * Double-double high-precision floating point number.
 *
 * The first element is a base value corresponding to the nearest approximation
 * of the target $(D_PSYMBOL HP) value, and the second element is an offset
 * value corresponding to the difference between the target value and the base.
 * Thus, the $(D_PSYMBOL HP) value represented is the sum of the base and the
 * offset.
 */
private struct HP
{
    private double base;
    private double offset = 0.0;

    private void normalize() @nogc nothrow pure @safe
    {
        const double target = this.base + this.offset;
        this.offset -= target - this.base;
        this.base = target;
    }

    private void multiply(ref const HP x, ref const HP y)
    @nogc nothrow pure @safe
    {
        double ahi, bhi;
        long bt;
        this.base = x.base * y.base;
        copyFp(x.base, bt);
        bt &= (~cast(ulong) 0) << 27;
        copyFp(bt, ahi);

        double alo = x.base - ahi;
        copyFp(y.base, bt);
        bt &= (~cast(ulong) 0) << 27;
        copyFp(bt, bhi);

        double blo = y.base - bhi;
        this.offset = ahi * bhi - this.base + ahi * blo + alo * bhi + alo * blo;
        this.offset += x.base * y.offset + x.offset * y.base;
    }
}

private enum int special = 0x7000;

private static const ulong[20] powersOf10 = [
    1,
    10,
    100,
    1000,
    10000,
    100000,
    1000000,
    10000000,
    100000000,
    1000000000,
    10000000000UL,
    100000000000UL,
    1000000000000UL,
    10000000000000UL,
    100000000000000UL,
    1000000000000000UL,
    10000000000000000UL,
    100000000000000000UL,
    1000000000000000000UL,
    10000000000000000000UL,
];

private static const char[201] digitPairs =
    "0001020304050607080910111213141516171819202122232425262728293031323334353"
  ~ "6373839404142434445464748495051525354555657585960616263646566676869707172"
  ~ "737475767778798081828384858687888990919293949596979899";

private static const HP[23] bottom = [
    HP(1e+000), HP(1e+001), HP(1e+002), HP(1e+003), HP(1e+004), HP(1e+005),
    HP(1e+006), HP(1e+007), HP(1e+008), HP(1e+009), HP(1e+010), HP(1e+011),
    HP(1e+012), HP(1e+013), HP(1e+014), HP(1e+015), HP(1e+016), HP(1e+017),
    HP(1e+018), HP(1e+019), HP(1e+020), HP(1e+021), HP(1e+022),
];

private static const HP[22] negativeBottom = [
    HP(1e-001, -5.551115123125783e-018),
    HP(1e-002, -2.0816681711721684e-019),
    HP(1e-003, -2.0816681711721686e-020),
    HP(1e-004, -4.7921736023859299e-021),
    HP(1e-005, -8.1803053914031305e-022),
    HP(1e-006, 4.5251888174113741e-023),
    HP(1e-007, 4.5251888174113739e-024),
    HP(1e-008, -2.0922560830128471e-025),
    HP(1e-009, -6.2281591457779853e-026),
    HP(1e-010, -3.6432197315497743e-027),
    HP(1e-011, 6.0503030718060191e-028),
    HP(1e-012, 2.0113352370744385e-029),
    HP(1e-013, -3.0373745563400371e-030),
    HP(1e-014, 1.1806906454401013e-032),
    HP(1e-015, -7.7705399876661076e-032),
    HP(1e-016, 2.0902213275965398e-033),
    HP(1e-017, -7.1542424054621921e-034),
    HP(1e-018, -7.1542424054621926e-035),
    HP(1e-019, 2.4754073164739869e-036),
    HP(1e-020, 5.4846728545790429e-037),
    HP(1e-021, 9.2462547772103625e-038),
    HP(1e-022, -4.8596774326570872e-039),
];

private static const HP[13] top = [
    HP(1e+023, 8388608),
    HP(1e+046, 6.8601809640529717e+028),
    HP(1e+069, -7.253143638152921e+052),
    HP(1e+092, -4.3377296974619174e+075),
    HP(1e+115, -1.5559416129466825e+098),
    HP(1e+138, -3.2841562489204913e+121),
    HP(1e+161, -3.7745893248228135e+144),
    HP(1e+184, -1.7356668416969134e+167),
    HP(1e+207, -3.8893577551088374e+190),
    HP(1e+230, -9.9566444326005119e+213),
    HP(1e+253, 6.3641293062232429e+236),
    HP(1e+276, -5.2069140800249813e+259),
    HP(1e+299, -5.2504760255204387e+282),
];

private static const HP[13] negativeTop = [
    HP(1e-023, 3.9565301985100693e-040L),
    HP(1e-046, -2.299904345391321e-063L),
    HP(1e-069, 3.6506201437945798e-086L),
    HP(1e-092, 1.1875228833981544e-109L),
    HP(1e-115, -5.0644902316928607e-132L),
    HP(1e-138, -6.7156837247865426e-155L),
    HP(1e-161, -2.812077463003139e-178L),
    HP(1e-184, -5.7778912386589953e-201L),
    HP(1e-207, 7.4997100559334532e-224L),
    HP(1e-230, -4.6439668915134491e-247L),
    HP(1e-253, -6.3691100762962136e-270L),
    HP(1e-276, -9.436808465446358e-293L),
    HP(1e-299, 8.0970921678014997e-317L),
];

/*
 * Copies double into long and back bitwise.
 */
private void copyFp(T, U)(ref const U src, ref T dest) @trusted
if (T.sizeof == U.sizeof)
{
    copy((&src)[0 .. 1], (&dest)[0 .. 1]);
}

// Power can be -323 to +350.
private HP raise2Power10(const HP value, int power)
@nogc nothrow pure @safe
{
    HP result;
    if ((power >= 0) && (power <= 22))
    {
        result.multiply(value, bottom[power]);
    }
    else
    {
        HP p2;
        int e = power;

        if (power < 0)
        {
            e = -e;
        }
        int et = (e * 0x2c9) >> 14; // % 23
        if (et > 13)
        {
            et = 13;
        }
        int eb = e - (et * 23);

        result = value;
        if (power < 0)
        {
            if (eb != 0)
            {
                --eb;
                result.multiply(value, negativeBottom[eb]);
            }
            if (et)
            {
                result.normalize();
                --et;
                p2.multiply(result, negativeTop[et]);
                result = p2;
            }
        }
        else
        {
            if (eb != 0)
            {
                e = eb;
                if (eb > 22)
                {
                    eb = 22;
                }
                e -= eb;
                result.multiply(value, bottom[eb]);
                if (e)
                {
                    result.normalize();
                    p2.multiply(result, bottom[e]);
                    result = p2;
                }
            }
            if (et != 0)
            {
                result.normalize();
                --et;
                p2.multiply(result, top[et]);
                result = p2;
            }
        }
    }
    result.normalize();

    return result;
}

/*
 * Given a float value, returns the significant bits in bits, and the position
 * of the decimal point in $(D_PARAM decimalPos). +/-Inf and NaN are specified
 * by special values returned in the $(D_PARAM decimalPos). Sing bit is set in
 * $(D_PARAM sign).
 */
private const(char)[] real2String(double value,
                                  ref char[512] buffer,
                                  out int exponent,
                                  out bool sign) @nogc nothrow pure @trusted
{
    long bits;
    copyFp(value, bits);

    exponent = (bits >> 52) & 0x7ff;
    sign = signBit(value);
    if (sign)
    {
        value = -value;
    }

    if (exponent == 2047) // Is NaN or Inf?
    {
        exponent = special;
        return (bits & ((1UL << 52) - 1)) != 0 ? "NaN" : "Inf";
    }

    if (exponent == 0) // Is zero or denormal?
    {
        if ((bits << 1) == 0) // Zero.
        {
            exponent = 1;
            buffer[0] = '0';
            return buffer[0 .. 1];
        }

        // Find the right exponent for denormals.
        for (long cursor = 1UL << 51; (bits & cursor) == 0; cursor >>= 1)
        {
            --exponent;
        }
    }

    // "617 / 2048" and "1233 / 4096" are estimations for the common logarithm
    // (log10) of 2. Multiplied by a binary number it tells how big the number
    // is in decimals, so it translates the binary exponent into decimal
    // format. The estimation is tweaked to hit or undershoot by no more than
    // 1 of log10 of all exponents 1..2046.
    int tens = exponent - 1023; // Bias.
    if (tens < 0)
    {
        tens = tens * 617 / 2048;
    }
    else
    {
        tens = tens * 1233 / 4096 + 1;
    }

    // Move the significant bits into position and stick them into an int.
    HP p = raise2Power10(HP(value), 18 - tens);

    // Get full as much precision from double-double as possible.
    bits = cast(long) p.base;
    double vh = cast(double) bits;
    double ahi = p.base - vh;
    double t = ahi - p.base;
    double alo = p.base - ahi + t - vh - t;
    bits += cast(long) (ahi + alo + p.offset);

    // Check if we undershot (bits >= 10 ^ 19).
    if ((cast(ulong) bits) >= 1000000000000000000UL)
    {
        ++tens;
    }

    // Now do the rounding in integer land.
    enum uint fracDigits = 6;

    uint dg = 1;
    if ((cast(ulong) bits) >= powersOf10[9])
    {
        dg = 10;
    }
    uint length;
    while ((cast(ulong) bits) >= powersOf10[dg])
    {
        ++dg;
        if (dg == 20)
        {
            goto NoRound;
        }
    }
    if (fracDigits < dg)
    {
        // Add 0.5 at the right position and round.
        length = dg - fracDigits;
        if (length >= 24)
        {
            goto NoRound;
        }
        ulong r = powersOf10[length];
        bits = bits + (r / 2);
        if ((cast(ulong) bits) >= powersOf10[dg])
        {
            ++tens;
        }
        bits /= r;
    }
NoRound:

    // Kill long trailing runs of zeros.
    if (bits)
    {
        for (;;)
        {
            if (bits <= 0xffffffff)
            {
                break;
            }
            if (bits % 1000)
            {
                goto Zeroed;
            }
            bits /= 1000;
        }
        auto n = cast(uint) bits;
        while ((n % 1000) == 0)
        {
            n /= 1000;
        }
        bits = n;
    }
Zeroed:

    // Convert to string.
    auto result = buffer.ptr + 64;
    length = 0;
    while (true)
    {
        uint n;
        char* o = result - 8;
        // Do the conversion in chunks of U32s (avoid most 64-bit divides,
        // worth it, constant denomiators be damned).
        if (bits >= 100000000)
        {
            n = cast(uint) (bits % 100000000);
            bits /= 100000000;
        }
        else
        {
            n = cast(uint) bits;
            bits = 0;
        }
        while (n)
        {
            result -= 2;
            *cast(ushort*) result = *cast(ushort*) &digitPairs[(n % 100) * 2];
            n /= 100;
            length += 2;
        }
        if (bits == 0)
        {
            if ((length != 0) && (result[0] == '0'))
            {
                ++result;
                --length;
            }
            break;
        }
        for (; result !is o; ++length, --result)
        {
            *result = '0';
        }
    }
    exponent = tens;
    return result[0 .. length];
}

package(tanya) String format(string fmt, Args...)(Args args)
{
    String ret;

    foreach (spec; ParseFmt!(fmt, 0))
    {
        static if (is(typeof(spec) == string))
        {
            ret.insertBack(spec);
        }
        else static if (isSomeChar!(Args[0]))
        {
            ret.insertBack(args[0]);
        }
        else static if (isSomeString!(Args[0]))
        {
            if (args[0] is null)
            {
                ret.insertBack("null");
            }
            else
            {
                ret.insertBack(args[0]);
            }
        }
        else static if (isIntegral!(Args[0]))
        {
            char[21] buffer = void;
            ret.insertBack(integral2String(args[0], buffer));
        }
        else static if (isFloatingPoint!(Args[0]))
        {
            int precision = 6;
            bool negative;
            int decimalPos;
            uint l;
            char[512] num;

            // Read the double into a string
            const(char)[] sn = real2String(args[0], num, decimalPos, negative);
        }
        else
        {
            static assert(false, "Unable to format " ~ Args[0].stringof);
        }
    }

    return ret;
}

@nogc pure @system unittest
{
    // Format without arguments.
    assert(format!""() == "");
    assert(format!"asdfqweryxcvz"() == "asdfqweryxcvz");

    // String printing.
    assert(format!"{}"('c') == "c"); // char.
    assert(format!"{}"('с') == "с"); // wchar.

    assert(format!"{}"("Протопи ты мне баньку по-белому!")
                    == "Протопи ты мне баньку по-белому!");
    assert(format!"{}"(cast(string) null) == "null");

    // Integer conversions.
    assert(format!"{}"(8) == "8");
    assert(format!"{}"(8U) == "8");
    assert(format!"{}"(-8) == "-8");
    assert(format!"{}"(-8L) == "-8");

    // Floating point conversions.
    auto f = format!"{}"(1.2345);
}

private struct FormatSpec
{
}

// Returns the position of `tag` in `fmt`. If `tag` can't be found, returns the
// length of  `fmt`.
private size_t specPosition(string fmt, char tag)()
{
    foreach (i, c; fmt)
    {
        if (c == tag)
        {
            return i;
        }
    }
    return fmt.length;
}

private template ParseFmt(string fmt, size_t pos = 0)
{
    static if (fmt.length == 0)
    {
        alias ParseFmt = AliasSeq!();
    }
    else static if (fmt[0] == '{')
    {
        static if (fmt.length > 1 && fmt[1] == '{')
        {
            enum size_t pos = specPosition!(fmt[2 .. $], '{') + 2;
            alias ParseFmt = AliasSeq!(fmt[1 .. pos],
                                       ParseFmt!(fmt[pos .. $], pos));
        }
        else
        {
            enum size_t pos = specPosition!(fmt[1 .. $], '}') + 1;
            static if (pos < fmt.length)
            {
                alias ParseFmt = AliasSeq!(FormatSpec(),
                                           ParseFmt!(fmt[pos + 1 .. $], pos + 1));
            }
            else
            {
                static assert(false, "Enclosing '}' is missing");
            }
        }
    }
    else
    {
        enum size_t pos = specPosition!(fmt, '{');
        alias ParseFmt = AliasSeq!(fmt[0 .. pos],
                                   ParseFmt!(fmt[pos .. $], pos));
    }
}

@nogc nothrow pure @safe unittest
{
    static assert(ParseFmt!"".length == 0);

    static assert(ParseFmt!"asdf".length == 1);
    static assert(ParseFmt!"asdf"[0] == "asdf");

    static assert(ParseFmt!"{}".length == 1);
}
