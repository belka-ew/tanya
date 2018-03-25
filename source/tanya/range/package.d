/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * This package contains generic functions and templates to be used with D
 * ranges.
 *
 * Copyright: Eugene Wissner 2017-2018.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/range/package.d,
 *                 tanya/range/package.d)
 */
module tanya.range;

import tanya.algorithm.mutation;
import tanya.math;
public import tanya.range.array;
public import tanya.range.primitive;

/**
 *
 */
struct Take(R)
if (isInputRange!R)
{
    private R source;
    size_t length_;

    @disable this();

    private this(R source, size_t length)
    {
        this.source = source;
        static if (hasLength!R)
        {
            this.length_ = min(source.length, length);
        }
        else
        {
            this.length_ = length;
        }
    }

    @property auto ref front()
    in
    {
        assert(!empty);
    }
    do
    {
        return this.source.front;
    }

    void popFront()
    in
    {
        assert(!empty);
    }
    do
    {
        this.source.popFront();
        --this.length_;
    }

    @property bool empty()
    {
        static if (isInfinite!R)
        {
            return length == 0;
        }
        else
        {
            return length == 0 || this.source.empty;
        }
    }

    @property size_t length()
    {
        return this.length_;
    }

    static if (hasMobileElements!R)
    {
        auto moveFront()
        in
        {
            assert(!empty);
        }
        do
        {
            return this.source.moveFront();
        }
    }
    static if (hasAssignableElements!R)
    {
        @property void front(ref ElementType!R value)
        in
        {
            assert(!empty);
        }
        do
        {
            this.source.front = value;
        }

        @property void front(ElementType!R value)
        in
        {
            assert(!empty);
        }
        do
        {
            this.source.front = move(value);
        }
    }

    static if (isForwardRange!R)
    {
        typeof(this) save()
        {
            return typeof(this)(this.source.save(), length);
        }
    }
    static if (isRandomAccessRange!R)
    {
        @property auto ref back()
        in
        {
            assert(!empty);
        }
        do
        {
            return this.source[this.length - 1];
        }

        void popBack()
        in
        {
            assert(!empty);
        }
        do
        {
            --this.length_;
        }

        auto ref opIndex(size_t i)
        in
        {
            assert(i < length);
        }
        do
        {
            return this.source[i];
        }

        static if (hasMobileElements!R)
        {
            auto moveBack()
            in
            {
                assert(!empty);
            }
            do
            {
                return this.source.moveAt(length - 1);
            }

            auto moveAt(size_t i)
            in
            {
                assert(i < length);
            }
            do
            {
                return this.source.moveAt(i);
            }
        }
        static if (hasAssignableElements!R)
        {
            @property void back(ref ElementType!R value)
            in
            {
                assert(!empty);
            }
            do
            {
                this.source[length - 1] = value;
            }

            @property void back(ElementType!R value)
            in
            {
                assert(!empty);
            }
            do
            {
                this.source[length - 1] = move(value);
            }

            void opIndexAssign(ref ElementType!R value, size_t i)
            in
            {
                assert(i < length);
            }
            do
            {
                this.source[i] = value;
            }

            void opIndexAssign(ElementType!R value, size_t i)
            in
            {
                assert(i < length);
            }
            do
            {
                this.source[i] = move(value);
            }
        }
    }
    static if (hasSlicing!R)
    {
        auto opSlice(size_t i, size_t j)
        in
        {
            assert(i <= j);
            assert(j <= length);
        }
        do
        {
            return take(this.source[i .. j], length);
        }
    }
}

/**
 * ditto
 */
Take!R take(R)(R range, size_t n)
if (isInputRange!R)
{
    return Take!R(range, n);
}

///
@nogc nothrow pure @safe unittest
{
    static struct InfiniteRange
    {
        private size_t front_ = 1;

        enum bool empty = false;

        @property size_t front() @nogc nothrow pure @safe
        {
            return this.front_;
        }

        @property void front(size_t i) @nogc nothrow pure @safe
        {
            this.front_ = i;
        }

        void popFront() @nogc nothrow pure @safe
        {
            ++this.front_;
        }
        
        size_t opIndex(size_t i) @nogc nothrow pure @safe
        {
            return this.front_ + i;
        }

        void opIndexAssign(size_t value, size_t i) @nogc nothrow pure @safe
        {
            this.front = i + value;
        }

        InfiniteRange save() @nogc nothrow pure @safe
        {
            return this;
        }
    }

    auto t = InfiniteRange().take(3);
    assert(t.length == 3);
    assert(t.front == 1);
    assert(t.back == 3);

    t.popFront();
    assert(t.front == 2);
    assert(t.back == 3);

    t.popBack();
    assert(t.front == 2);
    assert(t.back == 2);

    t.popFront();
    assert(t.empty);
}
