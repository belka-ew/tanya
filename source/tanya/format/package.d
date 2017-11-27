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
import tanya.memory.op;
import tanya.meta.metafunction;
import tanya.meta.trait;
import tanya.range.array;

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

private static const char[201] digitpair =
    "0001020304050607080910111213141516171819202122232425262728293031323334353"
  ~ "6373839404142434445464748495051525354555657585960616263646566676869707172"
  ~ "737475767778798081828384858687888990919293949596979899";

private static const double[23] bottom = [
    1e+000, 1e+001, 1e+002, 1e+003, 1e+004, 1e+005, 1e+006, 1e+007, 1e+008,
    1e+009, 1e+010, 1e+011, 1e+012, 1e+013, 1e+014, 1e+015, 1e+016, 1e+017,
    1e+018, 1e+019, 1e+020, 1e+021, 1e+022,
];

private static const double[22] negativeBottom = [
    1e-001, 1e-002, 1e-003, 1e-004, 1e-005, 1e-006, 1e-007, 1e-008, 1e-009,
    1e-010, 1e-011, 1e-012, 1e-013, 1e-014, 1e-015, 1e-016, 1e-017, 1e-018,
    1e-019, 1e-020, 1e-021, 1e-022,
];

private static const double[13] top = [
    1e+023, 1e+046, 1e+069, 1e+092, 1e+115, 1e+138, 1e+161, 1e+184, 1e+207,
    1e+230, 1e+253, 1e+276, 1e+299,
];

private static const double[13] negativeTop = [
    1e-023, 1e-046, 1e-069, 1e-092, 1e-115, 1e-138, 1e-161, 1e-184, 1e-207,
    1e-230, 1e-253, 1e-276, 1e-299,
];

private static const double[13] topError = [
    8388608, 6.8601809640529717e+028, -7.253143638152921e+052,
    -4.3377296974619174e+075, -1.5559416129466825e+098,
    -3.2841562489204913e+121, -3.7745893248228135e+144,
    -1.7356668416969134e+167, -3.8893577551088374e+190,
    -9.9566444326005119e+213, 6.3641293062232429e+236,
    -5.2069140800249813e+259, -5.2504760255204387e+282,
];

private static const double[22] negativeBottomError = [
    -5.551115123125783e-018, -2.0816681711721684e-019,
    -2.0816681711721686e-020, -4.7921736023859299e-021,
    -8.1803053914031305e-022, 4.5251888174113741e-023,
    4.5251888174113739e-024, -2.0922560830128471e-025,
    -6.2281591457779853e-026, -3.6432197315497743e-027,
    6.0503030718060191e-028, 2.0113352370744385e-029, -3.0373745563400371e-030,
    1.1806906454401013e-032, -7.7705399876661076e-032, 2.0902213275965398e-033,
    -7.1542424054621921e-034, -7.1542424054621926e-035,
    2.4754073164739869e-036, 5.4846728545790429e-037, 9.2462547772103625e-038,
    -4.8596774326570872e-039,
];

private static const double[13] negativeTopError = [
    3.9565301985100693e-040, -2.299904345391321e-063, 3.6506201437945798e-086,
    1.1875228833981544e-109, -5.0644902316928607e-132,
    -6.7156837247865426e-155, -2.812077463003139e-178,
    -5.7778912386589953e-201, 7.4997100559334532e-224,
    -4.6439668915134491e-247, -6.3691100762962136e-270,
    -9.436808465446358e-293, // 8.0970921678014997e-317,
];

private enum ulong tenTo19th = 1000000000000000000UL;

private void ddmultlo(A, B, C, D, E, F)(ref A oh,
                                        ref B ol,
                                        ref C xh,
                                        ref D xl,
                                        ref E yh,
                                        ref F yl)
{
    ol = ol + (xh * yl + xl * yh);
}

private void ddmultlos(A, B, C, D)(ref A oh, ref B ol, ref C xh, ref D yl)
{
    ol = ol + (xh * yl);
}

