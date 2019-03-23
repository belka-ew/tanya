/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Internet Protocol implementation.
 *
 * Copyright: Eugene Wissner 2018-2019.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/net/ip.d,
 *                 tanya/net/ip.d)
 */
module tanya.net.ip;

import tanya.algorithm.comparison;
import tanya.algorithm.iteration;
import tanya.algorithm.mutation;
import tanya.container.string;
import tanya.conv;
import tanya.encoding.ascii;
import tanya.format;
import tanya.memory.lifetime;
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
    this(uint address) @nogc nothrow pure @trusted
    {
        copy(NetworkOrder!4(address), (cast(ubyte*) &this.address)[0 .. 4]);
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        assert(Address4(0x00202000U).toUInt() == 0x00202000U);
    }

    /**
     * Compares two $(D_PARAM Address4) objects.
     *
     * Params:
     *  that = Another address.
     *
     * Returns: Positive number if $(D_KEYWORD this) is larger than
     *          $(D_PARAM that), negative - if it is smaller, or 0 if they
     *          equal.
     */
    int opCmp(ref const Address4 that) const @nogc nothrow pure @safe
    {
        const lhs = toUInt();
        const rhs = that.toUInt();
        return (rhs < lhs) - (lhs < rhs);
    }

    /// ditto
    int opCmp(const Address4 that) const @nogc nothrow pure @safe
    {
        return opCmp(that);
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        assert(address4("127.0.0.1") > address4("126.0.0.0"));
        assert(address4("127.0.0.1") < address4("127.0.0.2"));
        assert(address4("127.0.0.1") == address4("127.0.0.1"));
    }

    /**
     * Returns object that represents 127.0.0.1.
     *
     * Returns: Object that represents the Loopback address.
     */
    static @property Address4 loopback() @nogc nothrow pure @safe
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
    static @property Address4 any() @nogc nothrow pure @safe
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
        assert(address4("127.0.0.1").get.isLoopback());
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
        assert(address4("0.0.0.0").get.isAny());
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
        assert(address4("255.255.255.255").get.isBroadcast());
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
        assert(address4("224.0.0.3").get.isMulticast());
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
        assert(address4("192.168.0.1").get.isUnicast());
    }

    /**
     * Produces a string containing an IPv4 address in dotted-decimal notation.
     *
     * Returns: This address in dotted-decimal notation.
     */
    deprecated("Use Address4.toString() instead")
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

    /**
     * Writes this IPv4 address in dotted-decimal notation.
     *
     * Params:
     *  OR     = Type of the output range.
     *  output = Output range.
     *
     * Returns: $(D_PARAM output).
     */
    OR toString(OR)(OR output) const @nogc nothrow pure @safe
    if (isOutputRange!(OR, const(char)[]))
    {
        const octets = (() @trusted => (cast(ubyte*) &this.address)[0 .. 4])();
        enum string fmt = "{}.{}.{}.{}";
        version (LittleEndian)
        {
            return sformat!fmt(output,
                               octets[0],
                               octets[1],
                               octets[2],
                               octets[3]);
        }
        else
        {
            return sformat!fmt(output,
                               octets[3],
                               octets[2],
                               octets[1],
                               octets[0]);
        }
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        import tanya.container.string : String;
        import tanya.range : backInserter;

        const dottedDecimal = "192.168.0.1";
        String actual;
        const address = address4(dottedDecimal);

        address.get.toString(backInserter(actual));
        assert(actual == dottedDecimal);
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
        assert(actual.get.toBytes() == expected);
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
        assert(address4("127.0.0.1").get.toUInt() == 0x7f000001U);
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
        assert(address4(actual[]).get.isLoopback());
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
     * Compares two $(D_PARAM Address6) objects.
     *
     * If $(D_KEYWORD this) and $(D_PARAM that) contain the same address, scope
     * IDs are compared.
     *
     * Params:
     *  that = Another address.
     *
     * Returns: Positive number if $(D_KEYWORD this) is larger than
     *          $(D_PARAM that), negative - if it is smaller, or 0 if they
     *          equal.
     */
    int opCmp(ref const Address6 that) const @nogc nothrow pure @safe
    {
        const diff = compare(this.address[], that.address[]);
        if (diff == 0)
        {
            return (that.scopeID < this.scopeID) - (this.scopeID < that.scopeID);
        }
        return diff;
    }

    /// ditto
    int opCmp(const Address6 that) const @nogc nothrow pure @safe
    {
        return opCmp(that);
    }

    ///
    @nogc nothrow @safe unittest
    {
        assert(address6("::14") > address6("::1"));
        assert(address6("::1") < address6("::14"));
        assert(address6("::1") == address6("::1"));
        assert(address6("fe80::1%1") < address6("fe80::1%2"));
        assert(address6("fe80::1%2") > address6("fe80::1%1"));
    }

    /**
     * Returns object that represents ::.
     *
     * Returns: Object that represents any address.
     */
    static @property Address6 any() @nogc nothrow pure @safe
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
    static @property Address6 loopback() @nogc nothrow pure @safe
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
        assert(address6("::").get.isAny());
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
        assert(address6("::1").get.isLoopback());
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
        assert(address6("ff00::").get.isMulticast());
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
        assert(address6("::1").get.isUnicast());
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
        assert(address6("fe80::1").get.isLinkLocal());
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
        assert(address6("fd80:124e:34f3::1").get.isUniqueLocal());
    }

    /**
     * Returns text representation of this address.
     *
     * Returns: text representation of this address.
     */
    deprecated("Use Address6.toString() instead")
    String stringify() const @nogc nothrow pure @safe
    {
        String output;

        toString(backInserter(output));
        return output;
    }

    /**
     * Writes text representation of this address to an output range.
     *
     * Params:
     *  OR     = Type of the output range.
     *  output = Output range.
     *
     * Returns: $(D_PARAM output).
     */
    OR toString(OR)(OR output) const
    if (isOutputRange!(OR, const(char)[]))
    {
        ptrdiff_t largestGroupIndex = -1;
        size_t largestGroupSize;
        size_t zeroesInGroup;
        size_t groupIndex;

        // Look for the longest group of zeroes
        for (size_t i; i < this.address.length; i += 2)
        {
            if (this.address[i] == 0 && this.address[i + 1] == 0)
            {
                if (zeroesInGroup++ == 0)
                {
                    groupIndex = i;
                }
            }
            else
            {
                zeroesInGroup = 0;
            }
            if (zeroesInGroup > largestGroupSize && zeroesInGroup > 1)
            {
                largestGroupSize = zeroesInGroup;
                largestGroupIndex = groupIndex;
            }
        }

        // Write the address
        size_t i;
        if (largestGroupIndex != 0)
        {
            writeGroup(output, i);
        }
        if (largestGroupIndex != -1)
        {
            while (i < largestGroupIndex)
            {
                put(output, ":");
                writeGroup(output, i);
            }
            put(output, "::");
            i += largestGroupSize + 2;
            if (i < (this.address.length - 1))
            {
                writeGroup(output, i);
            }
        }

        while (i < this.address.length - 1)
        {
            put(output, ":");
            writeGroup(output, i);
        }

        return output;
    }

    ///
    @nogc nothrow @safe unittest
    {
        import tanya.container.string : String;
        import tanya.range : backInserter;

        String actual;

        address6("1:2:3:4:5:6:7:8").get.toString(backInserter(actual));
        assert(actual == "1:2:3:4:5:6:7:8");
    }

    private void writeGroup(OR)(ref OR output, ref size_t i) const
    {
        ubyte low = this.address[i] & 0xf;
        ubyte high = this.address[i] >> 4;

        bool groupStarted = writeHexDigit!OR(output, high);
        groupStarted = writeHexDigit!OR(output, low, groupStarted);

        ++i;
        low = this.address[i] & 0xf;
        high = this.address[i] >> 4;

        writeHexDigit!OR(output, high, groupStarted);
        put(output, low.toHexDigit.singleton);
        ++i;
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
        assert(actual.get.toBytes() == expected);
    }
}

