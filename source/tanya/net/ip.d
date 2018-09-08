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
import tanya.encoding.ascii;
import tanya.format;
import tanya.meta.trait;
import tanya.meta.transform;
import tanya.net.iface;
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
     * See_Also: $(D_PSYMBOL isUnicast).
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
if (isForwardRange!R && is(Unqual!(ElementType!R) == char) && hasLength!R)
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

/**
 * IPv6 internet address.
 */
struct Address6
{
    // Raw bytes
    private ubyte[16] address;

    /// Scope ID.
    uint scopeID;

    /**
     * Constructs an $(D_PSYMBOL Address6) from an array containing raw bytes
     * in network byte order and scope ID.
     *
     * Params:
     *  address = The address as an unsigned integer in host byte order.
     *  scopeID = Scope ID.
     */
    this(ubyte[16] address, uint scopeID = 0) @nogc nothrow pure @safe
    {
        copy(address[], this.address[]);
        this.scopeID = scopeID;
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        const ubyte[16] expected = [ 0, 1, 0, 2, 0, 3, 0, 4,
                                     0, 5, 0, 6, 0, 7, 0, 8 ];
        auto actual = Address6(expected, 1);
        assert(actual.toBytes() == expected);
        assert(actual.scopeID == 1);
    }

    /**
     * Returns object that represents ::.
     *
     * Returns: Object that represents any address.
     */
    static Address6 any() @nogc nothrow pure @safe
    {
        return Address6();
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        assert(Address6.any().isAny());
    }

    /**
     * Returns object that represents ::1.
     *
     * Returns: Object that represents the Loopback address.
     */
    static Address6 loopback() @nogc nothrow pure @safe
    {
        typeof(return) address;
        address.address[$ - 1] = 1;
        return address;
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        assert(Address6.loopback().isLoopback());
    }

    /**
     * :: can represent any address. This function checks whether this
     * address is ::.
     *
     * Returns: $(D_KEYWORD true) if this is an unspecified address,
     *          $(D_KEYWORD false) otherwise.
     */
    bool isAny() const @nogc nothrow pure @safe
    {
        return this.address == any.address;
    }

    ///
    @nogc nothrow @safe unittest
    {
        assert(address6("::").isAny());
    }

    /**
     * Loopback address is ::1.
     *
     * Returns: $(D_KEYWORD true) if this is a loopback address,
     *          $(D_KEYWORD false) otherwise.
     */
    bool isLoopback() const @nogc nothrow pure @safe
    {
        return this.address == loopback.address;
    }

    ///
    @nogc nothrow @safe unittest
    {
        assert(address6("::1").isLoopback());
    }

    /**
     * Determines whether this address' destination is a group of endpoints.
     *
     * Returns: $(D_KEYWORD true) if this is a multicast address,
     *          $(D_KEYWORD false) otherwise.
     *
     * See_Also: $(D_PSYMBOL isUnicast).
     */
    bool isMulticast() const @nogc nothrow pure @safe
    {
        return this.address[0] == 0xff;
    }

