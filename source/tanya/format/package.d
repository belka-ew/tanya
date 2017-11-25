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

import core.stdc.stdarg;
public import tanya.format.conv;
import tanya.memory.op;
import tanya.meta.metafunction;
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

package static const string hex = "0123456789abcdefxp";

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
                           int power) pure nothrow @nogc
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
 * digits (got %g and %e), or in 0x80000000
 */
private int real2String(ref const(char)* start,
                        ref uint len,
                        char* out_,
                        out int decimalPos,
                        double value,
                        uint fracDigits) pure nothrow @nogc
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

private void leadSign(uint fl, char* sign)
pure nothrow @nogc
{
    sign[0] = 0;
    if (fl & Modifier.negative)
    {
        sign[0] = 1;
        sign[1] = '-';
    }
}

private enum Modifier : uint
{
    intMax = 32,
    negative = 128,
    halfWidth = 512,
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
                      const ref double yh) pure nothrow @nogc
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

/*
 * Get float info.
 *
 * Returns: Sign bit.
 */
private int real2Parts(long* bits, out int exponent, const double value)
pure nothrow @nogc
{
    long b;

    // Load value and round at the fracDigits.
    double d = value;

    copyFp(b, d);

    *bits = b & (((cast(ulong) 1) << 52) - 1);
    // 1023 is the exponent bias, calculated as 2^(k - 1) - 1, where k is the
    // number of bits used to represent the exponent, 11 bit for double.
    exponent = cast(int) (((b >> 52) & 0x7ff) - 1023);

    return cast(int) (b >> 63);
}