private void read2Bytes(R)(ref R range, ubyte[] address)
{
    ushort group = readIntegral!ushort(range, 16);
    address[0] = cast(ubyte) (group >> 8);
    address[1] = group & 0xff;
}

private char toHexDigit(ubyte digit) @nogc nothrow pure @safe
in (digit < 16)
{
    return cast(char) (digit >= 10 ? (digit - 10 + 'a') : (digit + '0'));
}

private bool writeHexDigit(OR)(ref OR output,
                               ubyte digit,
                               bool groupStarted = false)
in (digit < 16)
{
    if (digit != 0 || groupStarted)
    {
        put(output, digit.toHexDigit.singleton);
        return true;
    }
    return groupStarted;
}

/**
 * Parses a string containing an IPv6 address.
 *
 * This function isn't pure since an IPv6 address can contain interface name
 * or interface ID (separated from the address by `%`). If an interface name
 * is specified (i.e. first character after `%` is not a digit), the parser
 * tries to convert it to the ID of that interface. If the interface with the
 * given name can't be found, the parser doesn't fail, but just ignores the
 * invalid interface name, scope ID is `0` then.
 *
 * If an ID is given (i.e. first character after `%` is a digit),
 * $(D_PSYMBOL address6) just stores it in $(D_PSYMBOL Address6.scopeID) without
 * checking whether an interface with this ID really exists. If the ID is
 * invalid (if it is too long or contains non decimal characters), parsing
 * fails and nothing is returned.
 *
 * If neither an ID nor a name is given, $(D_PSYMBOL Address6.scopeID) is set
 * to `0`.
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
    static foreach (i; 0 .. 7)
    {
        { // To make "state" definition local
            static if (i == 6) // Can be embedded IPv4
            {
                auto state = range.save();
            }
            read2Bytes(range, result.address[i * 2 .. $]);
            if (range.empty)
            {
                return typeof(return)();
            }
            static if (i == 6)
            {
                if (range.front == '.')
                {
                    swap(range, state);
                    goto ParseIPv4;
                }
            }
            if (range.front != ':')
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
    }
    read2Bytes(range, result.address[14 .. $]);

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
    { // To make "state" definition local
        auto state = range.save();

        read2Bytes(range, tail[j .. $]);
        if (range.empty)
        {
            goto CopyTail;
        }
        else if (range.front == '%')
        {
            goto ParseIface;
        }
        else if (range.front == '.')
        {
            swap(range, state);
            goto ParseIPv4;
        }
        else if (range.front != ':')
        {
            return typeof(return)();
        }
        range.popFront();
    }

    j = 2;
    for (size_t i = 2; i <= 11; i += 2, j += 2, range.popFront())
    {
        if (range.empty || range.front == ':')
        {
            return typeof(return)();
        }
        auto state = range.save();
        read2Bytes(range, tail[j .. $]);

        if (range.empty)
        {
            goto CopyTail;
        }
        else if (range.front == '%')
        {
            goto ParseIface;
        }
        else if (range.front == '.')
        {
            swap(range, state);
            goto ParseIPv4;
        }
        else if (range.front != ':')
        {
            return typeof(return)();
        }
    }

ParseIPv4:
    // We know there is a number followed by '.'. We have to ensure this number
    // is an octet
    tail[j] = readIntegral!ubyte(range);
    static foreach (i; 1 .. 4)
    {
        if (range.empty || range.front != '.')
        {
            return typeof(return)();
        }
        range.popFront();
        if (range.empty)
        {
            return typeof(return)();
        }
        tail[j + i] = readIntegral!ubyte(range);
    }
    j += 2;

    if (range.empty)
    {
        goto CopyTail;
    }
    else if (range.front != '%')
    {
        return typeof(return)();
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

/**
 * Address storage, that can hold either an IPv4 or IPv6 address.
 */
