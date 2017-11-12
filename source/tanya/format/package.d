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
import tanya.meta.trait;

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