private void ddrenorm(T, U)(ref T oh, ref U ol)
{
    double s;
    s = oh + ol;
    ol = ol - (s - oh);
    oh = s;
}

// Power can be -323 to +350.
private void raise2Power10(double* ohi,
                           double* olo,
                           double d,
                           int power) @nogc nothrow pure
{
    double ph, pl;
    if ((power >= 0) && (power <= 22))
    {
        ddmulthi(ph, pl, d, bottom[power]);
    }
    else
    {
        int e, et, eb;
        double p2h, p2l;

        e = power;
        if (power < 0)
        {
            e = -e;
        }
        et = (e * 0x2c9) >> 14; /* %23 */
        if (et > 13)
        {
            et = 13;
        }
        eb = e - (et * 23);

        ph = d;
        pl = 0.0;
        if (power < 0)
        {
            if (eb)
            {
                --eb;
                ddmulthi(ph, pl, d, negativeBottom[eb]);
                ddmultlos(ph, pl, d, negativeBottomError[eb]);
            }
            if (et)
            {
                ddrenorm(ph, pl);
                --et;
                ddmulthi(p2h, p2l, ph, negativeTop[et]);
                ddmultlo(p2h,
                         p2l,
                         ph,
                         pl,
                         negativeTop[et],
                         negativeTopError[et]);
                ph = p2h;
                pl = p2l;
            }
        }
        else
        {
            if (eb)
            {
                e = eb;
                if (eb > 22)
                {
                    eb = 22;
                }
                e -= eb;
                ddmulthi(ph, pl, d, bottom[eb]);
                if (e)
                {
                    ddrenorm(ph, pl);
                    ddmulthi(p2h, p2l, ph, bottom[e]);
                    ddmultlos(p2h, p2l, bottom[e], pl);
                    ph = p2h;
                    pl = p2l;
                }
            }
            if (et)
            {
                ddrenorm(ph, pl);
                --et;
                ddmulthi(p2h, p2l, ph, top[et]);
                ddmultlo(p2h, p2l, ph, pl, top[et], topError[et]);
                ph = p2h;
                pl = p2l;
            }
        }
    }
    ddrenorm(ph, pl);
    *ohi = ph;
    *olo = pl;
}

/*
 * Given a float value, returns the significant bits in bits, and the position
 * of the decimal point in decimalPos. +/-Inf and NaN are specified by special
 * values returned in the decimalPos parameter.
 * fracDigits is absolute normally, but if you want from first significant
 * digits (got %g), or in 0x80000000
 */