struct Address
{
    private Variant!(Address4, Address6) address;

    @disable this();

    /**
     * Initializes the addres with an IPv4 address.
     *
     * Params:
     *  address = IPv6 address.
     */
    this(Address4 address) @nogc nothrow pure @safe
    {
        this.address = address;
    }

    /**
     * Initializes the addres with an IPv4 address.
     *
     * Params:
     *  address = IPv6 address.
     */
    this(Address6 address) @nogc nothrow pure @safe
    {
        this.address = address;
    }

    /**
     * Determines whether this is an IPv4 address.
     *
     * Returns: $(D_KEYWORD true) if this is an IPv4 address,
     *          $(D_KEYWORD false) otherwise.
     */
    bool isV4() const @nogc nothrow pure @safe
    {
        return this.address.peek!Address4;
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        assert(Address(Address4.any()).isV4());
    }

    /**
     * Determines whether this is an IPv6 address.
     *
     * Returns: $(D_KEYWORD true) if this is an IPv6 address,
     *          $(D_KEYWORD false) otherwise.
     */
    bool isV6() const @nogc nothrow pure @safe
    {
        return this.address.peek!Address6;
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        assert(Address(Address6.any()).isV6());
    }

    /**
     * Get the address as an IPv4 address.
     *
     * This method doesn't convert the address, so the address should be
     * already an IPv4 one.
     *
     * Returns: IPv4 address.
     *
     * Precondition: This is an IPv4 address.
     */
    ref inout(Address4) toV4() inout @nogc nothrow pure @safe
    in (this.address.peek!Address4)
    {
        return this.address.get!Address4;
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        auto expected = Address4.loopback;
        assert(Address(expected).toV4() == expected);
    }

