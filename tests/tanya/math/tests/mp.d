/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
module tanya.math.tests.mp;

import tanya.algorithm.comparison;
import tanya.math.mp;

@nogc nothrow pure @safe unittest
{
    auto h1 = Integer(18);
    auto h2 = Integer(4);
    h1 %= h2;
    assert(h1 == 2);

    h1 = 8;
    h1 %= h2;
    assert(h1 == 0);

    h1 = 7;
    h1 %= h2;
    assert(h1 == 3);

    h1 = 56088;
    h2 = 456;
    h1 /= h2;
    assert(h1 == 123);
}

@nogc nothrow pure @safe unittest
{
    Integer integer;
    assert(integer.toArray().length == 0);
}

@nogc nothrow pure @safe unittest
{
    auto integer = Integer(0x03);
    ubyte[1] expected = [ 0x03 ];

    auto array = integer.toArray();
    assert(equal(array[], expected[]));
}

@nogc nothrow pure @safe unittest
{
    ubyte[63] expected = [
        0x02, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08,
        0x09, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x10,
        0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18,
        0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f, 0x20,
        0x21, 0x22, 0x23, 0x24, 0x25, 0x26, 0x27, 0x28,
        0x29, 0x2a, 0x2b, 0x2c, 0x2d, 0x2e, 0x2f, 0x30,
        0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38,
        0x39, 0x3a, 0x3b, 0x00, 0x61, 0x62, 0x63,
    ];
    auto integer = Integer(Sign.positive, expected[]);

    auto array = integer.toArray();
    assert(equal(array[], expected[]));
}

@nogc nothrow pure @safe unittest
{
    ubyte[14] expected = [
        0x22, 0x33, 0x44, 0x55, 0x05, 0x06, 0x07,
        0x08, 0x3a, 0x3b, 0x00, 0x61, 0x62, 0x63,
    ];
    auto integer = Integer(Sign.positive, expected[]);

    auto array = integer.toArray();
    assert(equal(array[], expected[]));
}