private int real2String(ref const(char)* start,
                        ref uint len,
                        char* out_,
                        out int decimalPos,
                        double value,
                        uint fracDigits) @nogc nothrow pure
{
    long bits = 0;
    int e, tens;

    double d = value;
    copyFp(bits, d);
    auto exponent = cast(int) ((bits >> 52) & 2047);
    auto ng = cast(int) (bits >> 63);
    if (ng)
    {
        d = -d;
    }

    if (exponent == 2047) // Is NaN or inf?
    {
        start = (bits & (((cast(ulong) 1) << 52) - 1)) ? "NaN" : "Inf";
        decimalPos = special;
        len = 3;
        return ng;
    }

    if (exponent == 0) // Is zero or denormal?
    {
        if ((bits << 1) == 0) // Do zero.
        {
            decimalPos = 1;
            start = out_;
            out_[0] = '0';
            len = 1;
            return ng;
        }
        // Find the right exponent for denormals.
        {
            long v = (cast(ulong) 1) << 51;
            while ((bits & v) == 0)
            {
                --exponent;
                v >>= 1;
            }
        }
    }

    // Find the decimal exponent as well as the decimal bits of the value.
    {
        double ph, pl;

        // log10 estimate - very specifically tweaked to hit or undershoot by
        // no more than 1 of log10 of all exponents 1..2046.
        tens = exponent - 1023;
        if (tens < 0)
        {
            tens = (tens * 617) / 2048;
        }
        else
        {
            tens = ((tens * 1233) / 4096) + 1;
        }

        // Move the significant bits into position and stick them into an int.
        raise2Power10(&ph, &pl, d, 18 - tens);

        // Get full as much precision from double-double as possible.
        bits = cast(long) ph;
        double vh = cast(double) bits;
        double ahi = (ph - vh);
        double t = (ahi - ph);
        double alo = (ph - (ahi - t)) - (vh + t);
        bits += cast(long) (ahi + alo + pl);

        // Check if we undershot.
        if ((cast(ulong) bits) >= tenTo19th)
        {
            ++tens;
        }
    }

    // Now do the rounding in integer land.
    if (fracDigits & 0x80000000)
    {
        fracDigits =  (fracDigits & 0x7ffffff) + 1;
    }
    else
    {
        fracDigits = tens + fracDigits;
    }
    if ((fracDigits < 24))
    {
        uint dg = 1;
        if (cast(ulong) bits >= powersOf10[9])
        {
            dg = 10;
        }
        while (cast(ulong) bits >= powersOf10[dg])
        {
            ++dg;
            if (dg == 20)
            {
                goto noround;
            }
        }
        if (fracDigits < dg)
        {
            // Add 0.5 at the right position and round.
            e = dg - fracDigits;
            if (cast(uint) e >= 24)
            {
                goto noround;
            }
            ulong r = powersOf10[e];
            bits = bits + (r / 2);
            if (cast(ulong) bits >= powersOf10[dg])
            {
                ++tens;
            }
            bits /= r;
        }
    noround:
    }

    // Kill long trailing runs of zeros.
    if (bits)
    {
        uint n;
        for (;;)
        {
            if (bits <= 0xffffffff)
            {
                break;
            }
            if (bits % 1000)
            {
                goto donez;
            }
            bits /= 1000;
        }
        n = cast(uint) bits;
        while ((n % 1000) == 0)
        {
            n /= 1000;
        }
        bits = n;
    donez:
    }

    // Convert to string.
    out_ += 64;
    e = 0;
    for (;;)
    {
        uint n;
        char *o = out_ - 8;
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
            out_ -= 2;
            *cast(ushort*) out_ = *cast(ushort*) &digitpair[(n % 100) * 2];
            n /= 100;
            e += 2;
        }
        if (bits == 0)
        {
            if ((e) && (out_[0] == '0'))
            {
                ++out_;
                --e;
            }
            break;
        }
        while (out_ != o)
        {
            *--out_ = '0';
            ++e;
        }
    }

    decimalPos = tens;
    start = out_;
    len = e;
    return ng;
}

private void leadSign(bool negative, ref char[8] sign)
@nogc nothrow pure
{
    sign[0] = 0;
    if (negative)
    {
        sign[0] = 1;
        sign[1] = '-';
    }
}

// Copies d to bits w/ strict aliasing (this compiles to nothing on /Ox).
private void copyFp(T, U)(ref T dest, ref U src)
{
    for (int count = 0; count < 8; ++count)
    {
        (cast(char*) &dest)[count] = (cast(char*) &src)[count];
    }
}

private void ddmulthi(ref double oh,
                      ref double ol,
                      ref double xh,
                      const ref double yh) @nogc nothrow pure
{
    double ahi, bhi;
    long bt;
    oh = xh * yh;
    copyFp(bt, xh);
    bt &= ((~cast(ulong) 0) << 27);
    copyFp(ahi, bt);
    double alo = xh - ahi;
    copyFp(bt, yh);
    bt &= ((~cast(ulong) 0) << 27);
    copyFp(bhi, bt);
    double blo = yh - bhi;
    ol = ((ahi * bhi - oh) + ahi * blo + alo * bhi) + alo * blo;
}