    /**
     * Get the address as an IPv6 address.
     *
     * This method doesn't convert the address, so the address should be
     * already an IPv6 one.
     *
     * Returns: IPv6 address.
     *
     * Precondition: This is an IPv6 address.
     */
    ref inout(Address6) toV6() inout @nogc nothrow pure @safe
    in (this.address.peek!Address6)
    {
        return this.address.get!Address6;
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        auto expected = Address6.loopback;
        assert(Address(expected).toV6() == expected);
    }

    /**
     * Determines whether this is a loopback address.
     *
     * Returns: $(D_KEYWORD true) if this is a loopback address,
     *          $(D_KEYWORD false) otherwise.
     *
     * See_Also: $(D_PSYMBOL Address4.loopback),
     *           $(D_PSYMBOL Address6.loopback).
     */
    bool isLoopback() const @nogc nothrow pure @safe
    in (this.address.hasValue)
    {
        if (this.address.peek!Address4)
        {
            return this.address.get!Address4.isLoopback();
        }
        return this.address.get!Address6.isLoopback();
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        assert(Address(Address4.loopback()).isLoopback());
        assert(Address(Address6.loopback()).isLoopback());
    }

    /**
     * Determines whether this address' destination is a group of endpoints.
     *
     * Returns: $(D_KEYWORD true) if this is a multicast address,
     *          $(D_KEYWORD false) otherwise.
     *
     * See_Also: $(D_PSYMBOL Address4.isMulticast),
     *           $(D_PSYMBOL Address6.isMulticast).
     */
    bool isMulticast() const @nogc nothrow pure @safe
    in (this.address.hasValue)
    {
        if (this.address.peek!Address4)
        {
            return this.address.get!Address4.isMulticast();
        }
        return this.address.get!Address6.isMulticast();
    }

    ///
    @nogc nothrow @safe unittest
    {
        assert(Address(address4("224.0.0.3").get).isMulticast());
        assert(Address(address6("ff00::").get).isMulticast());
    }

    /**
     * Determines whether this is an unspecified address.
     *
     * Returns: $(D_KEYWORD true) if this is an unspecified address,
     *          $(D_KEYWORD false) otherwise.
     *
     * See_Also: $(D_PSYMBOL Address4.isAny), $(D_PSYMBOL Address6.isAny).
     */
    bool isAny() const @nogc nothrow pure @safe
    in (this.address.hasValue)
    {
        if (this.address.peek!Address4)
        {
            return this.address.get!Address4.isAny();
        }
        return this.address.get!Address6.isAny();
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        assert(Address(Address4.any).isAny());
        assert(Address(Address6.any).isAny());
    }

    /**
     * Compares two addresses for equality.
     *
     * Params:
     *  T    = The type of the other address. It can be $(D_PSYMBOL Address),
     *         $(D_PSYMBOL Address4) or $(D_PSYMBOL Address6).
     *  that = The address to compare with.
     *
     * Returns: $(D_KEYWORD true) if this and $(D_PARAM that) addresses are
     *          representations of the same IP address, $(D_KEYWORD false)
     *          otherwise.
     */
    bool opEquals(T)(T that) const
    if (is(Unqual!T == Address4) || is(Unqual!T == Address6))
    {
        alias AddressType = Unqual!T;
        if (this.address.peek!AddressType)
        {
            return this.address.get!AddressType == that;
        }
        return false;
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        assert(Address(Address4.loopback) == Address4.loopback);
        assert(Address(Address6.loopback) == Address6.loopback);
        assert(Address(Address4.loopback) != Address6.loopback);
    }

    /// ditto
    bool opEquals(T)(T that) const
    if (is(Unqual!T == Address))
    {
        return this.address == that.address;
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        assert(Address(Address6.loopback) == Address(Address6.loopback));
        assert(Address(Address4.loopback) != Address(Address6.loopback));
    }

    ref Address opAssign(T)(T that)
    if (is(Unqual!T == Address4) || is(Unqual!T == Address6))
    {
        this.address = that;
        return this;
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        Address address = Address4.any;
        address = Address4.loopback;
        assert(address == Address4.loopback);
    }
}
