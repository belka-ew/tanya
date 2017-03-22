/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Arbitrary precision arithmetic.
 *
 * Copyright: Eugene Wissner 2016-2017.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 */
module tanya.math.mp;

import core.exception;
import std.algorithm;
import std.range;
import std.traits;
import tanya.math;
import tanya.memory;

/**
 * Algebraic sign.
 */
enum Sign : bool
{
    /// The value is positive or `0`.
    positive = false,

    /// The value is negative.
    negative = true,
}

/**
 * Mutliple precision integer.
 */
struct Integer
{
    private size_t size;
    package ubyte* rep;
    package Sign sign;

    pure nothrow @safe @nogc invariant
    {
        assert(this.size > 0 || !this.sign, "0 should be positive.");
    }

    /**
     * Creates a multiple precision integer.
     *
     * Params:
     *  T         = Value type.
     *  value     = Initial value.
     *  allocator = Allocator.
     *
     * Precondition: $(D_INLINECODE allocator !is null)
     */
    this(T)(const T value, shared Allocator allocator = defaultAllocator)
        if (isIntegral!T)
    {
        this(allocator);
        assign(value);
    }

    /// Ditto.
    this(const ref Integer value, shared Allocator allocator = defaultAllocator)
    nothrow @safe @nogc
    {
        this(allocator);
        assign(value);
    }

    /// Ditto.
    this(Integer value, shared Allocator allocator = defaultAllocator)
    nothrow @safe @nogc
    {
        this(allocator);
        if (allocator is value.allocator)
        {
            this.rep = value.rep;
            this.size = value.size;
            this.sign = value.sign;
            value.rep = null;
            value.size = 0;
            value.sign = Sign.positive;
        }
        else
        {
            assign(value);
        }
    }

    /// Ditto.
    this(shared Allocator allocator) pure nothrow @safe @nogc
    in
    {
        assert(allocator !is null);
    }
    body
    {
        this.allocator_ = allocator;
    }

    private @nogc unittest
    {
        {
            auto integer = Integer(79);
            assert(integer.length == 1);
            assert(integer.rep[0] == 79);
            assert(!integer.sign);
        }
        {
            auto integer = Integer(-2);
            assert(integer.length == 1);
            assert(integer.rep[0] == 2);
            assert(integer.sign);
        }
    }

    /**
     * Constructs the integer from a sign-magnitude $(D_KEYWORD ubyte) range.
     *
     * Params:
     *  R         = Range type.
     *  sign      = Sign.
     *  value     = Range.
     *  allocator = Allocator.
     *
     * Precondition: $(D_INLINECODE allocator !is null)
     */
    this(R)(const Sign sign, R value, shared Allocator allocator = defaultAllocator)
        if (isInputRange!R && hasLength!R && is(Unqual!(ElementType!R) == ubyte))
    out
    {
        assert(this.size == 0 || this.rep[0] > 0);
    }
    body
    {
        this(allocator);
        while (!value.empty && value.front == 0)
        {
            value.popFront();
        }
        this.rep = allocator.resize(this.rep[0 .. this.size], value.length).ptr;
        this.size = value.length;
        this.sign = sign;
        value.copy(this.rep[0 .. this.size]);
    }

    /**
     * Copies the integer.
     */
    this(this) nothrow @trusted @nogc
    {
        auto tmp = allocator.resize!ubyte(null, this.size);
        this.rep[0 .. this.size].copy(tmp);
        this.rep = tmp.ptr;
    }

    /**
     * Destroys the integer.
     */
    ~this() nothrow @trusted @nogc
    {
        allocator.deallocate(this.rep[0 .. this.size]);
    }

