/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Internet Protocol implementation.
 *
 * Copyright: Eugene Wissner 2018.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/net/ip.d,
 *                 tanya/net/ip.d)
 */
module tanya.net.ip;

import tanya.algorithm.mutation;
import tanya.container.string;
import tanya.conv;
import tanya.format;
import tanya.meta.trait;
import tanya.meta.transform;
import tanya.net.inet;
import tanya.range;
import tanya.typecons;

/**
 * IPv4 internet address.
 */
struct Address4
{
    // In network byte order.
    private uint address;

    version (LittleEndian)
    {
        private enum uint loopback_ = 0x0100007fU;
        enum byte step = 8;
    }
    else
    {
        private enum uint loopback_ = 0x7f000001U;
        enum byte step = -8;
    }
    private enum uint any_ = 0U;
    private enum uint broadcast = uint.max;

    /**
     * Constructs an $(D_PSYMBOL Address4) from an unsigned integer in host
     * byte order.
     *
     * Params:
     *  address = The address as an unsigned integer in host byte order.
     */
    this(uint address) @nogc nothrow pure @safe
    {
        copy(NetworkOrder!4(address),
             (() @trusted => (cast(ubyte*) &this.address)[0 .. 4])());
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        assert(Address4(0x00202000U).toUInt() == 0x00202000U);
    }

    /**
     * Returns object that represents 127.0.0.1.
     *
     * Returns: Object that represents the Loopback address.
     */
    static Address4 loopback() @nogc nothrow pure @safe
    {
        typeof(return) address;
        address.address = Address4.loopback_;
        return address;
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        assert(Address4.loopback().isLoopback());
    }

    /**
     * Returns object that represents 0.0.0.0.
     *
     * Returns: Object that represents any address.
     */
    static Address4 any() @nogc nothrow pure @safe
    {
        typeof(return) address;
        address.address = Address4.any_;
        return address;
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        assert(Address4.any().isAny());
    }

    /**
     * Loopback address is 127.0.0.1.
     *
     * Returns: $(D_KEYWORD true) if this is a loopback address,
     *          $(D_KEYWORD false) otherwise.
     */
    bool isLoopback() const @nogc nothrow pure @safe
    {
        return this.address == loopback_;
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        assert(address4("127.0.0.1").isLoopback());
    }

    /**
     * 0.0.0.0 can represent any address. This function checks whether this
     * address is 0.0.0.0.
     *
     * Returns: $(D_KEYWORD true) if this is an unspecified address,
     *          $(D_KEYWORD false) otherwise.
     */
    bool isAny() const @nogc nothrow pure @safe
    {
        return this.address == any_;
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        assert(address4("0.0.0.0").isAny());
    }

    /**
     * Broadcast address is 255.255.255.255.
     *
     * Returns: $(D_KEYWORD true) if this is a broadcast address,
     *          $(D_KEYWORD false) otherwise.
     */
    bool isBroadcast() const @nogc nothrow pure @safe
    {
        return this.address == broadcast;
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        assert(address4("255.255.255.255").isBroadcast());
    }

    /**
     * Determines whether this address' destination is a group of endpoints.
     *
     * Returns: $(D_KEYWORD true) if this is a multicast address,
     *          $(D_KEYWORD false) otherwise.
     *
     * See_Also: $(D_PSYMBOL isMulticast).
     */
    bool isMulticast() const @nogc nothrow pure @safe
    {
        version (LittleEndian)
        {
            enum uint mask = 0xe0;
        }
        else
        {
            enum uint mask = 0xe0000000U;
        }
        return (this.address & mask) == mask;
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        assert(address4("224.0.0.3").isMulticast());
    }

    /**
     * Determines whether this address' destination is a single endpoint.
     *
     * Returns: $(D_KEYWORD true) if this is a multicast address,
     *          $(D_KEYWORD false) otherwise.
     *
     * See_Also: $(D_PSYMBOL isMulticast).
     */
    bool isUnicast() const @nogc nothrow pure @safe
    {
        return !isMulticast();
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        assert(address4("192.168.0.1").isUnicast());
    }