package(tanya) String format(string fmt, Args...)(char[] buf, Args args)
{
    String result;
    char* bf = buf.ptr;

    // Ok, we have a percent, read the modifiers first.
    int precision = -1;
    int tz = 0;
    bool negative;

    // Handle each replacement.
    char[512] num; // Big enough for e308 (with commas) or e-307.
    char[8] lead;
    char[8] tail;
    char *s;
    uint l, n;
    ulong n64;

    double fv;

    int decimalPos;
    const(char)* sn;

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
        fv = args[0];
        if (precision == -1)
        {
            precision = 6;
        }
        else if (precision == 0)
        {
            precision = 1; // Default is 6.
        }
        // Read the double into a string.
        if (real2String(sn,
                        l,
                        num.ptr,
                        decimalPos,
                        fv,
                        (precision - 1) | 0x80000000))
        {
            negative = true;
        }

        // Clamp the precision and delete extra zeros after clamp.
        n = precision;
        if (l > cast(uint) precision)
        {
            l = precision;
        }
        while ((l > 1) && (precision) && (sn[l - 1] == '0'))
        {
            --precision;
            --l;
        }

        // Should we use %e.
        if ((decimalPos <= -4) || (decimalPos > cast(int) n))
        {
            if (precision > cast(int) l)
            {
                precision = l - 1;
            }
            else if (precision)
            {
               // When using %e, there is one digit before the decimal.
               --precision;
            }
            goto doexpfromg;
        }
        // This is the insane action to get the pr to match %g sematics
        // for %f
        if (decimalPos > 0)
        {
            precision = (decimalPos < cast(int) l) ? l - decimalPos : 0;
        }
        else
        {
            if (precision > cast(int) l)
            {
                precision = -decimalPos + l;
            }
            else
            {
                precision = -decimalPos + precision;
            }
        }
        goto dofloatfromg;

    doexpfromg:
        tail[0] = 0;
        leadSign(negative, lead);
        if (decimalPos == special)
        {
            s = cast(char*) sn;
            precision = 0;
            goto scopy;
        }
        s = num.ptr + 64;
        // Handle leading chars.
        *s++ = sn[0];

        if (precision)
        {
            *s++ = period;
        }

        // Handle after decimal.
        if ((l - 1) > cast(uint) precision)
        {
            l = precision + 1;
        }
        for (n = 1; n < l; n++)
        {
            *s++ = sn[n];
        }
        // Trailing zeros.
        tz = precision - (l - 1);
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
        for (;;)
        {
            tail[n] = '0' + decimalPos % 10;
            if (n <= 3)
            {
                break;
            }
            --n;
            decimalPos /= 10;
        }
        goto flt_lead;

    dofloatfromg:
        tail[0] = 0;
        leadSign(negative, lead);
        if (decimalPos == special)
        {
            s = cast(char*) sn;
            precision = 0;
            goto scopy;
        }
        s = num.ptr + 64;

        // Handle the three decimal varieties.
        if (decimalPos <= 0)
        {
            // Handle 0.000*000xxxx.
            *s++ = '0';
            if (precision)
            {
                *s++ = period;
            }
            n = -decimalPos;
            if (cast(int) n > precision)
            {
                n = precision;
            }
            int i = n;
            while (i)
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
            while (i)
            {
                *s++ = '0';
                --i;
            }
            if (cast(int) (l + n) > precision)
            {
                l = precision - n;
            }
            i = l;
            while (i)
            {
                *s++ = *sn++;
                --i;
            }
            tz = precision - (n + l);
        }
        else
        {
            if (cast(uint) decimalPos >= l)
            {
                // Handle xxxx000*000.0.
                n = 0;
                for (;;)
                {
                    *s++ = sn[n];
                    ++n;
                    if (n >= l)
                    {
                        break;
                    }
                }
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
                if (precision)
                {
                    *s++ = period;
                    tz = precision;
                }
            }
            else
            {
                // Handle xxxxx.xxxx000*000.
                n = 0;
                for (;;)
                {
                    *s++ = sn[n];
                    ++n;
                    if (n >= cast(uint) decimalPos)
                    {
                        break;
                    }
                }
                if (precision)
                {
                    *s++ = period;
                }
                if ((l - decimalPos) > cast(uint) precision)
                {
                    l = precision + decimalPos;
                }
                while (n < l)
                {
                    *s++ = sn[n];
                    ++n;
                }
                tz = precision - (l - decimalPos);
            }
        }
        precision = 0;

    flt_lead:
        // Get the length that we copied.
        l = cast(uint) (s - (num.ptr + 64));
        s = num.ptr + 64;
    }
    else static if (isPointer!(Args[0])) // Pointer
    {
        // Get the number.
        n64 = cast(size_t) args[0];
        size_t position = num.length;

        do // Write at least "0" if the pointer is null.
        {
            num[--position] = lowerHexDigits[cast(size_t) (n64 & 15)];
            n64 >>= 4;
        }
        while (n64 != 0);

        result.insertBack("0x");
        result.insertBack(num[position .. $]);
    }
    else static if (isIntegral!(Args[0])) // Integer
    {
        // Get the integer and abs it.
        static if (Args[0].sizeof == 8)
        {
            long k64 = args[0];
            n64 = cast(ulong) k64;
            static if (isSigned!(Args[0]))
            {
                if (k64 < 0)
                {
                    n64 = cast(ulong) -k64;
                    negative = true;
                }
            }
        }
        else
        {
            int k = args[0];
            n64 = cast(uint) k;
            static if (isSigned!(Args[0]))
            {
                if (k < 0)
                {
                    n64 = cast(uint) -k;
                    negative = true;
                }
            }
        }

        // Convert to string.
        s = num.ptr + num.length;
        l = 0;

        for (;;)
        {
            // Do in 32-bit chunks (avoid lots of 64-bit divides even
            // with constant denominators).
            char *o = s - 8;
            if (n64 >= 100000000)
            {
                n = cast(uint) (n64 % 100000000);
                n64 /= 100000000;
            }
            else
            {
                n = cast(uint) n64;
                n64 = 0;
            }
            while (n)
            {
                s -= 2;
                *cast(ushort*) s = *cast(ushort*) &digitpair[(n % 100) * 2];
                n /= 100;
            }
            while (n)
            {
                *--s = cast(char) (n % 10) + '0';
                n /= 10;
            }
            if (n64 == 0)
            {
                if ((s[0] == '0') && (s != (num.ptr + num.length)))
                {
                    ++s;
                }
                break;
            }
            while (s != o)
            {
                *--s = '0';
            }
        }

        tail[0] = 0;
        leadSign(negative, lead);

        // Get the length that we copied.
        l = cast(uint) ((num.ptr + num.length) - s);
        if (l == 0)
        {
            *--s = '0';
            l = 1;
        }
        if (precision < 0)
        {
            precision = 0;
        }
    }
    else
    {
        static assert(false);
    }

    if (result.length > 0)
    {
        return result;
    }