    /*
     * Figures out the minimum amount of space this value will take
     * up in bytes and resizes the internal storage. Sets the sign.
     */
    private void assign(T)(const ref T value) @trusted
        if (isIntegral!T)
    {
        ubyte size = ulong.sizeof;
        ulong mask;

        this.sign = Sign.positive; // Reset the sign.
        static if (isSigned!T)
        {
            const absolute = value.abs;
        }
        else
        {
            alias absolute = value;
        }
        for (mask = 0xff00000000000000; mask >= 0xff; mask >>= 8)
        {
            if (absolute & mask)
            {
                break;
            }
            --size;
        }

        this.rep = allocator.resize(this.rep[0 .. this.size], size).ptr;
        this.size = size;
        static if (isSigned!T)
        {
            this.sign = value < 0 ? Sign.negative : Sign.positive;
        }

        /* Work backward through the int, masking off each byte (up to the
           first 0 byte) and copy it into the internal representation in
           big-endian format. */
        mask = 0xff;
        ubyte shift;
        for (auto i = this.size; i; --i, mask <<= 8, shift += 8)
        {
            this.rep[i - 1] = cast(ubyte) ((absolute & mask) >> shift);
        }
    }

    private void assign(const ref Integer value) nothrow @trusted @nogc
    {
        this.rep = allocator.resize(this.rep[0 .. this.size], value.size).ptr;
        this.size = value.size;
        this.sign = value.sign;
        value.rep[0 .. value.size].copy(this.rep[0 .. this.size]);
    }

    /**
     * Returns: Integer size.
     */
    @property size_t length() const pure nothrow @safe @nogc
    {
        return this.size;
    }

    /**
     * Assigns a new value.
     *
     * Params:
     *  T     = Value type.
     *  value = Value.
     *
     * Returns: $(D_KEYWORD this).
     */
    ref Integer opAssign(T)(const T value)
        if (isIntegral!T)
    {
        assign(value);
        return this;
    }

    /// Ditto.
    ref Integer opAssign(const ref Integer value) nothrow @safe @nogc
    {
        assign(value);
        return this;
    }

    /// Ditto.
    ref Integer opAssign(Integer value) nothrow @safe @nogc
    {
        swap(this.rep, value.rep);
        swap(this.sign, value.sign);
        swap(this.size, value.size);
        return this;
    }

    private @nogc unittest
    {
        auto integer = Integer(1019);
        assert(integer.length == 2);
        assert(integer.rep[0] == 0b00000011 && integer.rep[1] == 0b11111011);

        integer = 3337;
        assert(integer.length == 2);
        assert(integer.rep[0] == 0b00001101 && integer.rep[1] == 0b00001001);

        integer = 688;
        assert(integer.length == 2);
        assert(integer.rep[0] == 0b00000010 && integer.rep[1] == 0b10110000);

        integer = 0;
        assert(integer.length == 0);
    }

    /*
     * Extend the space for this by 1 byte and set the LSB to 1.
     */
    private void expand() nothrow @trusted @nogc
    {
        rep = allocator.resize(this.rep[0 .. this.size], this.size + 1).ptr;
        ++this.size;
        auto target = this.rep[1 .. this.size].retro;
        this.rep[0 .. this.size - 1].retro.copy(target);
        this.rep[0] = 0x01;
    }

    /*
     * Go through this and see how many of the left-most bytes are unused.
     * Remove them and resize this appropriately.
     */
    private void contract() nothrow @trusted @nogc
    {
        const i = this.rep[0 .. this.size].countUntil!((const ref a) => a != 0);

        if (i > 0)
        {
            this.rep[i .. this.size].copy(this.rep[0 .. this.size - i]);
            this.rep = allocator.resize(this.rep[0 .. this.size], this.size - i).ptr;
            this.size -= i;
        }
        else if (i == -1)
        {
            this.sign = Sign.positive;
            this.rep = allocator.resize(this.rep[0 .. this.size], 0).ptr;
            this.size = 0;
        }
    }

    private void add(const ref Integer summand) nothrow @trusted @nogc
    {
        if (summand.length > this.length)
        {
            const delta = summand.size - this.size;
            auto tmp = this.rep[0 .. this.size];

            this.rep =  allocator.resize!ubyte(null, summand.size).ptr;
            tmp.copy(this.rep[delta .. summand.size]);
            this.rep[0 .. delta].initializeAll();

            allocator.deallocate(tmp[0 .. this.size]);
            this.size = summand.size;
        }

        bool carry;
        size_t i = this.size;
        size_t j = summand.size;
        do
        {
            uint sum;
            --i;
            if (j)
            {
                --j;
                sum = this.rep[i] + summand.rep[j] + carry;
            }
            else
            {
                sum = this.rep[i] + carry;
            }

            carry = sum > 0xff;
            this.rep[i] = cast(ubyte) sum;
        }
        while (i);

        if (carry)
        {
            // Still overflowed; allocate more space
            expand();
        }
    }