    ///
    @nogc nothrow @safe unittest
    {
        assert(address6("ff00::").isMulticast());
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
    @nogc nothrow @safe unittest
    {
        assert(address6("::1").isUnicast());
    }

    /**
     * Determines whether this address is a link-local unicast address.
     *
     * Returns: $(D_KEYWORD true) if this is a link-local address,
     *          $(D_KEYWORD false) otherwise.
     */
    bool isLinkLocal() const @nogc nothrow pure @safe
    {
        return this.address[0] == 0xfe && (this.address[1] & 0xc0) == 0x80;
    }

    ///
    @nogc nothrow @safe unittest
    {
        assert(address6("fe80::1").isLinkLocal());
    }

    /**
     * Determines whether this address is an Unique Local Address (ULA).
     *
     * Returns: $(D_KEYWORD true) if this is an Unique Local Address,
     *          $(D_KEYWORD false) otherwise.
     */
    bool isUniqueLocal() const @nogc nothrow pure @safe
    {
        return this.address[0] == 0xfc || this.address[0] == 0xfd;
    }

    ///
    @nogc nothrow @safe unittest
    {
        assert(address6("fd80:124e:34f3::1").isUniqueLocal());
    }

    /**
     * Returns text representation of this address.
     *
     * Returns: text representation of this address.
     */
    String stringify() const @nogc nothrow pure @safe
    {
        String output;
        foreach (i, b; this.address)
        {
            ubyte low = b & 0xf;
            ubyte high = b >> 4;

            if (high < 10)
            {
                output.insertBack(cast(char) (high + '0'));
            }
            else
            {
                output.insertBack(cast(char) (high - 10 + 'a'));
            }
            if (low < 10)
            {
                output.insertBack(cast(char) (low + '0'));
            }
            else
            {
                output.insertBack(cast(char) (low - 10 + 'a'));
            }
            if (i % 2 != 0 && i != (this.address.length - 1))
            {
                output.insertBack(':');
            }
        }

        return output;
    }

    ///
    @nogc nothrow @safe unittest
    {
        import tanya.algorithm.comparison : equal;

        assert(equal(address6("1:2:3:4:5:6:7:8").stringify()[],
               "0001:0002:0003:0004:0005:0006:0007:0008"));
    }

    /**
     * Produces a byte array containing this address in network byte order.
     *
     * Returns: This address as raw bytes in network byte order.
     */
    ubyte[16] toBytes() const @nogc nothrow pure @safe
    {
        return this.address;
    }

    ///
    @nogc nothrow @safe unittest
    {
        auto actual = address6("1:2:3:4:5:6:7:8");
        ubyte[16] expected = [0, 1, 0, 2, 0, 3, 0, 4, 0, 5, 0, 6, 0, 7, 0, 8];
        assert(actual.toBytes() == expected);
    }
}

private void write2Bytes(R)(ref R range, ubyte[] address)
{
    ushort group = readIntegral!ushort(range, 16);
    address[0] = cast(ubyte) (group >> 8);
    address[1] = group & 0xff;
}

/**
 * Parses a string containing an IPv6 address.
 *
 * This function isn't pure since an IPv6 address can contain interface name
 * or interface ID (separated from the address by `%`). If an interface name
 * is specified (i.e. first character after `%` is not a digit), the parser
 * tries to convert it to the ID of that interface. If the interface with the
 * given name can't be found, the parser doesn't fail, but just ignores the
 * invalid interface name.
 *
 * If an ID is given (i.e. first character after `%` is a digit),
 * $(D_PSYMBOL address6) just stores it in $(D_PSYMBOL Address6.scopeID) without
 * checking whether an interface with this ID really exists. If the ID is
 * invalid (if it is too long or contains non decimal characters), parsing
 * and nothing is returned.
 *
 * If neither an ID nor a name is given, $(D_PSYMBOL Address6.scopeID) is set
 * to `0`.
 *
 * The parser doesn't support notation with an embedded IPv4 address (e.g.
 * ::1.2.3.4).
 *
 * Params:
 *  R     = Input range type.
 *  range = Stringish range containing the address.
 *
 * Returns: $(D_PSYMBOL Option) containing the address if the parsing was
 *          successful, or nothing otherwise.
 */
Option!Address6 address6(R)(R range)
if (isForwardRange!R && is(Unqual!(ElementType!R) == char) && hasLength!R)
{
    if (range.empty)
    {
        return typeof(return)();
    }
    Address6 result;
    ubyte[12] tail;
    size_t i;
    size_t j;

    // An address begins with a number, not ':'. But there is a special case
    // if the address begins with '::'.
    if (range.front == ':')
    {
        range.popFront();
        if (range.empty || range.front != ':')
        {
            return typeof(return)();
        }
        range.popFront();
        goto ParseTail;
    }

    // Parse the address before '::'.
    // This loop parses the whole address if it doesn't contain '::'.
    for (; i < 13; i += 2)
    {
        write2Bytes(range, result.address[i .. $]);
        if (range.empty || range.front != ':')
        {
            return typeof(return)();
        }
        range.popFront();
        if (range.empty)
        {
            return typeof(return)();
        }
        if (range.front == ':')
        {
            range.popFront();
            goto ParseTail;
        }
    }
    write2Bytes(range, result.address[14 .. $]);

    if (range.empty)
    {
        return typeof(return)(result);
    }
    else if (range.front == '%')
    {
        goto ParseIface;
    }
    else
    {
        return typeof(return)();
    }

ParseTail: // after ::
    // Normally the address can't end with ':', but a special case is if the
    // address ends with '::'. So the first iteration of the loop below is
    // unrolled to check whether the address contains something after '::' at
    // all.
    if (range.empty)
    {
        return typeof(return)(result); // ends with ::
    }
    if (range.front == ':')
    {
        return typeof(return)();
    }
    write2Bytes(range, tail[j .. $]);
    if (range.empty)
    {
        goto CopyTail;
    }
    else if (range.front == '%')
    {
        goto ParseIface;
    }
    else if (range.front != ':')
    {
        return typeof(return)();
    }
    range.popFront();

    for (i = 2, j = 2; i <= 11; i += 2, j += 2, range.popFront())
    {
        if (range.empty || range.front == ':')
        {
            return typeof(return)();
        }
        write2Bytes(range, tail[j .. $]);

        if (range.empty)
        {
            goto CopyTail;
        }
        else if (range.front == '%')
        {
            goto ParseIface;
        }
        else if (range.front != ':')
        {
            return typeof(return)();
        }
    }

ParseIface: // Scope name or ID
    range.popFront();
    if (range.empty)
    {
        return typeof(return)();
    }
    else if (isDigit(range.front))
    {
        const scopeID = readIntegral!uint(range);
        if (range.empty)
        {
            result.scopeID = scopeID;
        }
        else
        {
            return typeof(return)();
        }
    }
    else
    {
        result.scopeID = nameToIndex(range);
    }

CopyTail:
    copy(tail[0 .. j + 2], result.address[$ - j - 2 .. $]);
    return typeof(return)(result);
}

@nogc nothrow @safe unittest
{
    {
        ubyte[16] expected = [0, 1, 0, 2, 0, 3, 0, 4, 0, 5, 0, 6, 0, 7, 0, 8];
        auto actual = address6("1:2:3:4:5:6:7:8");
        assert(actual.address == expected);
    }
    {
        ubyte[16] expected;
        auto actual = address6("::");
        assert(actual.address == expected);
    }
    {
        ubyte[16] expected = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1];
        auto actual = address6("::1");
        assert(actual.address == expected);
    }
    {
        ubyte[16] expected = [0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0];
        auto actual = address6("1::");
        assert(actual.address == expected);
    }
}

