/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Internet utilities.
 *
 * Copyright: Eugene Wissner 2016-2017.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 */
module tanya.network.inet;

import std.math;
import std.range.primitives;
import std.traits;

version (unittest)
{
    version (Windows)
    {
        import core.sys.windows.winsock2;
        version = PlattformUnittest;
    }
    else version (Posix)
    {
        import core.sys.posix.arpa.inet;
        version = PlattformUnittest;
    }
}

/**
 * Represents an unsigned integer as an $(D_KEYWORD ubyte) range.
 *
 * The range is bidirectional. The byte order is always big-endian.
 *
 * It can accept any unsigned integral type but the value should fit
 * in $(D_PARAM L) bytes.
 *
 * Params:
 *  L = Desired range length.
 */
struct NetworkOrder(uint L)
    if (L > ubyte.sizeof && L <= ulong.sizeof)
{
    static if (L > uint.sizeof)
    {
        private alias StorageType = ulong;
    }
    else static if (L > ushort.sizeof)
    {
        private alias StorageType = uint;
    }
    else static if (L > ubyte.sizeof)
    {
        private alias StorageType = ushort;
    }
    else
    {
        private alias StorageType = ubyte;
    }

    private StorageType value;
    private size_t size = L;

    const pure nothrow @safe @nogc invariant
    {
        assert(this.size <= L);
    }

    /**
     * Constructs a new range.
     *
     * $(D_PARAM T) can be any unsigned type but $(D_PARAM value) cannot be
     * larger than the maximum can be stored in $(D_PARAM L) bytes. Otherwise
     * an assertion failure will be caused.
     *
     * Params:
     *  T      = Value type.
     *  value  = The value should be represented by this range.
     *
     * Precondition: $(D_INLINECODE value <= 2 ^^ (length * 8) - 1).
     */
    this(T)(const T value)
        if (isUnsigned!T)
    in
    {
        assert(value <= pow(2, L * 8) - 1);
    }
    body
    {
        this.value = value & StorageType.max;
    }

    /**
     * Returns: LSB.
     *
     * Precondition: $(D_INLINECODE length > 0).
     */
    @property ubyte back() const
    in
    {
        assert(this.length > 0);
    }
    body
    {
        return this.value & 0xff;
    }

    /**
     * Returns: MSB.
     *
     * Precondition: $(D_INLINECODE length > 0).
     */
    @property ubyte front() const
    in
    {
        assert(this.length > 0);
    }
    body
    {
        return (this.value >> ((this.length - 1) * 8)) & 0xff;
    }

    /**
     * Eliminates the LSB.
     *
     * Precondition: $(D_INLINECODE length > 0).
     */
    void popBack()
    in
    {
        assert(this.length > 0);
    }
    body
    {
        this.value >>= 8;
        --this.size;
    }

    /**
     * Eliminates the MSB.
     *
     * Precondition: $(D_INLINECODE length > 0).
     */
    void popFront()
    in
    {
        assert(this.length > 0);
    }
    body
    {
        this.value &= StorageType.max >> ((StorageType.sizeof - this.length) * 8);
        --this.size;
    }

    /**
     * Returns: Copy of this range.
     */
    typeof(this) save() const
    {
        return this;
    }

    /**
     * Returns: Whether the range is empty.
     */
    @property bool empty() const
    {
        return this.length == 0;
    }

    /**
     * Returns: Byte length.
     */
    @property size_t length() const
    {
        return this.size;
    }
}

///
pure nothrow @safe @nogc unittest
{
    auto networkOrder = NetworkOrder!3(0xae34e2u);
    assert(!networkOrder.empty);
    assert(networkOrder.front == 0xae);

    networkOrder.popFront();
    assert(networkOrder.length == 2);
    assert(networkOrder.front == 0x34);
    assert(networkOrder.back == 0xe2);

    networkOrder.popBack();
    assert(networkOrder.length == 1);
    assert(networkOrder.front == 0x34);
    assert(networkOrder.front == 0x34);

    networkOrder.popFront();
    assert(networkOrder.empty);
}

// Static.
private unittest
{
    static assert(isBidirectionalRange!(NetworkOrder!4));
    static assert(isBidirectionalRange!(NetworkOrder!8));
    static assert(!is(NetworkOrder!9));
    static assert(!is(NetworkOrder!1));
}

