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
import tanya.encoding.ascii;
public import tanya.format.conv;
import tanya.math;
import tanya.memory.op;
import tanya.meta.metafunction;
import tanya.meta.trait;
import tanya.range.array;

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
        HP a, b;
        long bt;

        this.base = x.base * y.base;
        copyFp(x.base, bt);
        bt &= ulong.max << 27;
        copyFp(bt, a.base);

        a.offset = x.base - a.base;
        copyFp(y.base, bt);
        bt &= ulong.max << 27;
        copyFp(bt, b.base);

        b.offset = y.base - b.base;
        this.offset = a.base * b.base - this.base
                    + a.base * b.offset
                    + a.offset * b.base
                    + a.offset * b.offset;
        this.offset += x.base * y.offset + x.offset * y.base;
    }
}

private enum special = 0x7000;
private enum char period = '.';

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

private enum ulong tenTo19th = 1000000000000000000UL;

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
 * of the decimal point in $(D_PARAM exponent). +/-Inf and NaN are specified
 * by special values returned in the $(D_PARAM exponent). Sing bit is set in
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
    auto a = HP(p.base - vh);
    double t = a.base - p.base;
    a.offset = p.base - a.base + t - vh - t;
    bits += cast(long) (a.base + a.offset + p.offset);

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
        while (bits > 0xffffffff)
        {
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

/*
 * Copies double into long and back bitwise.
 */
private void copyFp(T, U)(ref const U src, ref T dest) @trusted
if (T.sizeof == U.sizeof)
{
    copy((&src)[0 .. 1], (&dest)[0 .. 1]);
}

package(tanya) String format(string fmt, Args...)(auto ref Args args)
{
    String result;

    static if (isSomeString!(Args[0])) // String
    {
        if (args[0] is null)
        {
            result.insertBack("null");
        }
        else
        {
            result.insertBack(args[0]);
        }
    }
    else static if (isSomeChar!(Args[0])) // Char
    {
        result.insertBack(args[0]);
    }
    else static if (isFloatingPoint!(Args[0])) // Float
    {
        char[512] buffer; // Big enough for e+308 or e-307.
        char[8] tail = 0;
        char *s;
        uint precision = 6;
        bool negative;
        int decimalPos;

        // Read the double into a string.
        auto realString = real2String(args[0], buffer, decimalPos, negative);
        auto length = cast(uint) realString.length;

        // Clamp the precision and delete extra zeros after clamp.
        uint n = precision;
        if (length > precision)
        {
            length = precision;
        }
        while ((length > 1)
            && (precision != 0)
            && (realString[length - 1] == '0'))
        {
            --precision;
            --length;
        }

        if (negative)
        {
            result.insertBack('-');
        }
        if (decimalPos == special)
        {
            result.insertBack(realString);
            goto ParamEnd;
        }

        // Should we use sceintific notation?
        if ((decimalPos <= -4) || (decimalPos > cast(int) n))
        {
            if (precision > length)
            {
                precision = length - 1;
            }
            else if (precision != 0)
            {
               // When using %e, there is one digit before the decimal.
               --precision;
            }

            s = buffer.ptr + 64;
            // Handle leading chars.
            *s++ = realString[0];

            if (precision != 0)
            {
                *s++ = period;
            }

            // Handle after decimal.
            if ((length - 1) > precision)
            {
                length = precision + 1;
            }
            for (n = 1; n < length; n++)
            {
                *s++ = realString[n];
            }
            precision = 0;
            // Dump the exponent.
            tail[1] = 'e';
            decimalPos -= 1;
            if (decimalPos < 0)
            {
                tail[2] = '-';
                decimalPos = -decimalPos;
            }
            else
            {
                tail[2] = '+';
            }

            n = (decimalPos >= 100) ? 5 : 4;

            tail[0] = cast(char) n;
            while (true)
            {
                tail[n] = '0' + decimalPos % 10;
                if (n <= 3)
                {
                    break;
                }
                --n;
                decimalPos /= 10;
            }
        }
        else
        {
            // This is the insane action to get the pr to match %g sematics
            // for %f
            if (decimalPos > 0)
            {
                precision = decimalPos < (cast(int) length)
                          ? length - decimalPos
                          : 0;
            }
            else
            {
                if (precision > length)
                {
                    precision = -decimalPos + length;
                }
                else
                {
                    precision = -decimalPos + precision;
                }
            }

            s = buffer.ptr + 64;

            // Handle the three decimal varieties.
            if (decimalPos <= 0)
            {
                // Handle 0.000*000xxxx.
                *s++ = '0';
                if (precision != 0)
                {
                    *s++ = period;
                }
                n = -decimalPos;
                if (n > precision)
                {
                    n = precision;
                }
                uint i = n;
                while (i > 0)
                {
                    if (((cast(size_t) s) & 3) == 0)
                    {
                        break;
                    }
                    *s++ = '0';
                    --i;
                }
                while (i >= 4)
                {
                    *cast(uint*) s = 0x30303030;
                    s += 4;
                    i -= 4;
                }
                while (i > 0)
                {
                    *s++ = '0';
                    --i;
                }
                if ((length + n) > precision)
                {
                    length = precision - n;
                }
                i = length;
                while (i > 0)
                {
                    *s++ = realString.front;
                    realString.popFront();
                    --i;
                }
            }
            else if (cast(uint) decimalPos >= length)
            {
                // Handle xxxx000*000.0.
                n = 0;
                do
                {
                    *s++ = realString[n];
                    ++n;
                }
                while (n < length);
                if (n < cast(uint) decimalPos)
                {
                    n = decimalPos - n;
                    while (n)
                    {
                        if (((cast(size_t) s) & 3) == 0)
                        {
                            break;
                        }
                        *s++ = '0';
                        --n;
                    }
                    while (n >= 4)
                    {
                        *cast(uint*) s = 0x30303030;
                        s += 4;
                        n -= 4;
                    }
                    while (n)
                    {
                        *s++ = '0';
                        --n;
                    }
                }
                if (precision != 0)
                {
                    *s++ = period;
                }
            }
            else
            {
                // Handle xxxxx.xxxx000*000.
                n = 0;
                do
                {
                    *s++ = realString[n];
                    ++n;
                }
                while (n < cast(uint) decimalPos);

                if (precision > 0)
                {
                    *s++ = period;
                }
                if ((length - decimalPos) > precision)
                {
                    length = precision + decimalPos;
                }
                while (n < length)
                {
                    *s++ = realString[n];
                    ++n;
                }
            }
            precision = 0;
        }

        // Get the length that we copied.
        length = cast(uint) (s - (buffer.ptr + 64));

        result.insertBack(buffer[64 .. 64 + length]); // Number.
        result.insertBack(tail[1 .. tail[0] + 1]); // Tail.
    }
    else static if (isPointer!(Args[0])) // Pointer
    {
        char[size_t.sizeof * 2] buffer;
        size_t position = buffer.length;
        auto address = cast(size_t) args[0];

        do // Write at least "0" if the pointer is null.
        {
            buffer[--position] = lowerHexDigits[cast(size_t) (address & 15)];
            address >>= 4;
        }
        while (address != 0);

        result.insertBack("0x");
        result.insertBack(buffer[position .. $]);
    }
    else static if (isIntegral!(Args[0])) // Integer
    {
        char[21] buffer;
        result.insertBack(integral2String(args[0], buffer));
    }
    else
    {
        static assert(false);
    }
ParamEnd:

    return result;
}

@nogc pure unittest
{
    // Modifiers.
    assert(format!("{}")(8.5) == "8.5");
    assert(format!("{}")(8.6) == "8.6");
    assert(format!("{}")(1000) == "1000");
    assert(format!("{}")(1) == "1");
    assert(format!("{}")(10.25) == "10.25");
    assert(format!("{}")(1) == "1");
    assert(format!("{}")(0.01) == "0.01");

    // Integer size.
    assert(format!("{}")(10) == "10");
    assert(format!("{}")(10L) == "10");

    // String printing.
    assert(format!("{}")("Some weired string") == "Some weired string");
    assert(format!("{}")(cast(string) null) == "null");
    assert(format!("{}")('c') == "c");

    // Integer conversions.
    assert(format!("{}")(8) == "8");
    assert(format!("{}")(8) == "8");
    assert(format!("{}")(-8) == "-8");
    assert(format!("{}")(-8L) == "-8");
    assert(format!("{}")(8) == "8");
    assert(format!("{}")(100000001) == "100000001");
    assert(format!("{}")(99999999L) == "99999999");

    // Floating point conversions.
    assert(format!("{}")(0.1234) == "0.1234");
    assert(format!("{}")(0.3) == "0.3");
    assert(format!("{}")(0.333333333333) == "0.333333");
    assert(format!("{}")(38234.1234) == "38234.1");
    assert(format!("{}")(-0.3) == "-0.3");
    assert(format!("{}")(0.000000000000000006) == "6e-18");
    assert(format!("{}")(0.0) == "0");
    assert(format!("{}")(double.init) == "NaN");
    assert(format!("{}")(-double.init) == "-NaN");
    assert(format!("{}")(double.infinity) == "Inf");
    assert(format!("{}")(-double.infinity) == "-Inf");
    assert(format!("{}")(0.000000000000000000000000003) == "3e-27");
    assert(format!("{}")(0.23432e304) == "2.3432e+303");
    assert(format!("{}")(-0.23432e8) == "-2.3432e+07");
    assert(format!("{}")(1e-307) == "1e-307");
    assert(format!("{}")(1e+8) == "1e+08");
    assert(format!("{}")(111234.1) == "111234");
    assert(format!("{}")(0.999) == "0.999");
    assert(format!("{}")(0x1p-16382L) == "0");
    assert(format!("{}")(1e+3) == "1000");
    assert(format!("{}")(38234.1234) == "38234.1");

    // Pointer convesions
    assert(format!("{}")(cast(void*) 1) == "0x1");
    assert(format!("{}")(cast(void*) 20) == "0x14");
    assert(format!("{}")(cast(void*) null) == "0x0");
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