// Rejects malformed addresses
@nogc nothrow @safe unittest
{
    assert(address6("").isNothing);
    assert(address6(":").isNothing);
    assert(address6(":a").isNothing);
    assert(address6("a:").isNothing);
    assert(address6("1:2:3:4::6:").isNothing);
    assert(address6("1:2:3:4::6:7:8%").isNothing);
}

/**
 * Constructs an $(D_PSYMBOL Address6) from raw bytes in network byte order and
 * the scope ID.
 *
 * Params:
 *  R       = Input range type.
 *  range   = $(D_KEYWORD ubyte) range containing the address.
 *  scopeID = Scope ID.
 *
 * Returns: $(D_PSYMBOL Option) containing the address if the $(D_PARAM range)
 *          contains exactly 16 bytes, or nothing otherwise.
 */
Option!Address6 address6(R)(R range, uint scopeID = 0)
if (isInputRange!R && is(Unqual!(ElementType!R) == ubyte))
{
    Address6 result;
    int i;

    for (; i < 16 && !range.empty; ++i, range.popFront())
    {
        result.address[i] = range.front;
    }
    result.scopeID = scopeID;

    return range.empty && i == 16 ? typeof(return)(result) : typeof(return)();
}

///
@nogc nothrow pure @safe unittest
{
    {
        ubyte[16] actual = [ 1, 2, 3, 4, 5, 6, 7, 8,
                             9, 10, 11, 12, 13, 14, 15, 16 ];
        assert(!address6(actual[]).isNothing);
    }
    {
        ubyte[15] actual = [ 1, 2, 3, 4, 5, 6, 7, 8,
                             9, 10, 11, 12, 13, 14, 15 ];
        assert(address6(actual[]).isNothing);
    }
    {
        ubyte[17] actual = [ 1, 2, 3, 4, 5, 6, 7, 8, 9,
                             10, 11, 12, 13, 14, 15, 16, 17 ];
        assert(address6(actual[]).isNothing);
    }
    {
        assert(address6(cast(ubyte[]) []).isNothing);
    }
}
