/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
module tanya.range.tests.primitive;

import tanya.range;
import tanya.test.stub;

private struct AssertPostblit
{
    this(this) @nogc nothrow pure @safe
    {
        assert(false);
    }
}

@nogc nothrow pure @safe unittest
{
    static struct Range1(T)
    {
        mixin InputRangeStub;

        T empty() const
        {
            return true;
        }
    }
    static assert(!isInputRange!(Range1!int));
    static assert(!isInputRange!(Range1!(const bool)));

    static struct Range2
    {
        mixin InputRangeStub;

        int popFront() @nogc nothrow pure @safe
        {
            return 100;
        }
    }
    static assert(isInputRange!Range2);

    static struct Range3
    {
        mixin InputRangeStub;

        void front() @nogc nothrow pure @safe
        {
        }
    }
    static assert(!isInputRange!Range3);

    static struct Range4
    {
        mixin InputRangeStub;

        enum bool empty = false;
    }
    static assert(isInputRange!Range4);
}

// Ranges with non-copyable elements can be input ranges
@nogc nothrow pure @safe unittest
{
    @WithLvalueElements
    static struct R
    {
        mixin InputRangeStub!NonCopyable;
    }
    static assert(isInputRange!R);
}

// Ranges with const non-copyable elements can be input ranges
@nogc nothrow pure @safe unittest
{
    @WithLvalueElements
    static struct R
    {
        mixin InputRangeStub!(const(NonCopyable));
    }
    static assert(isInputRange!R);
}

@nogc nothrow pure @safe unittest
{
    static struct Range1
    {
    }
    static struct Range2
    {
        mixin InputRangeStub;

        Range1 save() @nogc nothrow pure @safe
        {
            return Range1();
        }
    }
    static assert(!isForwardRange!Range2);

    static struct Range3
    {
        mixin InputRangeStub;

        const(typeof(this)) save() const @nogc nothrow pure @safe
        {
            return this;
        }
    }
    static assert(!isForwardRange!Range3);
}

@nogc nothrow pure @safe unittest
{
    static struct Range(T, U)
    {
        mixin BidirectionalRangeStub;

        @property T front() @nogc nothrow pure @safe
        {
            return T.init;
        }

        @property U back() @nogc nothrow pure @safe
        {
            return U.init;
        }
    }
    static assert(!isBidirectionalRange!(Range!(int, uint)));
    static assert(!isBidirectionalRange!(Range!(int, const int)));
}

// Ranges with non-copyable elements can be bidirectional ranges
@nogc nothrow pure @safe unittest
{
    @WithLvalueElements
    static struct R
    {
        mixin BidirectionalRangeStub!NonCopyable;
    }
    static assert(isBidirectionalRange!R);
}

@nogc nothrow pure @safe unittest
{
    static struct Range1
    {
        mixin BidirectionalRangeStub;
        mixin RandomAccessRangeStub;
    }
    static assert(!isRandomAccessRange!Range1);

    @Length
    static struct Range2(Args...)
    {
        mixin BidirectionalRangeStub;

        int opIndex(Args) @nogc nothrow pure @safe
        {
            return 0;
        }
    }
    static assert(isRandomAccessRange!(Range2!size_t));
    static assert(!isRandomAccessRange!(Range2!()));
    static assert(!isRandomAccessRange!(Range2!(size_t, size_t)));

    @Length
    static struct Range3
    {
        mixin BidirectionalRangeStub;

        int opIndex(const size_t pos1, const size_t pos2 = 0)
        @nogc nothrow pure @safe
        {
            return 0;
        }
    }
    static assert(isRandomAccessRange!Range3);

    static struct Range4
    {
        mixin BidirectionalRangeStub;
        mixin RandomAccessRangeStub;

        size_t opDollar() const @nogc nothrow pure @safe
        {
            return 0;
        }
    }
    static assert(!isRandomAccessRange!Range4);
}

// Ranges with non-copyable elements can be random-access ranges
@nogc nothrow pure @safe unittest
{
    @WithLvalueElements @Infinite
    static struct R
    {
        mixin RandomAccessRangeStub!NonCopyable;
    }
    static assert(isRandomAccessRange!R);
}

