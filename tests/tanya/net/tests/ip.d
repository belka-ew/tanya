/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
module tanya.net.tests.ip;

import tanya.net.ip;
import tanya.range;

// Rejects malformed addresses
@nogc nothrow pure @safe unittest
{
    assert(address4("256.0.0.1").isNothing);
    assert(address4(".0.0.1").isNothing);
    assert(address4("0..0.1").isNothing);
    assert(address4("0.0.0.").isNothing);
    assert(address4("0.0.").isNothing);
    assert(address4("").isNothing);
}

@nogc nothrow pure @safe unittest
{
    assert(address4(cast(ubyte[]) []).isNothing);
}

// Assignment and comparison works
@nogc nothrow pure @safe unittest
{
    auto address1 = Address4.loopback();
    auto address2 = Address4.any();
    address1 = address2;
    assert(address1 == address2);
}

@nogc nothrow @safe unittest
{
    char[18] actual;

    address6("ff00:2:3:4:5:6:7:8").get.toString(arrayInserter(actual));
    assert(actual[] == "ff00:2:3:4:5:6:7:8");
}

// Skips zero group in the middle
@nogc nothrow @safe unittest
{
    char[12] actual;

    address6("1::4:5:6:7:8").get.toString(arrayInserter(actual));
    assert(actual[] == "1::4:5:6:7:8");
}

// Doesn't replace lonely zeroes
@nogc nothrow @safe unittest
{
    char[15] actual;

    address6("0:1:0:2:3:0:4:0").get.toString(arrayInserter(actual));
    assert(actual[] == "0:1:0:2:3:0:4:0");
}

// Skips zero group at the beginning
@nogc nothrow @safe unittest
{
    char[13] actual;

    address6("::3:4:5:6:7:8").get.toString(arrayInserter(actual));
    assert(actual[] == "::3:4:5:6:7:8");
}

// Skips zero group at the end
@nogc nothrow @safe unittest
{
    char[13] actual;

    address6("1:2:3:4:5:6::").get.toString(arrayInserter(actual));
    assert(actual[] == "1:2:3:4:5:6::");
}

@nogc nothrow @safe unittest
{
    ubyte[16] expected = [0, 1, 0, 2, 0, 3, 0, 4, 0, 5, 0, 6, 0, 7, 0, 8];
    auto actual = address6("1:2:3:4:5:6:7:8");
    assert(actual.get.toBytes() == expected);
}

@nogc nothrow @safe unittest
{
    ubyte[16] expected;
    auto actual = address6("::");
    assert(actual.get.toBytes() == expected);
}

@nogc nothrow @safe unittest
{
    ubyte[16] expected = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1];
    auto actual = address6("::1");
    assert(actual.get.toBytes() == expected);
}

@nogc nothrow @safe unittest
{
    ubyte[16] expected = [0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
    auto actual = address6("1::");
    assert(actual.get.toBytes() == expected);
}

// Rejects malformed addresses
@nogc nothrow @safe unittest
{
    assert(address6("").isNothing);
    assert(address6(":").isNothing);
    assert(address6(":a").isNothing);
    assert(address6("a:").isNothing);
    assert(address6("1:2:3:4::6:").isNothing);
    assert(address6("fe80:2:3:4::6:7:8%").isNothing);
}

// Parses embedded IPv4 address
@nogc nothrow @safe unittest
{
    ubyte[16] expected = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4];
    auto actual = address6("0:0:0:0:0:0:1.2.3.4");
    assert(actual.get.toBytes() == expected);
}

@nogc nothrow @safe unittest
{
    ubyte[16] expected = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 2, 3, 4];
    auto actual = address6("::1.2.3.4");
    assert(actual.get.toBytes() == expected);
}

@nogc nothrow @safe unittest
{
    ubyte[16] expected = [0, 0, 0, 0, 0, 0, 0, 0, 0, 5, 0, 6, 1, 2, 3, 4];
    auto actual = address6("::5:6:1.2.3.4");
    assert(actual.get.toBytes() == expected);
}

@nogc nothrow @safe unittest
{
    assert(address6("0:0:0:0:0:0:1.2.3.").isNothing);
    assert(address6("0:0:0:0:0:0:1.2:3.4").isNothing);
    assert(address6("0:0:0:0:0:0:1.2.3.4.").isNothing);
    assert(address6("fe80:0:0:0:0:0:1.2.3.4%1").get.scopeID == 1);
}

// Can assign another address
@nogc nothrow pure @safe unittest
{
    Address actual = Address4.loopback;
    Address expected = Address6.loopback;
    actual = expected;
    assert(actual == expected);
}