    /**
     * Produces a string containing an IPv4 address in dotted-decimal notation.
     *
     * Returns: This address in dotted-decimal notation.
     */
    String stringify() const @nogc nothrow pure @safe
    {
        const octets = (() @trusted => (cast(ubyte*) &this.address)[0 .. 4])();
        enum string fmt = "{}.{}.{}.{}";
        version (LittleEndian)
        {
            return format!fmt(octets[0], octets[1], octets[2], octets[3]);
        }
        else
        {
            return format!fmt(octets[3], octets[2], octets[1], octets[0]);
        }
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        const dottedDecimal = "192.168.0.1";
        const address = address4(dottedDecimal);
        assert(address.get.stringify() == dottedDecimal);
    }

    /**
     * Produces a byte array containing this address in network byte order.
     *
     * Returns: This address as raw bytes in network byte order.
     */
    ubyte[4] toBytes() const @nogc nothrow pure @safe
    {
        ubyte[4] bytes;
        copy((() @trusted => (cast(ubyte*) &this.address)[0 .. 4])(), bytes[]);
        return bytes;
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        const actual = address4("192.168.0.1");
        const ubyte[4] expected = [192, 168, 0, 1];
        assert(actual.toBytes() == expected);
    }

    /**
     * Converts this address to an unsigned integer in host byte order.
     *
     * Returns: This address as an unsigned integer in host byte order.
     */
    uint toUInt() const @nogc nothrow pure @safe
    {
        alias slice = () @trusted => (cast(ubyte*) &this.address)[0 .. 4];
        return toHostOrder!uint(slice());
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        assert(address4("127.0.0.1").toUInt() == 0x7f000001U);
    }
}

/**
 * Parses a string containing an IPv4 address in dotted-decimal notation.
 *
 * Params:
 *  R     = Input range type.
 *  range = Stringish range containing the address.
 *
 * Returns: $(D_PSYMBOL Option) containing the address if the parsing was
 *          successful, or nothing otherwise.
 */
Option!Address4 address4(R)(R range)
if (isInputRange!R && isSomeChar!(ElementType!R))
{
    Address4 result;
    version (LittleEndian)
    {
        ubyte shift;
        enum ubyte cond = 24;
    }
    else
    {
        ubyte shift = 24;
        enum ubyte cond = 0;
    }

    for (; shift != cond; shift += Address4.step, range.popFront())
    {
        if (range.empty || range.front == '.')
        {
            return typeof(return)();
        }
        result.address |= readIntegral!ubyte(range) << shift;
        if (range.empty || range.front != '.')
        {
            return typeof(return)();
        }
    }

    if (range.empty || range.front == '.')
    {
        return typeof(return)();
    }
    result.address |= readIntegral!ubyte(range) << shift;
    return range.empty ? typeof(return)(result) : typeof(return)();
}

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

/**
 * Constructs an $(D_PSYMBOL Address4) from raw bytes in network byte order.
 *
 * Params:
 *  R     = Input range type.
 *  range = $(D_KEYWORD ubyte) range containing the address.
 *
 * Returns: $(D_PSYMBOL Option) containing the address if the $(D_PARAM range)
 *          contains exactly 4 bytes, or nothing otherwise.
 */
Option!Address4 address4(R)(R range)
if (isInputRange!R && is(Unqual!(ElementType!R) == ubyte))
{
    Address4 result;
    version (LittleEndian)
    {
        ubyte shift;
    }
    else
    {
        ubyte shift = 24;
    }

    for (; shift <= 24; shift += Address4.step, range.popFront())
    {
        if (range.empty)
        {
            return typeof(return)();
        }
        result.address |= range.front << shift;
    }

    return range.empty ? typeof(return)(result) : typeof(return)();
}

///
@nogc nothrow pure @safe unittest
{
    {
        ubyte[4] actual = [127, 0, 0, 1];
        assert(address4(actual[]).isLoopback());
    }
    {
        ubyte[3] actual = [127, 0, 0];
        assert(address4(actual[]).isNothing);
    }
    {
        ubyte[5] actual = [127, 0, 0, 0, 1];
        assert(address4(actual[]).isNothing);
    }
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