@nogc nothrow pure @safe unittest
{
    @Infinite
    static struct StaticConstRange
    {
        mixin InputRangeStub;

        static bool empty = false;
    }
    static assert(!isInfinite!StaticConstRange);

    @Infinite
    static struct TrueRange
    {
        mixin InputRangeStub;

        static const bool empty = true;
    }
    static assert(!isInfinite!TrueRange);
}

@nogc nothrow pure @safe unittest
{
    @Infinite
    static struct InfiniteRange
    {
        mixin ForwardRangeStub;
        private int i;

        void popFront() @nogc nothrow pure @safe
        {
            ++this.i;
        }

        void popBack() @nogc nothrow pure @safe
        {
            --this.i;
        }

        @property int front() const @nogc nothrow pure @safe
        {
            return this.i;
        }

        @property int back() const @nogc nothrow pure @safe
        {
            return this.i;
        }
    }
    {
        InfiniteRange range;
        popFrontExactly(range, 2);
        assert(range.front == 2);
        popFrontN(range, 2);
        assert(range.front == 4);
    }
    {
        InfiniteRange range;
        popBackExactly(range, 2);
        assert(range.back == -2);
        popBackN(range, 2);
        assert(range.back == -4);
    }
}

@nogc nothrow pure @safe unittest
{
    static struct Range
    {
        private int[5] a = [1, 2, 3, 4, 5];
        private size_t begin = 0, end = 5;

        Range save() @nogc nothrow pure @safe
        {
            return this;
        }

        void popFront() @nogc nothrow pure @safe
        {
            ++this.begin;
        }

        void popBack() @nogc nothrow pure @safe
        {
            --this.end;
        }

        @property int front() const @nogc nothrow pure @safe
        {
            return this.a[this.begin];
        }

        @property int back() const @nogc nothrow pure @safe
        {
            return this.a[this.end - 1];
        }

        @property bool empty() const @nogc nothrow pure @safe
        {
            return this.begin >= this.end;
        }
    }
    {
        Range range;

        popFrontN(range, 3);
        assert(range.front == 4);
        assert(range.back == 5);

        popFrontN(range, 20);
        assert(range.empty);
    }
    {
        Range range;

        popBackN(range, 3);
        assert(range.front == 1);
        assert(range.back == 2);

        popBackN(range, 20);
        assert(range.empty);
    }
}

@nogc nothrow pure @safe unittest
{
    // Returns its elements by reference.
    @Infinite @WithLvalueElements
    static struct R1
    {
        mixin InputRangeStub!AssertPostblit;
    }
    static assert(is(typeof(moveFront(R1()))));

    // Returns elements with a postblit constructor by value. moveFront fails.
    @Infinite
    static struct R2
    {
        mixin InputRangeStub!AssertPostblit;
    }
    static assert(!is(typeof(moveFront(R2()))));
}

@nogc nothrow pure @safe unittest
{
    // Returns its elements by reference.
    @Infinite @WithLvalueElements
    static struct R1
    {
        mixin BidirectionalRangeStub!AssertPostblit;
    }
    static assert(is(typeof(moveBack(R1()))));

    // Returns elements with a postblit constructor by value. moveBack fails.
    @Infinite
    static struct R2
    {
        mixin BidirectionalRangeStub!AssertPostblit;
    }
    static assert(!is(typeof(moveBack(R2()))));
}

@nogc nothrow pure @safe unittest
{
    // Returns its elements by reference.
    @Infinite @WithLvalueElements
    static struct R1
    {
        mixin RandomAccessRangeStub!AssertPostblit;
    }
    static assert(is(typeof(moveAt(R1(), 0))));

    // Returns elements with a postblit constructor by value. moveAt fails.
    @Infinite
    static struct R2
    {
        mixin RandomAccessRangeStub!AssertPostblit;
    }
    static assert(!is(typeof(moveAt(R2(), 0))));
}

// Works with non-copyable elements
@nogc nothrow pure @safe unittest
{
    static assert(hasLvalueElements!(NonCopyable[]));
}
