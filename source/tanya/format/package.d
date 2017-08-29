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

public import tanya.format.conv;
import core.stdc.stdarg;

private enum special = 0x7000;
private enum char comma = ',';
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
    double d;
    long bits = 0;
    int expo, e, ng, tens;

    d = value;
    copyFp(bits, d);
    expo = cast(int) ((bits >> 52) & 2047);
    ng = cast(int) (bits >> 63);
    if (ng)
    {
        d = -d;
    }

    if (expo == 2047) // Is nan or inf?
    {
        start = (bits & (((cast(ulong) 1) << 52) - 1)) ? "NaN" : "Inf";
        decimalPos = special;
        len = 3;
        return ng;
    }

    if (expo == 0) // Is zero or denormal.
    {
        if ((bits << 1) == 0) // Do zero.
        {
            decimalPos = 1;
            start = out_;
            out_[0] = '0';
            len = 1;
            return ng;
        }
        // Find the right expo for denormals.
        {
            long v = (cast(ulong) 1) << 51;
            while ((bits & v) == 0)
            {
                --expo;
                v >>= 1;
            }
        }
    }

    // Find the decimal exponent as well as the decimal bits of the value.
    {
        double ph, pl;

        // log10 estimate - very specifically tweaked to hit or undershoot by
        // no more than 1 of log10 of all expos 1..2046
        tens = expo - 1023;
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

        void ddtoS64(A, B, C)(ref A ob, ref B xh, ref C xl)
        {
            double ahi = 0, alo, vh, t;
            ob = cast(long) ph;
            vh = cast(double) ob;
            ahi = (xh - vh);
            t = (ahi - xh);
            alo = (xh - (ahi - t)) - (vh + t);
            ob += cast(long) (ahi + alo + xl);
        }

        // Get full as much precision from double-double as possible.
        ddtoS64(bits, ph, pl);

        // check if we undershot
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
            ulong r;
            // Add 0.5 at the right position and round.
            e = dg - fracDigits;
            if (cast(uint) e >= 24)
            {
                goto noround;
            }
            r = powersOf10[e];
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
    else if (fl & Modifier.leadingSpace)
    {
        sign[0] = 1;
        sign[1] = ' ';
    }
    else if (fl & Modifier.leadingPlus)
    {
        sign[0] = 1;
        sign[1] = '+';
    }
}

private enum Modifier : uint
{
    leftJust = 1,
    leadingPlus = 2,
    leadingSpace = 4,
    leading0x = 8,
    leadingZero = 16,
    intMax = 32,
    tripletComma = 64,
    negative = 128,
    metricSuffix = 256,
    halfWidth = 512,
    metricNoSpace = 1024,
    metric1024 = 2048,
    metricJedec = 4096,
}

// Copies d to bits w/ strict aliasing (this compiles to nothing on /Ox).
private void copyFp(T, U)(ref T dest, ref U src)
{
    int cn;
    for (cn = 0; cn < 8; ++cn)
    {
        (cast(char*) &dest)[cn] = (cast(char *) &src)[cn];
    }
}

private void ddmulthi(ref double oh,
                      ref double ol,
                      ref double xh,
                      const ref double yh) pure nothrow @nogc
{
    double ahi = 0, alo, bhi = 0, blo;
    long bt;
    oh = xh * yh;
    copyFp(bt, xh);
    bt &= ((~cast(ulong) 0) << 27);
    copyFp(ahi, bt);
    alo = xh - ahi;
    copyFp(bt, yh);
    bt &= ((~cast(ulong) 0) << 27);
    copyFp(bhi, bt);
    blo = yh - bhi;
    ol = ((ahi * bhi - oh) + ahi * blo + alo * bhi) + alo * blo;
}