    private void subtract(const ref Integer subtrahend) nothrow @trusted @nogc
    {
        size_t i = this.size;
        size_t j = subtrahend.size;
        bool borrow;

        while (i)
        {
            int difference;
            --i;

            if (j)
            {
                --j;
                difference = this.rep[i] - subtrahend.rep[j] - borrow;
            }
            else
            {
                difference = this.rep[i] - borrow;
            }
            borrow = difference < 0;
            this.rep[i] = cast(ubyte) difference;
        }

        if (borrow && i > 0)
        {
            if (this.rep[i - 1]) // Don't borrow i
            {
                --this.rep[i - 1];
            }
        }
        contract();
    }

    private int compare(const ref Integer that) const nothrow @trusted @nogc
    {
        if (this.length > that.length)
        {
            return 1;
        }
        else if (this.length < that.length)
        {
            return -1;
        }
        return this.rep[0 .. this.size].cmp(that.rep[0 .. that.size]);
    }

    /**
     * Comparison.
     *
     * Params:
     *  that = The second integer.
     *
     * Returns: A positive number if $(D_INLINECODE this > that), a negative
     *          number if $(D_INLINECODE this < that), `0` otherwise.
     */
    int opCmp(I : Integer)(const auto ref I that) const
    {
        if (this.sign != that.sign)
        {
            return this.sign ? -1 : 1;
        }
        return compare(that);
    }

    ///
    @safe @nogc unittest
    {
        auto integer1 = Integer(1019);
        auto integer2 = Integer(1019);
        assert(integer1 == integer2);

        integer2 = 3337;
        assert(integer1 < integer2);

        integer2 = 688;
        assert(integer1 > integer2);

        integer2 = -3337;
        assert(integer1 > integer2);
    }

    /// Ditto.
    int opCmp(I)(const auto ref I that) const
        if (isIntegral!I)
    {
        if (that < 0 && !this.sign)
        {
            return 1;
        }
        else if (that > 0 && this.sign)
        {
            return -1;
        }
        else if (this.length > I.sizeof)
        {
            return this.sign ? -1 : 1;
        }

        const diff = (cast(I) this) - that;
        if (diff > 0)
        {
            return 1;
        }
        else if (diff < 0)
        {
            return -1;
        }
        return 0;
    }

    ///
    @safe @nogc unittest
    {
        auto integer = Integer(1019);

        assert(integer == 1019);
        assert(integer < 3337);
        assert(integer > 688);
        assert(integer > -3337);
    }

    /**
     * Params:
     *  that = The second integer.
     *
     * Returns: Whether the two integers are equal.
     */
    bool opEquals(I)(const auto ref I that) const
        if (is(I : Integer) || isIntegral!I)
    {
        return opCmp!I(that) == 0;
    }

    ///
    @safe @nogc unittest
    {
        auto integer = Integer(1019);

        assert(integer == Integer(1019));
        assert(integer != Integer(109));
    }

    /**
     * Assignment operators with another $(D_PSYMBOL Integer).
     *
     * Params:
     *  op      = Operation.
     *  operand = The second operand.
     *
     * Returns: $(D_KEYWORD this).
     */
    ref Integer opOpAssign(string op : "+")(const auto ref Integer operand)
    out
    {
        assert(this.size == 0 || this.rep[0] > 0);
    }
    body
    {
        if (this.sign == operand.sign)
        {
            add(operand);
        }
        else
        {
            if (this >= operand)
            {
                subtract(operand);
            }
            else
            {
                // Swap the operands.
                auto tmp = Integer(this, this.allocator);
                this = Integer(operand, this.allocator);
                subtract(tmp);
                this.sign = operand.sign;
            }

        }
        return this;
    }