scopy:
    // Get fw=leading/trailing space, precision=leading zeros.
    if (precision < cast(int) l)
    {
        precision = l;
    }
    n = precision + lead[0] + tail[0] + tz;
    precision -= l;

    // Copy the spaces and/or zeros.
    if (precision)
    {
        int i;

        // copy leader
        sn = lead.ptr + 1;
        while (lead[0])
        {
            i = lead[0];
            lead[0] -= cast(char) i;
            while (i)
            {
                *bf++ = *sn++;
                --i;
            }
        }

        // Copy leading zeros.
        while (precision > 0)
        {
            i = precision;
            precision -= i;
            while (i)
            {
                if (((cast(size_t) bf) & 3) == 0)
                {
                    break;
                }
                *bf++ = '0';
                --i;
            }
            while (i >= 4)
            {
                *cast(uint*) bf = 0x30303030;
                bf += 4;
                i -= 4;
            }
            while (i)
            {
                *bf++ = '0';
                --i;
            }
        }
    }

    // copy leader if there is still one
    sn = lead.ptr + 1;
    while (lead[0])
    {
        int i = lead[0];
        lead[0] -= cast(char) i;
        while (i)
        {
            *bf++ = *sn++;
            --i;
        }
    }

    // Copy the string.
    n = l;
    while (n)
    {
        int i = n;
        n -= i;

        while (i)
        {
            *bf++ = *s++;
            --i;
        }
    }

    // Copy trailing zeros.
    while (tz)
    {
        int i = tz;
        tz -= i;
        while (i)
        {
            if (((cast(size_t) bf) & 3) == 0)
            {
                break;
            }
            *bf++ = '0';
            --i;
        }
        while (i >= 4)
        {
            *cast(uint*) bf = 0x30303030;
            bf += 4;
            i -= 4;
        }
        while (i)
        {
            *bf++ = '0';
            --i;
        }
    }

    // copy tail if there is one
    sn = tail.ptr + 1;
    while (tail[0])
    {
        int i = tail[0];
        tail[0] -= cast(char) i;
        while (i)
        {
            *bf++ = *sn++;
            --i;
        }
    }

    *bf = 0;
    result = String(buf[0 .. cast(int) (bf - buf.ptr)]);
    return result;
}

