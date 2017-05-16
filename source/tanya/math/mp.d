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

import std.algorithm;
import std.ascii;
import std.range;
import std.traits;
import tanya.container.array;
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
    package digit[] rep;
    package ptrdiff_t size;
    package Sign sign;

    pure nothrow @safe @nogc invariant
    {
        assert(this.size > 0 || !this.sign, "0 should be positive.");
    }

    private alias digit = uint;
    private alias word = ulong;

    // Count of bits per digit.
    private enum : digit
    {
        digitBitCount = 28,
        mask = 0xfffffff,
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
        this = value;
    }

    /// Ditto.
    this(T)(ref T value, shared Allocator allocator = defaultAllocator)
        if (is(Unqual!T == Integer))
    {
        this(allocator);
        this = value;
    }

    /// Ditto.
    this(T)(T value, shared Allocator allocator = defaultAllocator)
    nothrow @safe @nogc
        if (is(T == Integer))
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
            this = value;
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
    this(R)(const Sign sign,
            R value,
            shared Allocator allocator = defaultAllocator)
        if (isBidirectionalRange!R && hasLength!R
         && is(Unqual!(ElementType!R) == ubyte))
    {
        this(allocator);
        grow(value.length / (digitBitCount / 8) + 1);

        int bit, delta;

        for (; !value.empty; ++this.size)
        {
            word w;
            for (bit = delta; (bit < digitBitCount) && !value.empty; bit += 8)
            {
                w |= (cast(word) value.back) << bit;
                value.popBack();
            }

            delta = bit - digitBitCount;
            this.rep[this.size] |= w & mask;

            if (delta > 0)
            {
                this.rep[this.size + 1] = (w >> digitBitCount) & mask;
            }
        }
    }

    nothrow @safe @nogc unittest
    {
        ubyte[8] range = [ 0x66, 0x77, 0x88, 0x99, 0xaa, 0xbb, 0xdd, 0xee ];
        auto integer = Integer(Sign.positive, range[]);
        assert(integer == 7383520307673030126);
    }

    /**
     * Constructs the integer from a two's complement representation.
     *
     * Params:
     *  R         = Range type.
     *  value     = Range.
     *  allocator = Allocator.
     *
     * Precondition: $(D_INLINECODE allocator !is null)
     */
    this(R)(R value,
            shared Allocator allocator = defaultAllocator)
        if (isBidirectionalRange!R && hasLength!R
         && is(Unqual!(ElementType!R) == ubyte))
    {
        this(Sign.positive, value, allocator);

        if (!value.empty && ((value.front & 0x80) != 0))
        {
            // Negative number.
            opOpAssign!"-"(exp2(countBits()));
        }
    }

    ///
    nothrow @safe @nogc unittest
    {
        {
            ubyte[8] range = [ 0x66, 0x77, 0x88, 0x99, 0xaa, 0xbb, 0xdd, 0xee ];
            auto integer = Integer(range[]);
            assert(integer == 7383520307673030126);
        }
        {
            ubyte[8] range = [ 0xe6, 0x77, 0x88, 0x99, 0xaa, 0xbb, 0xdd, 0xee ];
            auto integer = Integer(range[]);
            assert(integer == -1839851729181745682);
        }
    }

    /**
     * Copies the integer.
     */
    this(this) nothrow @trusted @nogc
    {
        auto tmp = allocator.resize!digit(null, this.size);
        this.rep[0 .. this.size].copy(tmp);
        this.rep = tmp;
    }

    /**
     * Destroys the integer.
     */
    ~this() nothrow @trusted @nogc
    {
        allocator.resize(this.rep, 0);
    }

    static private const short[16] bitCounts = [
        4, 0, 1, 0, 2, 0, 1, 0, 3, 0, 1, 0, 2, 0, 1, 0
    ];

    // Counts the number of LSBs before the first non-zero bit.
    private ptrdiff_t countLSBs() const pure nothrow @safe @nogc
    {
        if (this.size == 0)
        {
            return 0;
        }

        ptrdiff_t bits;
        for (bits = 0; (bits < this.size) && (this.rep[bits] == 0); ++bits)
        {
        }
        digit nonZero = this.rep[bits];
        bits *= digitBitCount;

        /* now scan this digit until a 1 is found */
        if ((nonZero & 0x01) == 0)
        {
            digit bitCountsPos;
            do
            {
                bitCountsPos = nonZero & 0x0f;
                bits += bitCounts[bitCountsPos];
                nonZero >>= 4;
            }
            while (bitCountsPos == 0);
        }
        return bits;
    }

    /**
     * Returns: Number of bytes in the two's complement representation.
     */
    @property size_t length() const pure nothrow @safe @nogc
    {
        if (this.sign)
        {
            const bc = countBits();
            auto length = bc + (8 - (bc & 0x07));

            if (((countLSBs() + 1) == bc) && ((bc & 0x07) == 0))
            {
                --length;
            }
            return length / 8;
        }
        else if (this.size == 0)
        {
            return 0;
        }
        else
        {
            return (countBits() / 8) + 1;
        }
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
        rep[0 .. this.size].fill(digit.init);
        grow(digitBitCount / 8 + 1);

        static if (isSigned!T)
        {
            ulong absolute;
            if (value >= 0)
            {
                absolute = value;
                this.sign = Sign.positive;
            }
            else
            {
                absolute = -value;
                this.sign = Sign.negative;
            }
        }
        else
        {
            ulong absolute = value;
            this.sign = Sign.positive;
        }

        for (this.size = 0; absolute; absolute >>= digitBitCount, ++this.size)
        {
            this.rep[this.size] = absolute & mask;
        }

        return this;
    }

    /// Ditto.
    ref Integer opAssign(T)(ref T value) @trusted
        if (is(Unqual!T == Integer))
    {
        this.rep = allocator.resize(this.rep, value.size);
        value.rep[0 .. value.size].copy(this.rep[0 .. value.size]);
        this.size = value.size;
        this.sign = value.sign;

        return this;
    }

    /// Ditto.
    ref Integer opAssign(T)(T value) nothrow @safe @nogc
        if (is(T == Integer))
    {
        swap(this.rep, value.rep);
        swap(this.sign, value.sign);
        swap(this.size, value.size);
        swap(this.allocator_, value.allocator_);
        return this;
    }

    /**
     * Casting.
     *
     * Params:
     *  T = Target type.
     *
     * Returns: Converted value.
     */
    T opCast(T : bool)() const
    {
        return this.size > 0;
    }

    /// Ditto.
    T opCast(T)() const
        if (isIntegral!T && isUnsigned!T)
    {
        T ret;
        ubyte shift;
        for (size_t i; i < this.size && shift <= T.sizeof * 8; ++i)
        {
            ret |= (cast(T) this.rep[i]) << shift;
            shift += digitBitCount;
        }
        return ret;
    }

    /// Ditto.
    T opCast(T)() const
        if (isIntegral!T && isSigned!T)
    {
        return this.sign ? -(cast(Unsigned!T) this) : cast(Unsigned!T) this;
    }

    ///
    @safe @nogc unittest
    {
        auto integer = Integer(79);
        assert(cast(ushort) integer == 79);

        integer = -79;
        assert(cast(short) integer == -79);

        integer = 4294967295;
        assert(cast(long) integer == 4294967295);

        integer = -4294967295;
        assert(cast(long) integer == -4294967295);

        integer = long.min;
        assert(cast(long) integer == long.min);

        integer = long.min + 1;
        assert(cast(long) integer == long.min + 1);

        integer = 0;
        assert(cast(long) integer == 0);
    }

    /* trim unused digits 
     *
     * This is used to ensure that leading zero digits are
     * trimed and the leading "size" digit will be non-zero
     * Typically very fast.  Also fixes the sign if there
     * are no more leading digits
     */
    void contract() nothrow @safe @nogc
    {
        /* decrease size while the most significant digit is
         * zero.
         */
        while ((this.size > 0) && (this.rep[this.size - 1] == 0))
        {
            --this.size;
        }

        /* reset the sign flag if size == 0 */
        if (this.size == 0)
        {
            this.sign = Sign.positive;
        }
    }

    private void grow(const size_t size) nothrow @trusted @nogc
    {
        if (this.rep.length >= size)
        {
            return;
        }
        const oldLength = this.rep.length;
        allocator.resize(this.rep, size);
        this.rep[oldLength .. $].fill(digit.init);
    }

    private size_t countBits() const pure nothrow @safe @nogc
    {
        if (this.size == 0)
        {
            return 0;
        }
        auto r = (this.size - 1) * digitBitCount;
        digit q = this.rep[this.size - 1];

        while (q > 0)
        {
            ++r;
            q >>= (cast(digit) 1);
        }
        return r;
    }

    private void add(ref const Integer summand, ref Integer sum)
    const nothrow @safe @nogc
    {
        const(digit)[] max, min;

        if (this.size > summand.size)
        {
            min = summand.rep[0 .. summand.size];
            max = this.rep[0 .. this.size];
        }
        else
        {
            min = this.rep[0 .. this.size];
            max = summand.rep[0 .. summand.size];
        }
        sum.grow(max.length + 1);

        const oldSize = sum.size;
        sum.size = cast(int) (max.length + 1);

        auto result = sum.rep;
        digit carry;
        foreach (i, ref const d; min)
        {
            result.front = d + max.front + carry;
            carry = result.front >> digitBitCount;
            result.front &= mask;

            max.popFront();
            result.popFront();
        }

        // Copy higher digests if one of the summands is greater than another
        // one.
        for (; !max.empty; max.popFront(), result.popFront())
        {
            result.front = max.front + carry;
            carry = result.front >> digitBitCount;
            result.front &= mask;
        }
        result.front = carry;

        // Clear digits above the old size.
        for (auto i = sum.size; i < oldSize; ++i)
        {
            sum.rep[i] = 0;
        }

        sum.contract();
    }

    private void add(const digit summand, ref Integer sum)
    const nothrow @safe @nogc
    {
        sum.grow(this.size + 2);

        sum.rep[0] = this.rep[0] + summand;
        auto carry = sum.rep[0] >> digitBitCount;
        sum.rep[0] &= mask;

        size_t i;
        for (i = 1; i < this.size; ++i)
        {
            sum.rep[i] = this.rep[i] + carry;
            carry = sum.rep[i] >> digitBitCount;
            sum.rep[i] &= mask;
        }
        sum.rep[i++] = carry;

        for (; i < sum.size; ++i)
        {
            sum.rep[i] = 0;
        }
        sum.size = this.size + 1;
        sum.contract();
    }

    private void subtract(ref const Integer subtrahend, ref Integer difference)
    const nothrow @safe @nogc
    {
        difference.grow(this.size);

        const oldSize = difference.size;
        difference.size = this.size;

        size_t i;
        digit carry;

        for (i = 0; i < subtrahend.size; ++i)
        {
            difference.rep[i] = (this.rep[i] - subtrahend.rep[i]) - carry;
            carry = difference.rep[i] >> (cast(digit) (8 * digit.sizeof) - 1);
            difference.rep[i] &= mask;
        }

        // Copy higher digests if the minuend has more digits than the
        // subtrahend.
        for (; i < this.size; ++i)
        {
            difference.rep[i] = this.rep[i] - carry;
            carry = difference.rep[i] >> (cast(digit) ((8 * digit.sizeof) - 1));
            difference.rep[i] &= mask;
        }

        // Clear digits above the size.
        for (i = difference.size; i < oldSize; ++i)
        {
            difference.rep[i] = 0;
        }

        difference.contract();
    }

    private void subtract(const digit subtrahend, ref Integer difference)
    const nothrow @safe @nogc
    {
        difference.grow(this.size);

        const oldSize = difference.size;

        difference.sign = this.sign;
        difference.size = this.size;

        difference.rep[0] = this.rep[0] - subtrahend;
        auto carry = difference.rep[0] >> ((digit.sizeof * 8) - 1);
        difference.rep[0] &= mask;

        size_t i;
        for (i = 1; i < this.size; ++i)
        {
            difference.rep[i] = this.rep[i] - carry;
            carry = difference.rep[i] >> ((digit.sizeof * 8) - 1);
            difference.rep[i] &= mask;
        }

        for (; i < oldSize; ++i)
        {
            difference.rep[i] = 0;
        }
        difference.contract();
    }

    // Compare the magnitude.
    private int compare(ref const Integer that) const pure nothrow @safe @nogc
    {
        if (this.size > that.size)
        {
            return 1;
        }
        else if (this.size < that.size)
        {
            return -1;
        }
        return this.rep[0 .. this.size]
                   .retro
                   .cmp(that.rep[0 .. that.size].retro);
    }

    /**
     * Comparison.
     *
     * Params:
     *  I    = Comparand type.
     *  that = The second integer.
     *
     * Returns: A positive number if $(D_INLINECODE this > that), a negative
     *          number if $(D_INLINECODE this < that), `0` otherwise.
     */
    int opCmp(I : Integer)(auto ref const I that) const
    {
        if (this.sign != that.sign)
        {
            if (this.sign == Sign.negative)
            {
                return -1;
            }
            else
            {
                return 1;
            }
        }
        if (this.sign == Sign.negative)
        {
            return that.compare(this);
        }
        else
        {
            return compare(that);
        }
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
    int opCmp(I)(const I that) const
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
        else if (this.size > I.sizeof)
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
     *  I    = Comparand type.
     *  that = The second integer.
     *
     * Returns: Whether the two integers are equal.
     */
    bool opEquals(I)(auto ref const I that) const
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
    ref Integer opOpAssign(string op : "+")(auto ref const Integer operand)
    {
        if (this.sign == operand.sign)
        {
            add(operand, this);
        }
        else if (compare(operand) < 0)
        {
            this.sign = operand.sign;
            operand.subtract(this, this);
        }
        else
        {
            subtract(operand, this);
        }
        return this;
    }

    ///
    unittest
    {
        {
            auto h1 = Integer(1019);
            auto h2 = Integer(3337);
            h1 += h2;
            assert(h1 == 4356);
        }
        {
            auto h1 = Integer(4356);
            auto h2 = Integer(2_147_483_647);
            h1 += h2;
            assert(h1 == 2147488003);
        }
        {
            auto h1 = Integer(2147488003L);
            auto h2 = Integer(2_147_483_647);
            h1 += h2;
            assert(h1 == 4294971650);
        }
    }

    /// Ditto.
    ref Integer opOpAssign(string op : "-")(auto ref const Integer operand)
    {
        if (this.sign != operand.sign)
        {
            add(operand, this);
        }
        else if (compare(operand) >= 0)
        {
            subtract(operand, this);
        }
        else
        {
            operand.subtract(this, this);
            this.sign = this.sign ? Sign.positive : Sign.negative;
        }
        return this;
    }

    ///
    unittest
    {
        {
            auto h1 = Integer(3);
            auto h2 = Integer(4);
            h1 -= h2;
            assert(h1 == -1);
        }
        {
            auto h1 = Integer(8589934590L);
            auto h2 = Integer(2147483647);
            h1 -= h2;
            assert(h1 == 6442450943);
        }
        {
            auto h1 = Integer(6442450943);
            auto h2 = Integer(4294967294);
            h1 -= h2;
            assert(h1 == 2147483649);
        }
        {
            auto h1 = Integer(2147483649);
            auto h2 = Integer(h1);
            h1 -= h2;
            assert(h1 == 0);
        }
    }

    /// Ditto.
    ref Integer opOpAssign(string op : "*")(auto ref const Integer operand)
    {
        const digits = this.size + operand.size + 1;

        multiply(operand, this, digits);

        if (this.size > 0)
        {
            this.sign = this.sign == operand.sign ? Sign.positive : Sign.negative;
        }

        return this;
    }

    ///
    nothrow @safe @nogc unittest
    {
        auto h1 = Integer(123);
        auto h2 = Integer(456);
        h1 *= h2;
        assert(h1 == 56088);
    }

    /// Ditto.
    ref Integer opOpAssign(string op : "/")(auto ref const Integer operand)
    in
    {
        assert(operand.length > 0, "Division by zero.");
    }
    body
    {
        divide(operand, this);
        return this;
    }

     /// Ditto.
    ref Integer opOpAssign(string op : "%")(auto ref const Integer operand)
    in
    {
        assert(operand.length > 0, "Division by zero.");
    }
    body
    {
        divide(operand, null, this);
        return this;
    }

    nothrow @safe @nogc unittest
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

    /// Ditto.
    ref Integer opOpAssign(string op : ">>")(const size_t operand)
    {
        if (operand == 0)
        {
            return this;
        }
        if (operand >= digitBitCount)
        {
            shiftRight(operand / digitBitCount);
        }

        const bit = cast(digit) (operand % digitBitCount);
        if (bit != 0)
        {
            const mask = ((cast(digit) 1) << bit) - 1;
            const shift = digitBitCount - bit;
            digit carry;

            foreach (ref d; this.rep[0 .. this.size].retro)
            {
                const newCarry = d & mask;
                d = (d >> bit) | (carry << shift);
                carry = newCarry;
            }
        }
        this.contract();
        return this;
    }

    ///
    nothrow @safe @nogc unittest
    {
        auto integer = Integer(4294967294);
        integer >>= 10;
        assert(integer == 4194303);

        integer = 27336704;
        integer >>= 1;
        assert(integer == 13668352);

        integer = 4294967294;
        integer >>= 20;
        assert(integer == 4095);

        integer >>= 0;
        assert(integer == 4095);

        integer >>= 20;
        assert(integer == 0);

        integer >>= 2;
        assert(integer == 0);

        integer = 1431655765;
        integer >>= 16;
        assert(integer == 21845);

        integer >>= 16;
        assert(integer == 0);
    }

    /// Ditto.
    ref Integer opOpAssign(string op : "<<")(const size_t operand)
    {
        const step = operand / digitBitCount;
        if (this.rep.length < this.size + step + 1)
        {
            grow(this.size + step + 1);
        }
        if (operand >= digitBitCount)
        {
            shiftLeft(step);
        }

        const bit = cast(digit) (operand % digitBitCount);
        if (bit != 0)
        {
            const mask = ((cast(digit) 1) << bit) - 1;
            const shift = digitBitCount - bit;
            digit carry;

            foreach (ref d; this.rep[0 .. this.size])
            {
                const newCarry = (d >> shift) & mask;
                d = ((d << bit) | carry) & this.mask;
                carry = newCarry;
            }

            if (carry != 0)
            {
                this.rep[this.size++] = carry;
            }
        }
        this.contract();
        return this;
    }

    ///
    nothrow @safe @nogc unittest
    {
        auto integer = Integer(4294967295);
        integer <<= 1;
        assert(integer == 8589934590);
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
        auto ret = Integer(this, allocator);
        ret.rep[0 .. ret.size].each!((ref a) => a = ~a & mask);
        return ret;
    }

    /// Ditto.
    Integer opUnary(string op : "-")() const
    {
        auto ret = Integer(this, allocator);
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

    //
    nothrow @safe @nogc unittest
    {
        auto h1 = Integer(79);
        Integer h2;

        h2 = +h1;
        assert(h2 == 79);

        h2 = -h1;
        assert(h2 == -79);
        assert(h1 == 79);

        h1 = -h2;
        assert(h1 == 79);

        h2 = ~h1;
        assert(h2 == ~cast(ubyte) 79);
    }

    /// Ditto.
    ref Integer opUnary(string op : "++")()
    {
        if (this.sign)
        {
            subtract(1, this);
        }
        else
        {
            add(1, this);
        }
        return this;
    }

    /// Ditto.
    ref Integer opUnary(string op : "--")()
    {
        if (this.size == 0)
        {
            add(1, this);
            this.sign = Sign.negative;
        }
        else if (this.sign)
        {
            add(1, this);
        }
        else
        {
            subtract(1, this);
        }
        return this;
    }

    ///
    nothrow @safe @nogc unittest
    {
        Integer integer;

        ++integer;
        assert(integer == 1);

        --integer;
        assert(integer == 0);

        integer = 511;
        ++integer;
        assert(integer == 512);

        --integer;
        assert(integer == 511);

        integer = 79;
        ++integer;
        assert(integer == 80);

        --integer;
        assert(integer == 79);

        integer = -2;
        ++integer;
        assert(integer == -1);

        ++integer;
        assert(integer == 0);

        --integer;
        assert(integer == -1);
    }

    /**
     * Implements binary operators.
     *
     * Params:
     *  op      = Operation.
     *  operand = The second operand.
     *
     * Returns: Result.
     */
    Integer opBinary(string op)(auto ref const Integer operand) const
        if ((op == "+" || op == "-") || (op == "*"))
    {
        mixin("return Integer(this, allocator) " ~ op ~ "= operand;");
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
        mixin("return Integer(this, allocator) " ~ op ~ "= operand;");
    }

    /// Ditto.
    Integer opBinary(string op)(const size_t operand) const
        if (op == "<<" || op == ">>")
    {
        mixin("return Integer(this, allocator) " ~ op ~ "= operand;");
    }

    // Shift right a certain amount of digits.
    private void shiftRight(const size_t operand) nothrow @safe @nogc
    {
        if (operand == 0)
        {
            return;
        }
        if (this.size <= operand)
        {
            this = 0;
            return;
        }
        const reducedSize = this.size - operand;

        this.rep[operand .. this.size].copy(this.rep[0 .. reducedSize]);
        this.rep[reducedSize .. this.size].fill(digit.init);
        this.size = reducedSize;
    }

    // Shift left a certain amount of digits.
    private void shiftLeft(const size_t operand) nothrow @safe @nogc
    {
        if (operand == 0)
        {
            return;
        }
        const increasedSize = this.size + operand;
        grow(increasedSize);

        this.size = increasedSize;

        auto top = this.size - 1;
        auto bottom = this.size - 1 - operand;

        for (; top >= operand; --bottom, --top)
        {
            this.rep[top] = this.rep[bottom];
        }
        this.rep[0 .. operand].fill(digit.init);
    }

    private void multiply(const digit factor, ref Integer product)
    const nothrow @safe @nogc
    {
        product.grow(this.size + 1);
        product.sign = this.sign;

        word carry;
        size_t i;

        for (i = 0; i < this.size; ++i)
        {
            auto newCarry = carry + (cast(word) this.rep[i] * factor);
            product.rep[i] = newCarry & mask;
            carry = newCarry >> digitBitCount;
        }
        product.rep[i++] = carry & mask;

        for (; i < this.size; ++i)
        {
            product.rep[i] = 0;
        }
        product.size = this.size + 1;
        product.contract();
    }

    private void multiply(ref const Integer factor,
                          ref Integer product,
                          const size_t digits) const nothrow @safe @nogc
    {
        Integer intermediate;
        intermediate.grow(digits);
        intermediate.size = digits;

        for (size_t i; i < this.size; ++i)
        {
            const limit = min(factor.size, digits - i);
            word carry;
            auto k = i;

            for (size_t j; j < limit; ++j, ++k)
            {
                const result = cast(word) intermediate.rep[k]
                             + (cast(word) this.rep[i] * factor.rep[j])
                             + carry;
                intermediate.rep[k] = result & mask;
                carry = result >> digitBitCount;
            }
            if (k < digits)
            {
                intermediate.rep[k] = carry & mask;
            }
        }
        intermediate.contract();
        swap(product, intermediate);
    }

    private void divide(Q, ARGS...)(ref const Integer divisor,
                                    auto ref Q quotient,
                                    ref ARGS args)
    const nothrow @safe @nogc
        if ((is(Q : typeof(null))
         || (is(Q : Integer) && __traits(isRef, quotient)))
         && (ARGS.length == 0 || (ARGS.length == 1 && is(ARGS[0] : Integer))))
    in
    {
        assert(divisor != 0, "Division by zero.");
    }
    body
    {
        if (compare(divisor) < 0)
        {
            static if (ARGS.length == 1)
            {
                args[0] = this;
            }
            static if (!is(Q == typeof(null)))
            {
                quotient = 0;
            }
            return;
        }

        Integer q, t1, t2;
        q.grow(this.size + 2);
        q.size = this.size + 2;

        t1.grow(2);
        t2.grow(3);

        auto x = Integer(this);
        auto y = Integer(divisor);

        const sign = this.sign == divisor.sign ? Sign.positive : Sign.negative;
        x.sign = y.sign = Sign.positive;

        auto norm = y.countBits() % digitBitCount;
        if (norm < digitBitCount - 1)
        {
            norm = digitBitCount - 1 - norm;
            x <<= norm;
            y <<= norm;
        }
        else
        {
            norm = 0;
        }

        auto n = x.size - 1;
        auto t = y.size - 1;

        y.shiftLeft(n - t);

        while (x >= y)
        {
            ++q.rep[n - t];
            x -= y;
        }

        y.shiftRight(n - t);

        for (auto i = n; i >= (t + 1); --i)
        {
            if (i > x.size)
            {
                continue;
            }
            if (x.rep[i] == y.rep[t])
            {
                q.rep[(i - t) - 1] = (((cast(digit) 1) << digitBitCount) - 1);
            }
            else
            {
                word tmp = (cast(word) x.rep[i]) << digitBitCount;
                tmp |= x.rep[i - 1];
                tmp /= y.rep[t];
                if (tmp > mask)
                {
                    tmp = mask;
                }
                q.rep[i - t - 1] = tmp & mask;
            }

            q.rep[i - t - 1] = (q.rep[i - t - 1] + 1) & mask;
            do
            {
                q.rep[i - t - 1] = (q.rep[i - t - 1] - 1) & mask;

                // Left hand.
                t1 = 0;
                t1.rep[0] = ((t - 1) < 0) ? 0 : y.rep[t - 1];
                t1.rep[1] = y.rep[t];
                t1.size = 2;
                t1.multiply(q.rep[i - t - 1], t1);

                // Right hand.
                t2.rep[0] = ((i - 2) < 0) ? 0 : x.rep[i - 2];
                t2.rep[1] = ((i - 1) < 0) ? 0 : x.rep[i - 1];
                t2.rep[2] = x.rep[i];
                t2.size = 3;
            }
            while (t1.compare(t2) > 0);

            y.multiply(q.rep[i - t - 1], t1);

            t1.shiftLeft(i - t - 1);

            x -= t1;

            if (x.sign == Sign.negative)
            {
                t1 = y;
                t1.shiftLeft(i - t - 1);
                x += t1;

                q.rep[i - t - 1] = (q.rep[i - t - 1] - 1) & mask;
            }
        }

        x.sign = (x.size == 0) ? Sign.positive : this.sign;
        static if (!is(Q == typeof(null)))
        {
            q.contract();
            swap(q, quotient);
            quotient.sign = sign;
        }
        static if (ARGS.length == 1)
        {
            x >>= norm;
            swap(x, args[0]);
        }
    }

    private Integer square() nothrow @safe @nogc
    {
        Integer result;
        const resultSize = 2 * this.size + 1;

        result.grow(resultSize);
        result.size = resultSize;

        for (size_t i; i < this.size; ++i)
        {
            const doubleI = 2 * i;
            word product = cast(word) result.rep[doubleI]
                         + (cast(word) this.rep[i] * this.rep[i]);

            result.rep[doubleI] = product & mask;

            word carry = product >> digitBitCount;
            size_t k = doubleI + 1;

            for (auto j = i + 1; j < this.size; ++j, ++k)
            {
                product = (cast(word) this.rep[i]) * (cast(word) this.rep[j]);
                product = (cast(word) result.rep[k]) + (2 * product) + carry;

                result.rep[k] = product & mask;
                carry = product >> digitBitCount;
            }
            for (; carry != 0; ++k)
            {
                product = (cast(word) result.rep[k]) + carry;
                result.rep[k] = product & mask;
                carry = product >> digitBitCount;
            }
        }
        result.contract();

        return result;
    }

    // Returns 2^^n.
    private Integer exp2(size_t n) const nothrow @safe @nogc
    {
        auto ret = Integer(allocator);
        const bytes = n / digitBitCount;

        ret.grow(bytes + 1);
        ret.size = bytes + 1;
        ret.rep[bytes] = (cast(digit) 1) << (n % digitBitCount);

        return ret;
    }

    /**
     * Returns: Two's complement representation of the integer.
     */
    Array!ubyte toArray() const nothrow @safe @nogc
    out (array)
    {
        assert(array.length == length);
    }
    body
    {
        Array!ubyte array;

        if (this.size == 0)
        {
            return array;
        }
        const bc = countBits();
        const remainingBits = bc & 0x07;

        array.reserve(bc / 8);
        if (remainingBits == 0)
        {
            array.insertBack(ubyte.init);

        }

        Integer tmp;
        if (this.sign)
        {
            auto length = bc + (8 - remainingBits);

            if (((countLSBs() + 1) == bc) && (remainingBits == 0))
            {
                length -= 8;
            }

            tmp = exp2(length) + this;
        }
        else
        {
            tmp = this;
        }

        do
        {
            array.insertBack(cast(ubyte) (tmp.rep[0] & 0xff));
            tmp >>= 8;
        }
        while (tmp != 0);

        array[].reverse();

        return array;
    }

    ///
    nothrow @safe @nogc unittest
    {
        {
            auto integer = Integer(0x66778899aabbddee);
            ubyte[8] expected = [ 0x66, 0x77, 0x88, 0x99, 0xaa, 0xbb, 0xdd, 0xee ];

            auto array = integer.toArray();
            assert(equal(array[], expected[]));
        }
        {
            auto integer = Integer(0x03);
            ubyte[1] expected = [ 0x03 ];

            auto array = integer.toArray();
            assert(equal(array[], expected[]));
        }
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
        {
            ubyte[14] expected = [
                0x22, 0x33, 0x44, 0x55, 0x05, 0x06, 0x07,
                0x08, 0x3a, 0x3b, 0x00, 0x61, 0x62, 0x63,
            ];
            auto integer = Integer(Sign.positive, expected[]);

            auto array = integer.toArray();
            assert(equal(array[], expected[]));
        }
    }

    mixin DefaultAllocator;
}