    private unittest
    {
        {
            auto h1 = Integer(1019);
            auto h2 = Integer(3337);
            h1 += h2;
            assert(h1.length == 2);
            assert(h1.rep[0] == 0x11 && h1.rep[1] == 0x04);
        }
        {
            auto h1 = Integer(4356);
            auto h2 = Integer(2_147_483_647);
            ubyte[4] expected = [0x80, 0x00, 0x11, 0x03];
            h1 += h2;
            assert(h1.rep[0 .. h1.size] == expected);
        }
        {
            auto h1 = Integer(2147488003L);
            auto h2 = Integer(2_147_483_647);
            ubyte[5] expected = [0x01, 0x00, 0x00, 0x11, 0x02];
            h1 += h2;
            assert(h1.rep[0 .. h1.size] == expected);
        }
    }

    /// Ditto.
    ref Integer opOpAssign(string op : "-")(const auto ref Integer operand)
    out
    {
        assert(this.size == 0 || this.rep[0] > 0);
    }
    body
    {
        if (operand.sign == this.sign)
        {
            if (this >= operand)
            {
                subtract(operand);
            }
            else
            {
                // Swap the operands.
                auto tmp = Integer(this, this.allocator);
                this = Integer(operand, this.allocator);
                subtract(tmp);

                if (operand.sign || this.size == 0)
                {
                    this.sign = Sign.positive;
                }
                else
                {
                    this.sign = Sign.negative;
                }
            }
        }
        else
        {
            add(operand);
        }
        return this;
    }

    private @nogc unittest
    {
        {
            auto h1 = Integer(3);
            auto h2 = Integer(4);
            h1 -= h2;
            assert(h1.length == 1);
            assert(h1.rep[0] == 0x01);
            assert(h1.sign);
        }
        {
            auto h1 = Integer(8589934590L);
            auto h2 = Integer(2147483647);
            ubyte[5] expected = [0x01, 0x7f, 0xff, 0xff, 0xff];

            h1 -= h2;
            assert(h1.rep[0 .. h1.size] == expected);
        }
        {
            auto h1 = Integer(6442450943);
            auto h2 = Integer(4294967294);
            ubyte[4] expected = [0x80, 0x00, 0x00, 0x01];
            h1 -= h2;
            assert(h1.rep[0 .. h1.size] == expected);
        }
        {
            auto h1 = Integer(2147483649);
            auto h2 = Integer(h1);
            h1 -= h2;
            assert(h1.length == 0);
        }
    }

    /// Ditto.
    ref Integer opOpAssign(string op : "*")(const auto ref Integer operand) @trusted
    out
    {
        assert(this.size == 0 || this.rep[0] > 0);
    }
    body
    {
        size_t i = operand.size;
        if (this.length == 0)
        {
            return this;
        }
        else if (i == 0)
        {
            this = 0;
            return this;
        }
        auto temp = Integer(this, this.allocator);
        auto sign = this.sign != operand.sign;

        this = 0;
        do
        {
            --i;
            for (ubyte mask = 0x01; mask; mask <<= 1)
            {
                if (mask & operand.rep[i])
                {
                    add(temp);
                }
                temp <<= 1;
            }
        }
        while (i);

        this.sign = sign ? Sign.negative : Sign.positive;

        return this;
    }

    ///
    @safe @nogc unittest
    {
        auto h1 = Integer(123);
        auto h2 = Integer(456);
        h1 *= h2;
        assert(h1 == 56088);
    }

    private @nogc unittest
    {
        assert((Integer(1) * Integer()).length == 0);
    }

    /// Ditto.
    ref Integer opOpAssign(string op : "^^")(const auto ref Integer operand)
    @trusted
    out
    {
        assert(this.size == 0 || this.rep[0] > 0);
    }
    body
    {
        size_t i = operand.size;

        auto tmp1 = Integer(this, this.allocator);
        this = 1;

        do
        {
            --i;
            for (ubyte mask = 0x01; mask; mask <<= 1)
            {
                if (operand.rep[i] & mask)
                {
                    this *= tmp1;
                }
                // Square tmp1
                auto tmp2 = tmp1;
                tmp1 *= tmp2;
            }
        }
        while (i);

        return this;
    }