@nogc pure unittest
{
    char[318] buffer;

    // Modifiers.
    assert(format!("{}")(buffer, 8.5) == "8.5");
    assert(format!("{}")(buffer, 8.6) == "8.6");
    assert(format!("{}")(buffer, 1000) == "1000");
    assert(format!("{}")(buffer, 1) == "1");
    assert(format!("{}")(buffer, 10.25) == "10.25");
    assert(format!("{}")(buffer, 1) == "1");
    assert(format!("{}")(buffer, 0.01) == "0.01");

    // Integer size.
    assert(format!("{}")(buffer, 10) == "10");
    assert(format!("{}")(buffer, 10L) == "10");

    // String printing.
    assert(format!("{}")(buffer, "Some weired string") == "Some weired string");
    assert(format!("{}")(buffer, cast(string) null) == "null");
    assert(format!("{}")(buffer, 'c') == "c");

    // Integer conversions.
    assert(format!("{}")(buffer, 8) == "8");
    assert(format!("{}")(buffer, 8) == "8");
    assert(format!("{}")(buffer, -8) == "-8");
    assert(format!("{}")(buffer, -8L) == "-8");
    assert(format!("{}")(buffer, 8) == "8");
    assert(format!("{}")(buffer, 100000001) == "100000001");
    assert(format!("{}")(buffer, 99999999L) == "99999999");

    // Floating point conversions.
    assert(format!("{}")(buffer, 0.1234) == "0.1234");
    assert(format!("{}")(buffer, 0.3) == "0.3");
    assert(format!("{}")(buffer, 0.333333333333) == "0.333333");
    assert(format!("{}")(buffer, 38234.1234) == "38234.1");
    assert(format!("{}")(buffer, -0.3) == "-0.3");
    assert(format!("{}")(buffer, 0.000000000000000006) == "6e-18");
    assert(format!("{}")(buffer, 0.0) == "0");
    assert(format!("{}")(buffer, double.init) == "NaN");
    assert(format!("{}")(buffer, -double.init) == "-NaN");
    assert(format!("{}")(buffer, double.infinity) == "Inf");
    assert(format!("{}")(buffer, -double.infinity) == "-Inf");
    assert(format!("{}")(buffer, 0.000000000000000000000000003) == "3e-27");
    assert(format!("{}")(buffer, 0.23432e304) == "2.3432e+303");
    assert(format!("{}")(buffer, -0.23432e8) == "-2.3432e+07");
    assert(format!("{}")(buffer, 1e-307) == "1e-307");
    assert(format!("{}")(buffer, 1e+8) == "1e+08");
    assert(format!("{}")(buffer, 111234.1) == "111234");
    assert(format!("{}")(buffer, 0.999) == "0.999");
    assert(format!("{}")(buffer, 0x1p-16382L) == "0");
    assert(format!("{}")(buffer, 1e+3) == "1000");
    assert(format!("{}")(buffer, 38234.1234) == "38234.1");

    // Pointer convesions.
    assert(format!("{}")(buffer, cast(void*) 1) == "0x1");
    assert(format!("{}")(buffer, cast(void*) 20) == "0x14");
    assert(format!("{}")(buffer, cast(void*) null) == "0x0");
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