private char[] vsprintf(string fmt)(return char[] buf, va_list va)
pure nothrow @nogc
{
    char* bf = buf.ptr;
    string f = fmt;
    int tlen;

    FmtLoop: while (true)
    {
        // Fast copy everything up to the next % (or end of string).
        while ((cast(size_t) f.ptr) & 3)
        {
        schk:
            if (f.length == 0)
            {
                break FmtLoop;
            }
            if (f[0] == '%')
            {
                goto scandd;
            }

            *bf++ = f[0];
            f.popFront();
        }
        while (true)
        {
            // Check if the next 4 bytes contain %(0x25) or end of string.
            // Using the 'hasless' trick:
            // https://graphics.stanford.edu/~seander/bithacks.html#HasLessInWord
            uint v = *cast(uint*) f;
            uint c = (~v) & 0x80808080;
            if ((((v ^ 0x25252525) - 0x01010101) & c) || f.length <= 3)
            {
                goto schk;
            }

            *cast(uint*) bf = v;
            bf += 4;
            f = f[4 .. $];
        }
    scandd:

        f.popFront();

        // Ok, we have a percent, read the modifiers first.
        int fw = 0;
        int precision = -1;
        int tz = 0;
        uint fl = 0;

        // Get the field width.
        if (f[0] == '*')
        {
            fw = va_arg!uint(va);
            f.popFront();
        }
        else
        {
            while ((f[0] >= '0') && (f[0] <= '9'))
            {
                fw = fw * 10 + f[0] - '0';
                f.popFront();
            }
        }
        // Get the precision.
        if (f[0] == '.')
        {
            f.popFront();
            if (f[0] == '*')
            {
                precision = va_arg!uint(va);
                f.popFront();
            }
            else
            {
                precision = 0;
                while ((f[0] >= '0') && (f[0] <= '9'))
                {
                    precision = precision * 10 + f[0] - '0';
                    f.popFront();
                }
            }
        }

        // Handle integer size overrides.
        switch (f[0])
        {
            // are we halfwidth?
            case 'h':
                fl |= Modifier.halfWidth;
                f.popFront();
                break;
            // are we 64-bit?
            case 'l':
                fl |= Modifier.intMax;
                f.popFront();
                break;
            default:
                break;
        }

        // Handle each replacement.
        enum NUMSZ = 512; // Big enough for e308 (with commas) or e-307.
        char[NUMSZ] num;
        char[8] lead;
        char[8] tail;
        char *s;
        uint l, n;
        ulong n64;

        double fv;

        int decimalPos;
        const(char)* sn;

        switch (f[0])
        {
            case 's':
                // Get the string.
                s = va_arg!(char[])(va).ptr;
                if (s is null)
                {
                    s = cast(char*) "null";
                }
                // Get the length.
                sn = s;
                for (;;)
                {
                    if (((cast(size_t) sn) & 3) == 0)
                    {
                        break;
                    }
                lchk:
                    if (sn[0] == 0)
                    {
                        goto ld;
                    }
                    ++sn;
                }
                n = 0xffffffff;
                if (precision >= 0)
                {
                    n = cast(uint) (sn - s);
                    if (n >= cast(uint) precision)
                    {
                        goto ld;
                    }
                    n = (cast(uint) (precision - n)) >> 2;
                }
                while (n)
                {
                    uint v = *cast(uint*) sn;
                    if ((v - 0x01010101) & (~v) & 0x80808080UL)
                    {
                        goto lchk;
                    }
                    sn += 4;
                    --n;
                }
                goto lchk;
            ld:

                l = cast(uint) (sn - s);
                // Clamp to precision.
                if (l > cast(uint) precision)
                {
                    l = precision;
                }
                lead[0] = 0;
                tail[0] = 0;
                precision = 0;
                decimalPos = 0;
                // Copy the string in.
                goto scopy;

            case 'c': // Char.
                // Get the character.
                s = num.ptr + NUMSZ - 1;
                *s = cast(char) va_arg!int(va);
                l = 1;
                lead[0] = 0;
                tail[0] = 0;
                precision = 0;
                decimalPos = 0;
                goto scopy;

            case 'g': // Float.
                fv = va_arg!double(va);
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
                    fl |= Modifier.negative;
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

            case 'e': // Float.
                fv = va_arg!double(va);
                if (precision == -1)
                {
                    precision = 6; // Default is 6.
                }
                // read the double into a string
                if (real2String(sn,
                                l,
                                num.ptr,
                                decimalPos,
                                fv,
                                precision | 0x80000000))
                {
                    fl |= Modifier.negative;
                }
            doexpfromg:
                tail[0] = 0;
                leadSign(fl, lead.ptr);
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
                tail[1] = hex[0xe];
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

            case 'f': // Float.
                fv = va_arg!double(va);
            doafloat:
                if (precision == -1)
                {
                    precision = 6; // Default is 6.
                }
                // Read the double into a string.
                if (real2String(sn, l, num.ptr, decimalPos, fv, precision))
                {
                    fl |= Modifier.negative;
                }
            dofloatfromg:
                tail[0] = 0;
                leadSign(fl, lead.ptr);
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
                goto scopy;

            case 'p': // Pointer
                static if (size_t.sizeof == 8)
                {
                    fl |= Modifier.intMax;
                }

                l = (4 << 4) | (4 << 8);
                lead[0] = 2;
                lead[1] = '0';
                lead[2] = 'x';
            radixnum:
                // Get the number.
                if (fl & Modifier.intMax)
                {
                    n64 = va_arg!ulong(va);
                }
                else
                {
                    n64 = va_arg!uint(va);
                }

                s = num.ptr + NUMSZ;
                decimalPos = 0;
                // Clear tail, and clear leading if value is zero.
                tail[0] = 0;
                if (n64 == 0)
                {
                    lead[0] = 0;
                    if (precision == 0)
                    {
                        l = 0;
                        goto scopy;
                    }
                }
                // Convert to string.
                for (;;)
                {
                    *--s = hex[cast(size_t) (n64 & ((1 << (l >> 8)) - 1))];
                    n64 >>= (l >> 8);
                    if (!((n64) || (cast(int) ((num.ptr + NUMSZ) - s) < precision)))
                    {
                        break;
                    }
                }
                // Get the length that we copied.
                l = cast(uint)((num.ptr + NUMSZ) - s);
                // Copy it.
                goto scopy;

            case 'u': // Unsigned.
            case 'i': // Signed.
                // Get the integer and abs it.
                if (fl & Modifier.intMax)
                {
                    long i64 = va_arg!long(va);
                    n64 = cast(ulong) i64;
                    if ((f[0] != 'u') && (i64 < 0))
                    {
                        n64 = cast(ulong) -i64;
                        fl |= Modifier.negative;
                    }
                }
                else
                {
                    int i = va_arg!int(va);
                    n64 = cast(uint) i;
                    if ((f[0] != 'u') && (i < 0))
                    {
                        n64 = cast(uint) -i;
                        fl |= Modifier.negative;
                    }
                }

                // Convert to string.
                s = num.ptr + NUMSZ;
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
                        if ((s[0] == '0') && (s != (num.ptr + NUMSZ)))
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
                leadSign(fl, lead.ptr);

                // Get the length that we copied.
                l = cast(uint) ((num.ptr + NUMSZ) - s);
                if (l == 0)
                {
                    *--s = '0';
                    l = 1;
                }
                if (precision < 0)
                {
                    precision = 0;
                }

            scopy:
                // Get fw=leading/trailing space, precision=leading zeros.
                if (precision < cast(int) l)
                {
                    precision = l;
                }
                n = precision + lead[0] + tail[0] + tz;
                if (fw < cast(int) n)
                {
                    fw = n;
                }
                fw -= n;
                precision -= l;

                // Copy the spaces and/or zeros.
                if (fw + precision)
                {
                    int i;

                    // copy leading spaces (or when doing %8.4d stuff)
                    while (fw > 0)
                    {
                        i = fw;
                        fw -= i;
                        while (i)
                        {
                            if (((cast(size_t) bf) & 3) == 0)
                            {
                                break;
                            }
                            *bf++ = ' ';
                            --i;
                        }
                        while (i >= 4)
                        {
                            *cast(uint*) bf = 0x20202020;
                            bf += 4;
                            i -= 4;
                        }
                        while (i)
                        {
                            *bf++ = ' ';
                            --i;
                        }
                    }

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
                break;

            default: // Unknown, just copy code.
                s = num.ptr + NUMSZ - 1;
                *s = f[0];
                l = 1;
                fw = precision = fl = 0;
                lead[0] = 0;
                tail[0] = 0;
                precision = 0;
                decimalPos = 0;
                goto scopy;
        }
        f.popFront();
    }

    *bf = 0;
    return buf[0 .. tlen + cast(int) (bf - buf.ptr)];
}

char[] format(string fmt)(return char[] buf, ...)
nothrow
{
    va_list va;
    va_start(va, buf);
    auto result = vsprintf!fmt(buf, va);
    va_end(va);
    return result;
}

nothrow unittest
{
    char[318] buffer;

    // Format without arguments.
    assert(format!""(buffer) == "");
    assert(format!"asdfqweryxcvz"(buffer) == "asdfqweryxcvz");

    // Modifiers.
    assert(format!"%g"(buffer, 8.5) == "8.5");
    assert(format!"%5g"(buffer, 8.6) == "  8.6");
    assert(format!"%i"(buffer, 1000) == "1000");
    assert(format!"%*i"(buffer, 5, 1) == "    1");
    assert(format!"%.1f"(buffer, 10.25) == "10.3");
    assert(format!"%.*f"(buffer, 1, 10.25) == "10.3");
    assert(format!"%i"(buffer, 1) == "1");
    assert(format!"%7.3g"(buffer, 0.01) == "   0.01");

    // Integer size.
    assert(format!"%hi"(buffer, 10) == "10");
    assert(format!"%li"(buffer, 10) == "10");
    assert(format!"%li"(buffer, 10L) == "10");

    // String printing.
    assert(format!"%s"(buffer, "Some weired string") == "Some weired string");
    assert(format!"%s"(buffer, cast(string) null) == "null");
    assert(format!"%.4s"(buffer, "Some weired string") == "Some");
    assert(format!"%c"(buffer, 'c') == "c");

    // Integer conversions.
    assert(format!"%i"(buffer, 8) == "8");
    assert(format!"%i"(buffer, 8) == "8");
    assert(format!"%i"(buffer, -8) == "-8");
    assert(format!"%li"(buffer, -8L) == "-8");
    assert(format!"%u"(buffer, 8) == "8");
    assert(format!"%i"(buffer, 100000001) == "100000001");
    assert(format!"%.12i"(buffer, 99999999L) == "000099999999");
    assert(format!"%i"(buffer, 100000001) == "100000001");

    // Floating point conversions.
    assert(format!"%g"(buffer, 0.1234) == "0.1234");
    assert(format!"%g"(buffer, 0.3) == "0.3");
    assert(format!"%g"(buffer, 0.333333333333) == "0.333333");
    assert(format!"%g"(buffer, 38234.1234) == "38234.1");
    assert(format!"%g"(buffer, -0.3) == "-0.3");
    assert(format!"%g"(buffer, 0.000000000000000006) == "6e-18");
    assert(format!"%g"(buffer, 0.0) == "0");
    assert(format!"%f"(buffer, 0.0) == "0.000000");
    assert(format!"%f"(buffer, double.init) == "NaN");
    assert(format!"%f"(buffer, double.infinity) == "Inf");
    assert(format!"%.0g"(buffer, 0.0) == "0");
    assert(format!"%f"(buffer, 0.000000000000000000000000003) == "0.000000");
    assert(format!"%g"(buffer, 0.23432e304) == "2.3432e+303");
    assert(format!"%f"(buffer, -0.23432e8) == "-23432000.000000");
    assert(format!"%e"(buffer, double.init) == "NaN");
    assert(format!"%f"(buffer, 1e-307) == "0.000000");
    assert(format!"%f"(buffer, 1e+8) == "100000000.000000");
    assert(format!"%05g"(buffer, 111234.1) == "111234");
    assert(format!"%.2g"(buffer, double.init) == "Na");
    assert(format!"%.1e"(buffer, 0.999) == "1.0e+00");
    assert(format!"%.0f"(buffer, 0.999) == "1");
    assert(format!"%.9f"(buffer, 1e-307) == "0.000000000");
    assert(format!"%g"(buffer, 0x1p-16382L)); // "6.95336e-310"
    assert(format!"%f"(buffer, 1e+3) == "1000.000000");
    assert(format!"%g"(buffer, 38234.1234) == "38234.1");

    // Pointer conversions.
    assert(format!"%p"(buffer, cast(void*) 1) == "0x1");
    assert(format!"%p"(buffer, cast(void*) 20) == "0x14");

    // Unknown specifier.
    assert(format!"%k"(buffer) == "k");
    assert(format!"%%k"(buffer) == "%k");
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