    private @nogc unittest
    {
        auto h1 = Integer(2);
        auto h2 = Integer(4);

        h1 ^^= h2;
        assert(h1.length == 1);
        assert(h1.rep[0] == 0x10);

        h1 = Integer(2342);
        h1 ^^= h2;
        ubyte[6] expected = [0x1b, 0x5c, 0xab, 0x9c, 0x31, 0x10];
        assert(h1.rep[0 .. h1.size] == expected);
    }

    /// Ditto.
    ref Integer opOpAssign(string op)(const auto ref Integer operand) @trusted
        if ((op == "%") || (op == "/"))
    in
    {
        assert(operand.length > 0, "Division by zero.");
    }
    out
    {
        assert(this.size == 0 || this.rep[0] > 0);
    }
    body
    {
        auto divisor = Integer(operand, this.allocator);
        size_t bitSize;

        // First, left-shift divisor until it's >= than the dividend
        while (compare(divisor) > 0)
        {
            divisor <<= 1;
            ++bitSize;
        }
        static if (op == "/")
        {
            auto quotient = allocator.resize!ubyte(null, bitSize / 8 + 1);
        }

        // bitPosition keeps track of which bit, of the quotient,
        // is being set or cleared on the current operation.
        auto bitPosition = 8 - (bitSize % 8) - 1;
        do
        {
            if (compare(divisor) >= 0)
            {
                subtract(divisor); // dividend -= divisor
                static if (op == "/")
                {
                    quotient[bitPosition / 8] |= 0x80 >> (bitPosition % 8);
                }
            }
            if (bitSize != 0)
            {
                divisor >>= 1;
            }
            ++bitPosition;
        }
        while (bitSize--);

        static if (op == "/")
        {
            allocator.resize(this.rep[0 .. this.size], 0);
            this.rep = quotient.ptr;
            this.size = quotient.length;
            this.sign = this.sign == divisor.sign ? Sign.positive : Sign.negative;
            contract();
        }

        return this;
    }

    private @nogc unittest
    {
        auto h1 = Integer(18);
        auto h2 = Integer(4);
        h1 %= h2;
        assert(h1.length == 1);
        assert(h1.rep[0] == 0x02);

        h1 = 8;
        h1 %= h2;
        assert(h1.length == 0);

        h1 = 7;
        h1 %= h2;
        assert(h1.length == 1);
        assert(h1.rep[0] == 0x03);

        h1 = 56088;
        h2 = 456;
        h1 /= h2;
        assert(h1.length == 1);
        assert(h1.rep[0] == 0x7b);
    }

    /// Ditto.
    ref Integer opOpAssign(string op : ">>")(const size_t operand) @trusted
    out
    {
        assert(this.size == 0 || this.rep[0] > 0);
    }
    body
    {
        const step = operand / 8;

        if (step >= this.length)
        {
            this.rep = allocator.resize(this.rep[0 .. this.size], 0).ptr;
            this.size = 0;
            return this;
        }

        size_t i, j;
        ubyte carry;
        const bit = operand % 8;
        const delta = 8 - bit;

        carry = cast(ubyte) (this.rep[0] << delta);
        this.rep[0] = this.rep[0] >> bit;
        if (rep[0])
        {
            ++j;
        }
        for (i = 1; i < this.length; ++i)
        {
            immutable oldCarry = carry;
            carry = cast(ubyte) (this.rep[i] << delta);
            this.rep[j] = this.rep[i] >> bit | oldCarry;
            ++j;
        }
        const newSize = this.length - operand / 8 - (i == j ? 0 : 1);
        this.rep = allocator.resize(this.rep[0 .. this.size], newSize).ptr;
        this.size = newSize;

        return this;
    }

    private @nogc unittest
    {
        auto integer = Integer(4294967294);
        integer >>= 10;
        assert(integer.length == 3);
        assert(integer.rep[0] == 0x3f && integer.rep[1] == 0xff && integer.rep[2] == 0xff);

        integer = 27336704;
        integer >>= 1;
        assert(integer.length == 3);
        assert(integer.rep[0] == 0xd0 && integer.rep[1] == 0x90 && integer.rep[2] == 0x00);

        integer = 4294967294;
        integer >>= 20;
        assert(integer.length == 2);
        assert(integer.rep[0] == 0x0f && integer.rep[1] == 0xff);

        integer >>= 0;
        assert(integer.length == 2);
        assert(integer.rep[0] == 0x0f && integer.rep[1] == 0xff);

        integer >>= 20;
        assert(integer.length == 0);

        integer >>= 2;
        assert(integer.length == 0);

        integer = 1431655765;
        integer >>= 16;
        assert(integer.length == 2);
        assert(integer.rep[0] == 0x55 && integer.rep[1] == 0x55);

        integer >>= 16;
        assert(integer.length == 0);
    }

