/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Internet utilities.
 *
 * Copyright: Eugene Wissner 2016-2019.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/net/inet.d,
 *                 tanya/net/inet.d)
 */
module tanya.net.inet;

import tanya.meta.trait;
import tanya.meta.transform;
import tanya.range;

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

    invariant
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
     * Precondition: $(D_INLINECODE value <= (2 ^^ (L * 8)) - 1).
     */
    this(T)(T value)
    if (isUnsigned!T)
    in (value <= (2 ^^ (L * 8)) - 1)
    {
        this.value = value & StorageType.max;
    }

    /**
     * Returns: LSB.
     *
     * Precondition: $(D_INLINECODE length > 0).
     */
    @property ubyte back() const
    in (this.length > 0)
    {
        return this.value & 0xff;
    }

    /**
     * Returns: MSB.
     *
     * Precondition: $(D_INLINECODE length > 0).
     */
    @property ubyte front() const
    in (this.length > 0)
    {
        return (this.value >> ((this.length - 1) * 8)) & 0xff;
    }

    /**
     * Eliminates the LSB.
     *
     * Precondition: $(D_INLINECODE length > 0).
     */
    void popBack()
    in (this.length > 0)
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
    in (this.length > 0)
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
@nogc nothrow pure @safe unittest
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
@nogc nothrow pure @safe unittest
{
    const value = 0xae34e2u;
    auto networkOrder = NetworkOrder!4(value);
    assert(networkOrder.toHostOrder() == value);
}