// Tests against the system's htonl, htons.
version (PlattformUnittest)
{
    private unittest
    {
        for (uint counter; counter <= 8 * uint.sizeof; ++counter)
        {
            const value = pow(2, counter) - 1;
            const inNetworkOrder = htonl(value);
            const p = cast(ubyte*) &inNetworkOrder;
            auto networkOrder = NetworkOrder!4(value);

            assert(networkOrder.length == 4);
            assert(!networkOrder.empty);
            assert(networkOrder.front == *p);
            assert(networkOrder.back == *(p + 3));

            networkOrder.popBack();
            assert(networkOrder.length == 3);
            assert(networkOrder.front == *p);
            assert(networkOrder.back == *(p + 2));

            networkOrder.popFront();
            assert(networkOrder.length == 2);
            assert(networkOrder.front == *(p + 1));
            assert(networkOrder.back == *(p + 2));

            networkOrder.popFront();
            assert(networkOrder.length == 1);
            assert(networkOrder.front == *(p + 2));
            assert(networkOrder.back == *(p + 2));

            networkOrder.popBack();
            assert(networkOrder.length == 0);
            assert(networkOrder.empty);
        }

        for (ushort counter; counter <= 8 * ushort.sizeof; ++counter)
        {
            const value = cast(ushort) (pow(2, counter) - 1);
            const inNetworkOrder = htons(value);
            const p = cast(ubyte*) &inNetworkOrder;

            auto networkOrder = NetworkOrder!2(value);

            assert(networkOrder.length == 2);
            assert(!networkOrder.empty);
            assert(networkOrder.front == *p);
            assert(networkOrder.back == *(p + 1));

            networkOrder.popBack();
            assert(networkOrder.length == 1);
            assert(networkOrder.front == *p);
            assert(networkOrder.back == *p);

            networkOrder.popBack();
            assert(networkOrder.length == 0);
            assert(networkOrder.empty);

            networkOrder = NetworkOrder!2(value);

            networkOrder.popFront();
            assert(networkOrder.length == 1);
            assert(networkOrder.front == *(p + 1));
            assert(networkOrder.back == *(p + 1));

            networkOrder.popFront();
            assert(networkOrder.length == 0);
            assert(networkOrder.empty);
        }
    }
}

/**
 * Converts the $(D_KEYWORD ubyte) input range $(D_PARAM range) to
 * $(D_PARAM T).
 *
 * The byte order of $(D_PARAM r) is assumed to be big-endian. The length
 * cannot be larger than $(D_INLINECODE T.sizeof). Otherwise an assertion
 * failure will be caused.
 *
 * Params:
 *  T     = Desired return type.
 *  R     = Range type.
 *  range = Input range.
 *
 * Returns: Integral representation of $(D_PARAM range) with the host byte
 *          order.
 */
T toHostOrder(T = size_t, R)(R range)
    if (isInputRange!R
     && !isInfinite!R
     && is(Unqual!(ElementType!R) == ubyte)
     && isUnsigned!T)
{
    T ret;
    ushort pos = T.sizeof * 8;

    for (; !range.empty && range.front == 0; pos -= 8, range.popFront())
    {
    }
    for (; !range.empty; range.popFront())
    {
        assert(pos != 0);
        pos -= 8;
        ret |= (cast(T) range.front) << pos;
    }

    return ret >> pos;
}

///
pure nothrow @safe @nogc unittest
{
    const value = 0xae34e2u;
    auto networkOrder = NetworkOrder!4(value);
    assert(networkOrder.toHostOrder() == value);
}

// Tests against the system's htonl, htons.
version (PlattformUnittest)
{
    private unittest
    {
        for (uint counter; counter <= 8 * uint.sizeof; ++counter)
        {
            const value = pow(2, counter) - 1;
            const inNetworkOrder = htonl(value);
            const p = cast(ubyte*) &inNetworkOrder;
            auto networkOrder = NetworkOrder!4(value);

            assert(p[0 .. uint.sizeof].toHostOrder() == value);
        }
        for (ushort counter; counter <= 8 * ushort.sizeof; ++counter)
        {
            const value = cast(ushort) (pow(2, counter) - 1);
            const inNetworkOrder = htons(value);
            const p = cast(ubyte*) &inNetworkOrder;
            auto networkOrder = NetworkOrder!2(value);

            assert(p[0 .. ushort.sizeof].toHostOrder() == value);
        }
    }
}