    /// Ditto.
    ref Integer opOpAssign(string op : "<<")(const size_t operand) @trusted
    out
    {
        assert(this.size == 0 || this.rep[0] > 0);
    }
    body
    {
        ubyte carry;
        auto i = this.length;
        size_t j;
        const bit = operand % 8;
        const delta = 8 - bit;

        if (cast(ubyte) (this.rep[0] >> delta))
        {
            const newSize = i + operand / 8 + 1;
            this.rep = allocator.resize(this.rep[0 .. this.size], newSize).ptr;
            this.size = newSize;
            j = i + 1;
        }
        else
        {
            const newSize = i + operand / 8;
            this.rep = allocator.resize(this.rep[0 .. this.size], newSize).ptr;
            j = i;
        }
        do
        {
            --i, --j;
            const oldCarry = carry;
            carry = rep[i] >> delta;
            rep[j] = cast(ubyte) ((this.rep[i] << bit) | oldCarry);
        }
        while (i);
        if (carry)
        {
            rep[0] = carry;
        }
        return this;
    }

    private @nogc unittest
    {
        auto integer = Integer(4294967295);
        ubyte[5] expected = [0x01, 0xff, 0xff, 0xff, 0xfe];
        integer <<= 1;
        assert(integer.rep[0 .. integer.size] == expected);
    }

    private void decrement() nothrow @trusted @nogc
    in
    {
        assert(this.length > 0);
    }
    body
    {
        auto p = this.rep + this.size;
        while (p != this.rep)
        {
            --p, --*p;
            if (*p != ubyte.max)
            {
                break;
            }
        }
        contract();
    }

    private void increment() nothrow @trusted @nogc
    {
        auto p = this.rep + this.size;
        while (p != this.rep)
        {
            --p, ++*p;
            if (*p > 0)
            {
                return;
            }
        }
        if (p == this.rep)
        {
            expand();
        }
    }

    /**
     * Unary operators.
     *
     * Params:
     *  op = Operation.
     *
     * Returns: New $(D_PSYMBOL Integer).
     */
    Integer opUnary(string op : "~")() const
    {
        auto ret = Integer(this, this.allocator);
        ret.rep[0 .. ret.size].each!((ref a) => a = ~a);
        return ret;
    }

    /// Ditto.
    Integer opUnary(string op : "-")() const
    {
        auto ret = Integer(this, this.allocator);
        ret.sign = ret.sign ? Sign.positive : Sign.negative;
        return ret;
    }

    /**
     * Unary operators.
     *
     * Params:
     *  op = Operation.
     *
     * Returns: $(D_KEYWORD this).
     */
    ref inout(Integer) opUnary(string op : "+")() inout
    {
        return this;
    }

    private @nogc unittest
    {
        auto h1 = Integer(79);
        Integer h2;

        h2 = +h1;
        assert(h2.length == 1);
        assert(h2.rep[0] == 79);
        assert(!h2.sign);
        assert(h2 !is h1);

        h2 = -h1;
        assert(h2.length == 1);
        assert(h2.rep[0] == 79);
        assert(h2.sign);

        h1 = -h2;
        assert(h2.length == 1);
        assert(h2.rep[0] == 79);
        assert(h2.sign);
        assert(h2 !is h1);

        h1 = -h2;
        assert(h1.length == 1);
        assert(h1.rep[0] == 79);
        assert(!h1.sign);

        h2 = ~h1;
        assert(h2.rep[0] == ~cast(ubyte) 79);
    }

    /// Ditto.
    ref Integer opUnary(string op : "++")()
    out
    {
        assert(this.size == 0 || this.rep[0] > 0);
    }
    body
    {
        if (this.sign)
        {
            decrement();
            if (this.length == 0)
            {
                this.sign = Sign.positive;
            }
        }
        else
        {
            increment();
        }
        return this;
    }

