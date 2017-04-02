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

import std.algorithm.comparison;
import std.traits;

version (assert)
{
    import std.math;
}

version (unittest)
{
    import std.math;
    import std.range.primitives;

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
 */
struct NetworkOrder
{
    private uint value;
    private size_t size;

    const pure nothrow @safe @nogc invariant
    {
        assert(this.size <= uint.sizeof);
    }

    /**
     * Constructs a new range.
     *
     * $(D_PARAM T) can be any unsigned type but $(D_PARAM value) shouldn't be
     * larger than the maximum can be stored in $(D_PARAM length) bytes.
     * Otherwise an assertion failure will be caused.
     *
     * If $(D_PARAM length) isn't specified, it is inferred from the
     * $(D_INLINECODE T.sizeof).
     *
     * If $(D_PARAM T) is $(D_KEYWORD ulong), $(D_PARAM value) should be less
     * than or equal to $(D_INLINECODE uint.max).
     *
     * Params:
     *  T      = Value type.
     *  value  = The value should be iterated over.
     *  length = $(D_PARAM value) size in bytes.
     *
     * Precondition: $(D_INLINECODE length < uint.sizeof
     *                           && value <= 2 ^ (length * 8) - 1).
     */
    this(T)(const T value, const size_t length)
        if (isIntegral!T)
    in
    {
        assert(length <= uint.sizeof);
        assert(value >= 0);
        assert(value <= pow(2, length * 8) - 1);
    }
    body
    {
        this.value = value & uint.max;
        this.size = length;
    }

    /// Ditto.
    this(T)(const T value)
        if (isIntegral!T)
    {
        this(value, min(T.sizeof, uint.sizeof));
    }

    /**
     * Returns: LSB.
     *
     * Precondition: $(D_INLINECODE length > 0).
     */
    @property ubyte back() const pure nothrow @safe @nogc
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
    @property ubyte front() const pure nothrow @safe @nogc
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
    void popBack() pure nothrow @safe @nogc
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
    void popFront() pure nothrow @safe @nogc
    in
    {
        assert(this.length > 0);
    }
    body
    {
        this.value &= uint.max >> ((4 - this.length) * 8);
        --this.size;
    }

    /**
     * Returns: Copy of this range.
     */
    typeof(this) save() const pure nothrow @safe @nogc
    {
        return this;
    }

    /**
     * Returns: Whether the range is empty.
     */
    @property bool empty() const pure nothrow @safe @nogc
    {
        return this.length == 0;
    }

    /**
     * Returns: Byte length.
     */
    @property size_t length() const pure nothrow @safe @nogc
    {
        return this.size;
    }
}

///
pure nothrow @safe @nogc unittest
{
    auto networkOrder = NetworkOrder(0xae34e2u, 3);
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
    static assert(isBidirectionalRange!NetworkOrder);
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
            auto networkOrder = NetworkOrder(value);

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

            auto networkOrder = NetworkOrder(value);

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

            networkOrder = NetworkOrder(value);

            networkOrder.popFront();
            assert(networkOrder.length == 1);
            assert(networkOrder.front == *(p + 1));
            assert(networkOrder.back == *(p + 1));

            networkOrder.popFront();
            assert(networkOrder.length == 0);
            assert(networkOrder.empty);
        }

        auto networkOrder = NetworkOrder(255u, 1);
        assert(networkOrder.length == 1);
        assert(!networkOrder.empty);
        assert(networkOrder.front == 0xff);
        assert(networkOrder.back == 0xff);

        networkOrder.popFront();
        assert(networkOrder.length == 0);
        assert(networkOrder.empty);
    }
}