// get float info
private int real2Parts(long* bits, ref int expo, double value)
pure nothrow @nogc
{
    double d;
    long b = 0;

    // Load value and round at the fracDigits.
    d = value;

    copyFp(b, d);

    *bits = b & (((cast(ulong) 1) << 52) - 1);
    expo = cast(int) (((b >> 52) & 2047) - 1023);

    return cast(int) (b >> 63);
}

private char[] vsprintf()(return char[] buf, string fmt, va_list va)
pure nothrow @nogc
{
    static const string hex = "0123456789abcdefxp";
    static const string hexu = "0123456789ABCDEFXP";
    char* bf = buf.ptr;
    const(char)* f = fmt.ptr;
    int tlen = 0;

    for (;;)
    {
        // fast copy everything up to the next % (or end of string)
        for (;;)
        {
            while ((cast(size_t) f) & 3)
            {
            schk1:
                if (f[0] == '%')
                {
                    goto scandd;
                }
            schk2:
                if (f[0] == 0)
                {
                    goto endfmt;
                }

                *bf++ = f[0];
                ++f;
            }
            for (;;)
            {
                // Check if the next 4 bytes contain %(0x25) or end of string.
                // Using the 'hasless' trick:
                // https://graphics.stanford.edu/~seander/bithacks.html#HasLessInWord
                uint v = *cast(uint*) f;
                uint c = (~v) & 0x80808080;
                if (((v ^ 0x25252525) - 0x01010101) & c)
                {
                    goto schk1;
                }
                if ((v - 0x01010101) & c)
                {
                    goto schk2;
                }

                *cast(uint*) bf = v;
                bf += 4;
                f += 4;
            }
        }
    scandd:

        ++f;

        // ok, we have a percent, read the modifiers first
        uint fw = 0;
        uint pr = -1;
        uint fl = 0;
        int tz = 0;

        // flags
        for (;;)
        {
            switch (f[0])
            {
                // if we have left justify
                case '-':
                    fl |= Modifier.leftJust;
                    ++f;
                    continue;
                // if we have leading plus
                case '+':
                    fl |= Modifier.leadingPlus;
                    ++f;
                    continue;
                // if we have leading space
                case ' ':
                    fl |= Modifier.leadingSpace;
                    ++f;
                    continue;
                // if we have leading 0x
                case '#':
                    fl |= Modifier.leading0x;
                    ++f;
                    continue;
                // if we have thousand commas
                case '\'':
                    fl |= Modifier.tripletComma;
                    ++f;
                    continue;
                // if we have kilo marker (none->kilo->kibi->jedec)
                case '$':
                    if (fl & Modifier.metricSuffix)
                    {
                        if (fl & Modifier.metric1024)
                        {
                            fl |= Modifier.metricJedec;
                        }
                        else
                        {
                            fl |= Modifier.metric1024;
                        }
                    }
                    else
                    {
                        fl |= Modifier.metricSuffix;
                    }
                    ++f;
                    continue;
                // if we don't want space between metric suffix and number
                case '_':
                    fl |= Modifier.metricNoSpace;
                    ++f;
                    continue;
                // if we have leading zero
                case '0':
                    fl |= Modifier.leadingZero;
                    ++f;
                    goto flags_done;
                default:
                    goto flags_done;
            }
        }
    flags_done:

        // get the field width
        if (f[0] == '*')
        {
            fw = va_arg!uint(va);
            ++f;
        }
        else
        {
            while ((f[0] >= '0') && (f[0] <= '9'))
            {
                fw = fw * 10 + f[0] - '0';
                f++;
            }
        }
        // get the precision
        if (f[0] == '.')
        {
            ++f;
            if (f[0] == '*')
            {
                pr = va_arg!uint(va);
                ++f;
            }
            else
            {
                pr = 0;
                while ((f[0] >= '0') && (f[0] <= '9'))
                {
                    pr = pr * 10 + f[0] - '0';
                    f++;
                }
            }
        }

        // handle integer size overrides
        switch (f[0])
        {
            // are we halfwidth?
            case 'h':
                fl |= Modifier.halfWidth;
                ++f;
                break;
            // are we 64-bit (unix style)
            case 'l':
                ++f;
                if (f[0] == 'l')
                {
                    fl |= Modifier.intMax;
                    ++f;
                }
                break;
            // are we 64-bit on intmax? (c99)
            case 'j':
                fl |= Modifier.intMax;
                ++f;
                break;
            // are we 64-bit on size_t or ptrdiff_t? (c99)
            case 'z':
            case 't':
                fl |= ((char*).sizeof == 8) ? Modifier.intMax : 0;
                ++f;
                break;
            // are we 64-bit (msft style)
            case 'I':
                if ((f[1] == '6') && (f[2] == '4'))
                {
                    fl |= Modifier.intMax;
                    f += 3;
                }
                else if ((f[1] == '3') && (f[2] == '2'))
                {
                    f += 3;
                }
                else
                {
                    fl |= ((void*).sizeof == 8) ? Modifier.intMax : 0;
                    ++f;
                }
                break;
            default:
                break;
        }

        // handle each replacement
        enum NUMSZ = 512; // big enough for e308 (with commas) or e-307
        char[NUMSZ] num;
        char[8] lead;
        char[8] tail;
        char *s;
        const(char)* h;
        uint l, n, cs;
        ulong n64;

        double fv;

        int decimalPos;
        const(char)* sn;

        switch (f[0])
        {
            case 's':
                // get the string
                s = va_arg!(char*)(va);
                if (s is null)
                {
                    s = cast(char*) "null";
                }
                // get the length
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
                if (pr >= 0)
                {
                    n = cast(uint) (sn - s);
                    if (n >= cast(uint) pr)
                    {
                        goto ld;
                    }
                    n = (cast(uint) (pr - n)) >> 2;
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
                // clamp to precision
                if (l > cast(uint) pr)
                {
                    l = pr;
                }
                lead[0] = 0;
                tail[0] = 0;
                pr = 0;
                decimalPos = 0;
                cs = 0;
                // copy the string in
                goto scopy;

            case 'c': // char
                // get the character
                s = num.ptr + NUMSZ - 1;
                *s = cast(char) va_arg!int(va);
                l = 1;
                lead[0] = 0;
                tail[0] = 0;
                pr = 0;
                decimalPos = 0;
                cs = 0;
                goto scopy;

            case 'n': // weird write-bytes specifier
                {
                    int *d = va_arg!(int*)(va);
                    *d = tlen + cast(int) (bf - buf.ptr);
                }
                break;

            case 'A': // hex float
            case 'a': // hex float
                h = (f[0] == 'A') ? hexu.ptr : hex.ptr;
                fv = va_arg!double(va);
                if (pr == -1)
                {
                    pr = 6; // default is 6
                }
                // read the double into a string
                if (real2Parts(cast(long*) &n64, decimalPos, fv))
                {
                    fl |= Modifier.negative;
                }
                s = num.ptr + 64;

                leadSign(fl, lead.ptr);

                if (decimalPos == -1023)
                {
                    decimalPos = (n64) ? -1022 : 0;
                }
                else
                {
                    n64 |= ((cast(ulong) 1) << 52);
                }
                n64 <<= (64 - 56);
                if (pr < 15)
                {
                    n64 += (((cast(ulong) 8) << 56) >> (pr * 4));
                }
                // add leading chars

                lead[1 + lead[0]] = '0';
                lead[2 + lead[0]] = 'x';
                lead[0] += 2;

                *s++ = h[(n64 >> 60) & 15];
                n64 <<= 4;
                if (pr)
                {
                    *s++ = period;
                }
                sn = s;

                // print the bits
                n = pr;
                if (n > 13)
                {
                    n = 13;
                }
                if (pr > cast(int) n)
                {
                    tz = pr - n;
                }
                pr = 0;
                while (n--)
                {
                    *s++ = h[(n64 >> 60) & 15];
                    n64 <<= 4;
                }

                // print the expo
                tail[1] = h[17];
                if (decimalPos < 0)
                {
                    tail[2] = '-';
                    decimalPos = -decimalPos;
                }
                else
                {
                    tail[2] = '+';
                }
                n = (decimalPos>= 1000) ? 6 : ((decimalPos >= 100) ? 5 : ((decimalPos >= 10) ? 4 : 3));
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

                decimalPos = cast(int) (s - sn);
                l = cast(int) (s - (num.ptr + 64));
                s = num.ptr + 64;
                cs = 1 + (3 << 24);
                goto scopy;

            case 'G': // float
            case 'g': // float
                h = (f[0] == 'G') ? hexu.ptr : hex.ptr;
                fv = va_arg!double(va);
                if (pr == -1)
                {
                    pr = 6;
                }
                else if (pr == 0)
                {
                    pr = 1; // default is 6
                }
                // read the double into a string
                if (real2String(sn, l, num.ptr, decimalPos, fv, (pr - 1) | 0x80000000))
                {
                    fl |= Modifier.negative;
                }

                // clamp the precision and delete extra zeros after clamp
                n = pr;
                if (l > cast(uint) pr)
                {
                    l = pr;
                }
                while ((l > 1) && (pr) && (sn[l - 1] == '0'))
                {
                    --pr;
                    --l;
                }

                // should we use %e
                if ((decimalPos <= -4) || (decimalPos > cast(int) n))
                {
                    if (pr > cast(int) l)
                    {
                        pr = l - 1;
                    }
                    else if (pr)
                    {
                       --pr; // when using %e, there is one digit before the decimal
                    }
                    goto doexpfromg;
                }
                // this is the insane action to get the pr to match %g sematics for %f
                if (decimalPos > 0)
                {
                    pr = (decimalPos < cast(int) l) ? l - decimalPos : 0;
                }
                else
                {
                    pr = -decimalPos + ((pr > cast(int) l) ? l : pr);
                }
                goto dofloatfromg;

            case 'E': // float
            case 'e': // float
                h = (f[0] == 'E') ? hexu.ptr : hex.ptr;
                fv = va_arg!double(va);
                if (pr == -1)
                {
                    pr = 6; // default is 6
                }
                // read the double into a string
                if (real2String(sn, l, num.ptr, decimalPos, fv, pr | 0x80000000))
                {
                    fl |= Modifier.negative;
                }
            doexpfromg:
                tail[0] = 0;
                leadSign(fl, lead.ptr);
                if (decimalPos == special)
                {
                    s = cast(char*) sn;
                    cs = 0;
                    pr = 0;
                    goto scopy;
                }
                s = num.ptr + 64;
                // handle leading chars
                *s++ = sn[0];

                if (pr)
                {
                    *s++ = period;
                }

                // handle after decimal
                if ((l - 1) > cast(uint) pr)
                {
                    l = pr + 1;
                }
                for (n = 1; n < l; n++)
                {
                    *s++ = sn[n];
                }
                // trailing zeros
                tz = pr - (l - 1);
                pr = 0;
                // dump expo
                tail[1] = h[0xe];
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
                cs = 1 + (3 << 24); // how many tens
                goto flt_lead;

            case 'f': // float
                fv = va_arg!double(va);
            doafloat:
                // do kilos
                if (fl & Modifier.metricSuffix)
                {
                    double divisor;
                    divisor = 1000.0f;
                    if (fl & Modifier.metric1024)
                    {
                        divisor = 1024.0;
                    }
                    while (fl < 0x4000000)
                    {
                        if ((fv < divisor) && (fv > -divisor))
                        {
                            break;
                        }
                        fv /= divisor;
                        fl += 0x1000000;
                    }
                }
                if (pr == -1)
                {
                    pr = 6; // default is 6
                }
                // read the double into a string
                if (real2String(sn, l, num.ptr, decimalPos, fv, pr))
                {
                    fl |= Modifier.negative;
                }
            dofloatfromg:
                tail[0] = 0;
                leadSign(fl, lead.ptr);
                if (decimalPos == special)
                {
                    s = cast(char*) sn;
                    cs = 0;
                    pr = 0;
                    goto scopy;
                }
                s = num.ptr + 64;

                // handle the three decimal varieties
                if (decimalPos <= 0)
                {
                    int i;
                    // handle 0.000*000xxxx
                    *s++ = '0';
                    if (pr)
                    {
                        *s++ = period;
                    }
                    n = -decimalPos;
                    if (cast(int) n > pr)
                    {
                        n = pr;
                    }
                    i = n;
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
                        *cast(uint*)s = 0x30303030;
                        s += 4;
                        i -= 4;
                    }
                    while (i)
                    {
                        *s++ = '0';
                        --i;
                    }
                    if (cast(int) (l + n) > pr)
                    {
                        l = pr - n;
                    }
                    i = l;
                    while (i)
                    {
                        *s++ = *sn++;
                        --i;
                    }
                    tz = pr - (n + l);
                    cs = 1 + (3 << 24); // how many tens did we write (for commas below)
                }
                else
                {
                    cs = (fl & Modifier.tripletComma) ? ((600 - cast(uint) decimalPos) % 3) : 0;
                    if (cast(uint) decimalPos>= l)
                    {
                        // handle xxxx000*000.0
                        n = 0;
                        for (;;)
                        {
                            if ((fl & Modifier.tripletComma) && (++cs == 4))
                            {
                                cs = 0;
                                *s++ = comma;
                            }
                            else
                            {
                                *s++ = sn[n];
                                ++n;
                                if (n >= l)
                                {
                                    break;
                                }
                            }
                        }
                        if (n < cast(uint) decimalPos)
                        {
                            n = decimalPos - n;
                            if ((fl & Modifier.tripletComma) == 0)
                            {
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
                            }
                            while (n)
                            {
                                if ((fl & Modifier.tripletComma) && (++cs == 4))
                                {
                                    cs = 0;
                                    *s++ = comma;
                                }
                                else
                                {
                                    *s++ = '0';
                                    --n;
                                }
                            }
                        }
                        cs = cast(int) (s - (num.ptr + 64)) + (3 << 24); // cs is how many tens
                        if (pr)
                        {
                            *s++ = period;
                            tz = pr;
                        }
                    }
                    else
                    {
                        // handle xxxxx.xxxx000*000
                        n = 0;
                        for (;;)
                        {
                            if ((fl & Modifier.tripletComma) && (++cs == 4))
                            {
                                cs = 0;
                                *s++ = comma;
                            }
                            else
                            {
                                *s++ = sn[n];
                                ++n;
                                if (n >= cast(uint) decimalPos)
                                {
                                    break;
                                }
                            }
                        }
                        cs = cast(int) (s - (num.ptr + 64)) + (3 << 24); // cs is how many tens
                        if (pr)
                        {
                            *s++ = period;
                        }
                        if ((l - decimalPos) > cast(uint) pr)
                        {
                            l = pr + decimalPos;
                        }
                        while (n < l)
                        {
                            *s++ = sn[n];
                            ++n;
                        }
                        tz = pr - (l - decimalPos);
                    }
                }
                pr = 0;

                // handle k,m,g,t
                if (fl & Modifier.metricSuffix)
                {
                    char idx = 1;
                    if (fl & Modifier.metricNoSpace)
                    {
                        idx = 0;
                    }
                    tail[0] = idx;
                    tail[1] = ' ';
                    {
                        if (fl >> 24)
                        { // SI kilo is 'k', JEDEC and SI kibits are 'K'.
                            if (fl & Modifier.metric1024)
                            {
                                tail[idx + 1] = "_KMGT"[fl >> 24];
                            }
                            else
                            {
                                tail[idx + 1] = "_kMGT"[fl >> 24];
                            }
                            idx++;
                            // If printing kibits and not in jedec, add the 'i'.
                            if (fl & Modifier.metric1024 && !(fl & Modifier.metricJedec))
                            {
                                tail[idx + 1] = 'i';
                                idx++;
                            }
                            tail[0] = idx;
                        }
                    }
                }

            flt_lead:
                // get the length that we copied
                l = cast(uint) (s - (num.ptr + 64));
                s = num.ptr + 64;
                goto scopy;

            case 'B': // upper binary
            case 'b': // lower binary
                h = (f[0] == 'B') ? hexu.ptr : hex.ptr;
                lead[0] = 0;
                if (fl & Modifier.leading0x)
                {
                    lead[0] = 2;
                    lead[1] = '0';
                    lead[2] = h[0xb];
                }
                l = (8 << 4) | (1 << 8);
                {
                    goto radixnum;
                }

            case 'o': // octal
                h = hexu.ptr;
                lead[0] = 0;
                if (fl & Modifier.leading0x)
                {
                    lead[0] = 1;
                    lead[1] = '0';
                }
                l = (3 << 4) | (3 << 8);
                goto radixnum;

            case 'p': // pointer
                fl |= ((void*).sizeof == 8) ? Modifier.intMax : 0;
                pr = (void*).sizeof * 2;
                fl &= ~Modifier.leadingZero; // 'p' only prints the pointer with zeros
                                        // drop through to X

                goto case;
            case 'X': // upper hex
            case 'x': // lower hex
                h = (f[0] == 'X') ? hexu.ptr : hex.ptr;
                l = (4 << 4) | (4 << 8);
                lead[0] = 0;
                if (fl & Modifier.leading0x)
                {
                    lead[0] = 2;
                    lead[1] = '0';
                    lead[2] = h[16];
                }
            radixnum:
                // get the number
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
                // clear tail, and clear leading if value is zero
                tail[0] = 0;
                if (n64 == 0)
                {
                    lead[0] = 0;
                    if (pr == 0)
                    {
                        l = 0;
                        cs = (((l >> 4) & 15)) << 24;
                        goto scopy;
                    }
                }
                // convert to string
                for (;;)
                {
                    *--s = h[n64 & ((1 << (l >> 8)) - 1)];
                    n64 >>= (l >> 8);
                    if (!((n64) || (cast(int) ((num.ptr + NUMSZ) - s) < pr)))
                    {
                        break;
                    }
                    if (fl & Modifier.tripletComma)
                    {
                        ++l;
                        if ((l & 15) == ((l >> 4) & 15))
                        {
                            l &= ~15;
                            *--s = comma;
                        }
                    }
                }
                // get the tens and the comma pos
                cs = cast(uint) ((num.ptr + NUMSZ) - s) + ((((l >> 4) & 15)) << 24);
                // get the length that we copied
                l = cast(uint)((num.ptr + NUMSZ) - s);
                // copy it
                goto scopy;

            case 'u': // unsigned
            case 'i':
            case 'd': // integer
                // get the integer and abs it
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

                if (fl & Modifier.metricSuffix)
                {
                    if (n64 < 1024)
                    {
                        pr = 0;
                    }
                    else if (pr == -1)
                    {
                       pr = 1;
                    }
                    fv = cast(double) cast(long) n64;
                    goto doafloat;
                }

                // convert to string
                s = num.ptr + NUMSZ;
                l = 0;

                for (;;)
                {
                    // do in 32-bit chunks (avoid lots of 64-bit divides even with constant denominators)
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
                    if ((fl & Modifier.tripletComma) == 0)
                    {
                        while (n)
                        {
                            s -= 2;
                            *cast(ushort*) s = *cast(ushort*) &digitpair[(n % 100) * 2];
                            n /= 100;
                        }
                    }
                    while (n)
                    {
                        if ((fl & Modifier.tripletComma) && (l++ == 3))
                        {
                            l = 0;
                            *--s = comma;
                            --o;
                        }
                        else
                        {
                            *--s = cast(char) (n % 10) + '0';
                            n /= 10;
                        }
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
                        if ((fl & Modifier.tripletComma) && (l++ == 3))
                        {
                            l = 0;
                            *--s = comma;
                            --o;
                        }
                        else
                        {
                            *--s = '0';
                        }
                    }
                }

                tail[0] = 0;
                leadSign(fl, lead.ptr);

                // get the length that we copied
                l = cast(uint) ((num.ptr + NUMSZ) - s);
                if (l == 0)
                {
                    *--s = '0';
                    l = 1;
                }
                cs = l + (3 << 24);
                if (pr < 0)
                {
                    pr = 0;
                }

            scopy:
                // get fw=leading/trailing space, pr=leading zeros
                if (pr < cast(int) l)
                {
                    pr = l;
                }
                n = pr + lead[0] + tail[0] + tz;
                if (fw < cast(int) n)
                {
                    fw = n;
                }
                fw -= n;
                pr -= l;

                // handle right justify and leading zeros
                if ((fl & Modifier.leftJust) == 0)
                {
                    if (fl & Modifier.leadingZero) // if leading zeros, everything is in pr
                    {
                        pr = (fw > pr) ? fw : pr;
                        fw = 0;
                    }
                    else
                    {
                        fl &= ~Modifier.tripletComma; // if no leading zeros, then no commas
                    }
                }

                // copy the spaces and/or zeros
                if (fw + pr)
                {
                    int i;

                    // copy leading spaces (or when doing %8.4d stuff)
                    if ((fl & Modifier.leftJust) == 0)
                    {
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
                    uint c = cs >> 24;
                    cs &= 0xffffff;
                    cs = (fl & Modifier.tripletComma) ? (cast(uint) (c - ((pr + cs) % (c + 1)))) : 0;
                    while (pr > 0)
                    {
                        i = pr;
                        pr -= i;
                        if ((fl & Modifier.tripletComma) == 0)
                        {
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
                        }
                        while (i)
                        {
                            if ((fl & Modifier.tripletComma) && (cs++ == c))
                            {
                                cs = 0;
                                *bf++ = comma;
                            }
                            else
                            {
                                *bf++ = '0';
                            }
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

                // handle the left justify
                if (fl & Modifier.leftJust && fw > 0)
                {
                    while (fw)
                    {
                        int i = fw;
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
                        while (i--)
                        {
                            *bf++ = ' ';
                        }
                    }
                }
                break;

            default: // unknown, just copy code
                s = num.ptr + NUMSZ - 1;
                *s = f[0];
                l = 1;
                fw = pr = fl = 0;
                lead[0] = 0;
                tail[0] = 0;
                pr = 0;
                decimalPos = 0;
                cs = 0;
                goto scopy;
        }
        ++f;
    }
endfmt:

    *bf = 0;
    return buf[0 .. tlen + cast(int) (bf - buf.ptr)];
}

package(tanya) char[] format(return char[] buf, string fmt, ...)
nothrow
{
    va_list va;
    va_start(va, fmt);
    auto result = vsprintf(buf, fmt, va);
    va_end(va);
    return result;
}

// Converting a floating point to string.
private nothrow unittest
{
    char[318] buffer;

    assert(format(buffer, "%g", 0.1234) == "0.1234");
    assert(format(buffer, "%g", 0.3) == "0.3");
    assert(format(buffer, "%g", 0.333333333333) == "0.333333");
    assert(format(buffer, "%g", 38234.1234) == "38234.1");
    assert(format(buffer, "%g", -0.3) == "-0.3");
}