    /// Ditto.
    ref Integer opUnary(string op : "--")()
    out
    {
        assert(this.size == 0 || this.rep[0] > 0);
    }
    body
    {
        if (this.sign)
        {
            increment();
        }
        else
        {
            decrement();
        }
        return this;
    }

    private @nogc unittest
    {
        Integer integer;

        ++integer;
        assert(integer.length == 1);
        assert(integer.rep[0] == 0x01);

        --integer;
        assert(integer.length == 0);

        integer = 511;
        ++integer;
        assert(integer.length == 2);
        assert(integer.rep[0] == 0x02 && integer.rep[1] == 0x00);

        --integer;
        assert(integer.length == 2);
        assert(integer.rep[0] == 0x01 && integer.rep[1] == 0xff);

        integer = 79;
        ++integer;
        assert(integer.length == 1);
        assert(integer.rep[0] == 0x50);

        --integer;
        assert(integer.length == 1);
        assert(integer.rep[0] == 0x4f);

        integer = 65535;
        ++integer;
        assert(integer.length == 3);
        assert(integer.rep[0] == 0x01 && integer.rep[1] == 0x00 && integer.rep[2] == 0x00);

        --integer;
        assert(integer.length == 2);
        assert(integer.rep[0] == 0xff && integer.rep[1] == 0xff);

        integer = -2;
        ++integer;
        assert(integer.length == 1);
        assert(integer.rep[0] == 0x01);
    }

    /**
     * Implements binary operators.
     *
     * Params:
     *  op      = Operation.
     *  operand = The second operand.
     */
    Integer opBinary(string op)(const auto ref Integer operand) const
        if (op == "+" || op == "-" || op == "*" || op == "^^")
    {
        auto ret = Integer(this, this.allocator);
        mixin("ret " ~ op ~ "= operand;");
        return ret;
    }

    /// Ditto.
    Integer opBinary(string op)(const auto ref Integer operand) const
        if (op == "/" || op == "%")
    in
    {
        assert(operand.length > 0, "Division by zero.");
    }
    body
    {
        auto ret = Integer(this, this.allocator);
        mixin("ret " ~ op ~ "= operand;");
        return ret;
    }

    /// Ditto.
    Integer opBinary(string op)(const auto ref size_t operand) const
        if (op == "<<" || op == ">>")
    {
        auto ret = Integer(this, this.allocator);
        mixin("ret " ~ op ~ "= operand;");
        return ret;
    }

    ///
    @safe @nogc unittest
    {
        auto integer1 = Integer(425);
        auto integer2 = integer1 << 1;
        assert(integer2 == 850);

        integer2 = integer1 >> 1;
        assert(integer2 == 212);
    }

    /**
     * Casting.
     *
     * Params:
     *  T = Target type.
     *
     * Returns: $(D_KEYWORD false) if the $(D_PSYMBOL Integer) is 0,
     *          $(D_KEYWORD true) otherwise.
     */
    T opCast(T : bool)() const
    {
        return this.length > 0;
    }

    /// Ditto.
    T opCast(T)() const
        if (isIntegral!T && isSigned!T)
    {
        return this.sign ? -(cast(Unsigned!T) this) : cast(Unsigned!T) this;
    }

    /// Ditto.
    T opCast(T)() const @trusted
        if (isIntegral!T && isUnsigned!T)
    {
        if (this.length == 0)
        {
            return 0;
        }
        T ret;
        const(ubyte)* src = this.rep + this.size - 1;
        for (ubyte shift; src >= this.rep && shift <= T.sizeof * 8; --src, shift += 8)
        {
            ret |= cast(T) (*src) << shift;
        }
        return ret;
    }

    ///
    @safe @nogc unittest
    {
        auto integer = Integer(79);
        assert(cast(long) integer == 79);

        integer = -79;
        assert(cast(long) integer == -79);

        integer = 4294967295;
        assert(cast(long) integer == 4294967295);

        integer = -4294967295;
        assert(cast(long) integer == -4294967295);
    }

    mixin DefaultAllocator;
}
