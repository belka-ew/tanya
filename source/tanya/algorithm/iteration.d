/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Iteration algorithms.
 *
 * These algorithms wrap other ranges and modify the way, how the original
 * range is iterated, or the order in which its elements are accessed.
 *
 * All algorithms in this module are lazy, they request the next element of the
 * original range on demand.
 *
 * Copyright: Eugene Wissner 2018-2020.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/algorithm/iteration.d,
 *                 tanya/algorithm/iteration.d)
 */
module tanya.algorithm.iteration;

import std.algorithm.comparison;
import tanya.memory.lifetime;
import tanya.meta.trait;
import tanya.meta.transform;
import tanya.range;
import tanya.typecons;

// These predicates are used to help preserve `const` and `inout` for
// ranges built on other ranges.

private enum hasInoutFront(T) = is(typeof((inout ref T a) => a.front));
private enum hasInoutBack(T) = is(typeof((inout ref T a) => a.back));
private enum hasInoutIndex(T) = is(typeof((inout ref T a, size_t i) => a[i]));

private enum hasConstEmpty(T) = is(typeof(((const T* a) => (*a).empty)(null)) : bool);
private enum hasConstLength(T) = is(typeof(((const T* a) => (*a).length)(null)) : size_t);
private enum hasConstSave(T) = is(typeof(((const T* a) => (*a).save())(null)) : T);
private enum hasConstSlice(T) = is(typeof(((const T* a) => (*a)[0 .. $])(null)) : T);

@nogc nothrow pure @safe unittest
{
    // Test the definitions.
    static assert(hasInoutFront!string);
    static assert(hasInoutBack!string);
    static assert(hasInoutIndex!string);
    static assert(hasConstEmpty!string);
    static assert(hasConstLength!string);
    static assert(hasConstSave!string);
    static assert(hasConstSlice!string);

    // Test that Take propagates const/inout correctly.
    alias TakeString = Take!(string, false);
    static assert(hasInoutFront!TakeString);
    static assert(hasInoutBack!TakeString);
    static assert(hasInoutIndex!TakeString);
    static assert(hasConstEmpty!TakeString);
    static assert(hasConstLength!TakeString);
    static assert(hasConstSave!TakeString);
    static assert(hasConstSlice!TakeString);

    // Test that Retro propagates const/inout correctly.
    alias RetroString = Retro!string;
    static assert(hasInoutFront!RetroString);
    static assert(hasInoutBack!RetroString);
    static assert(hasInoutIndex!RetroString);
    static assert(hasConstEmpty!RetroString);
    static assert(hasConstLength!RetroString);
    static assert(hasConstSave!RetroString);
    static assert(hasConstSlice!RetroString);
}

private struct Take(R, bool exactly)
{
    private R source;
    size_t length_;

    @disable this();

    private this(R source, size_t length)
    {
        this.source = source;
        static if (!exactly && hasLength!R)
        {
            this.length_ = min(source.length, length);
        }
        else
        {
            this.length_ = length;
        }
    }

    mixin(`@property auto ref front() ` ~ (hasInoutFront!R ? `inout ` : ``) ~
    `in (!empty)
    {
        return this.source.front;
    }`);

    void popFront()
    in (!empty)
    {
        this.source.popFront();
        --this.length_;
    }

    mixin(`@property bool empty() ` ~ (exactly || isInfinite!R || hasConstEmpty!R ? `const ` : ``) ~
    `{
        static if (exactly || isInfinite!R)
        {
            return length == 0;
        }
        else
        {
            return this.length_ == 0 || this.source.empty;
        }
    }`);

    static if (exactly || hasLength!R)
    {
        @property size_t length() const
        {
            return this.length_;
        }
    }

    static if (hasAssignableElements!R)
    {
        @property void front(ref ElementType!R value)
        in (!empty)
        {
            this.source.front = value;
        }

        @property void front(ElementType!R value)
        in (!empty)
        {
            this.source.front = move(value);
        }
    }

    static if (isForwardRange!R)
    {
        mixin(`typeof(this) save() ` ~ (hasConstSave!R ? `const ` : ``) ~
        `{
            return typeof(this)(this.source.save(), length);
        }`);
    }
    static if (isRandomAccessRange!R)
    {
        mixin(`@property auto ref back() ` ~ (hasInoutBack!R ? `inout ` : ``) ~
        `in (!empty)
        {
            return this.source[this.length - 1];
        }`);

        void popBack()
        in (!empty)
        {
            --this.length_;
        }

        mixin(`auto ref opIndex(size_t i) ` ~ (hasInoutIndex!R ? `inout ` : ``) ~
        `in (i < length)
        {
            return this.source[i];
        }`);

        static if (hasAssignableElements!R)
        {
            @property void back(ref ElementType!R value)
            in (!empty)
            {
                this.source[length - 1] = value;
            }

            @property void back(ElementType!R value)
            in (!empty)
            {
                this.source[length - 1] = move(value);
            }

            void opIndexAssign(ref ElementType!R value, size_t i)
            in (i < length)
            {
                this.source[i] = value;
            }

            void opIndexAssign(ElementType!R value, size_t i)
            in (i < length)
            {
                this.source[i] = move(value);
            }
        }
    }

    static if (!exactly && hasSlicing!R)
    {
        static if (is(typeof(length))) alias opDollar = length;

        mixin(`auto opSlice(size_t i, size_t j) ` ~ (hasConstSlice!R ? `const ` : ``) ~
        `in (i <= j)
        in (j <= length)
        {
            return typeof(this)(this.source[i .. j], length);
        }`);
    }

    version (unittest) static assert(isInputRange!Take);
}

/**
 * Takes $(D_PARAM n) elements from $(D_PARAM range).
 *
 * If $(D_PARAM range) doesn't have $(D_PARAM n) elements, the resulting range
 * spans all elements of $(D_PARAM range).
 *
 * $(D_PSYMBOL take) is particulary useful with infinite ranges. You can take
 ` $(B n) elements from such range and pass the result to an algorithm which
 * expects a finit range.
 *
 * Params:
 *  R     = Type of the adapted range.
 *  range = The range to take the elements from.
 *  n     = The number of elements to take.
 *
 * Returns: A range containing maximum $(D_PARAM n) first elements of
 *          $(D_PARAM range).
 *
 * See_Also: $(D_PSYMBOL takeExactly).
 */
auto take(R)(R range, size_t n)
if (isInputRange!R)
{
    static if (hasSlicing!R && hasLength!R)
    {
        if (range.length <= n)
            return range;
        else
            return range[0 .. n];
    }
    // Special case: take(take(...), n)
    else static if (is(Range == Take!(RRange, exact), RRange, bool exact))
    {
        if (n > range.length_)
            n = range.length_;
        static if (exact)
            // `take(takeExactly(r, n0), n)` is rewritten `takeExactly(r, min(n0, n))`.
            return Take!(RRange, true)(range.source, n);
        else
            // `take(take(r, n0), n)` is rewritten `take(r, min(n0, n))`.
            return Take!(RRange, false)(range.source, n);
    }
    else static if (isInfinite!R)
    {
        // If the range is infinite then `take` is the same as `takeExactly`.
        return Take!(R, true)(range, n);
    }
    else
    {
        return Take!(R, false)(range, n);
    }
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

/**
 * Takes exactly $(D_PARAM n) elements from $(D_PARAM range).
 *
 * $(D_PARAM range) must have at least $(D_PARAM n) elements.
 *
 * $(D_PSYMBOL takeExactly) is particulary useful with infinite ranges. You can
 ` take $(B n) elements from such range and pass the result to an algorithm
 * which expects a finit range.
 *
 * Params:
 *  R     = Type of the adapted range.
 *  range = The range to take the elements from.
 *  n     = The number of elements to take.
 *
 * Returns: A range containing $(D_PARAM n) first elements of $(D_PARAM range).
 *
 * See_Also: $(D_PSYMBOL take).
 */
auto takeExactly(R)(R range, size_t n)
if (isInputRange!R)
{
    static if (hasSlicing!R)
    {
        return range[0 .. n];
    }
    // Special case: takeExactly(take(range, ...), n) is takeExactly(range, n)
    else static if (is(Range == Take!(RRange, exact), RRange, bool exact))
    {
        assert(n <= range.length_);
        return Take!(RRange, true)(range.source, n);
    }
    else
    {
        return Take!(R, true)(range, n);
    }
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

    auto t = InfiniteRange().takeExactly(3);
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

// Reverse-access-order range returned by `retro`.
private struct Retro(Range)
{
    Range source;

    @disable this();

    private this(Range source) @safe
    {
        this.source = source;
    }

    mixin(`Retro save() ` ~ (hasConstSave!Range ? `const ` : ``) ~
    `{
        return Retro(source.save());
    }`);

    mixin(`@property auto ref front() ` ~ (hasInoutBack!Range ? `inout ` : ``) ~
    `in (!empty)
    {
        return this.source.back;
    }`);

    void popFront()
    in (!empty)
    {
        this.source.popBack();
    }

    mixin(`@property auto ref back() ` ~ (hasInoutFront!Range ? `inout ` : ``) ~
    `in (!empty)
    {
        return this.source.front;
    }`);

    void popBack()
    in (!empty)
    {
        this.source.popFront();
    }

    mixin(`@property bool empty() ` ~ (hasConstEmpty!Range ? `const ` : ``) ~
    `{
        return this.source.empty;
    }`);

    static if (hasLength!Range)
    {
        mixin(`@property size_t length() ` ~ (hasConstLength!Range ? `const ` : ``) ~
        `{
            return this.source.length;
        }`);
    }

    static if (isRandomAccessRange!Range && hasLength!Range)
    {
        mixin(`auto ref opIndex(size_t i) ` ~ (hasInoutIndex!Range ? `inout ` : ``) ~
        `in (i < length)
        {
            return this.source[$ - ++i];
        }`);
    }

    static if (hasLength!Range && hasSlicing!Range)
    {
        alias opDollar = length;

        mixin(`auto opSlice(size_t i, size_t j) ` ~ (hasConstSlice!Range ? `const ` : ``) ~
        `in (i <= j)
        in (j <= length)
        {
            return typeof(this)(this.source[$-j .. $-i]);
        }`);
    }

    static if (hasAssignableElements!Range)
    {
        @property void front(ref ElementType!Range value)
        in (!empty)
        {
            this.source.back = value;
        }

        @property void front(ElementType!Range value)
        in (!empty)
        {
            this.source.back = move(value);
        }

        @property void back(ref ElementType!Range value)
        in (!empty)
        {
            this.source.front = value;
        }

        @property void back(ElementType!Range value)
        in (!empty)
        {
            this.source.front = move(value);
        }

        static if (isRandomAccessRange!Range && hasLength!Range)
        {
            void opIndexAssign(ref ElementType!Range value, size_t i)
            in (i < length)
            {
                this.source[$ - ++i] = value;
            }

            void opIndexAssign(ElementType!Range value, size_t i)
            in (i < length)
            {
                this.source[$ - ++i] = move(value);
            }
        }
    }

    version (unittest) static assert(isBidirectionalRange!Retro);
}

/**
 * Iterates a bidirectional range backwards.
 *
 * If $(D_PARAM Range) is a random-access range as well, the resulting range
 * is a random-access range too.
 *
 * Params:
 *  Range = Bidirectional range type.
 *  range = Bidirectional range.
 *
 * Returns: Bidirectional range with the elements order reversed.
 */
auto retro(Range)(Range range)
if (isBidirectionalRange!Range)
{
    // Special case: retro(retro(range)) is range
    static if (is(Range == Retro!RRange, RRange))
        return range.source;
    else
        return Retro!Range(range);
}

///
@nogc nothrow pure @safe unittest
{
    const int[3] given = [1, 2, 3];
    const int[3] expected = [3, 2, 1];

    auto actual = retro(given[]);

    assert(actual.length == expected.length);
    assert(!actual.empty);
    assert(equal(actual, expected[]));
}

private struct SingletonByValue(E)
{
    private Option!E element;

    @disable this();

    private this(U)(ref U element)
    if (is(U == E))
    {
        this.element = move(element);
    }

    private this(U)(ref U element)
    if (is(Unqual!U == Option!(Unqual!E)) || is(Unqual!U == Option!(const E)))
    {
        if (!element.isNothing)
        {
            this.element = element.get;
        }
    }

    @property ref inout(E) front() inout
    in (!empty)
    {
        return this.element.get;
    }

    alias back = front;

    void popFront()
    in (!empty)
    {
        this.element.reset();
    }

    alias popBack = popFront;

    @property bool empty() const
    {
        return this.element.isNothing;
    }

    @property size_t length() const
    {
        return !this.element.isNothing;
    }

    auto save()
    {
        return SingletonByValue!E(this.element);
    }

    auto save() const
    {
        return SingletonByValue!(const E)(this.element);
    }

    ref inout(E) opIndex(size_t i) inout
    in (!empty)
    in (i == 0)
    {
        return this.element.get;
    }
}

private struct SingletonByRef(E)
{
    private E* element;

    @disable this();

    private this(return ref E element) @trusted
    {
        this.element = &element;
    }

    @property ref inout(E) front() inout return
    in (!empty)
    {
        return *this.element;
    }

    alias back = front;

    void popFront()
    in (!empty)
    {
        this.element = null;
    }

    alias popBack = popFront;

    @property bool empty() const
    {
        return this.element is null;
    }

    @property size_t length() const
    {
        return this.element !is null;
    }

    auto save() return
    {
        return typeof(this)(*this.element);
    }

    auto save() const return
    {
        return SingletonByRef!(const E)(*this.element);
    }

    ref inout(E) opIndex(size_t i) inout return
    in (!empty)
    in (i == 0)
    {
        return *this.element;
    }
}

/**
 * Creates a bidirectional and random-access range with the single element
 * $(D_PARAM element).
 *
 * If $(D_PARAM element) is passed by value the resulting range stores it
 * internally. If $(D_PARAM element) is passed by reference, the resulting
 * range keeps only a pointer to the element.
 *
 * Params:
 *  E       = Element type.
 *  element = Element.
 *
 * Returns: A range with one element.
 */
auto singleton(E)(return E element)
if (isMutable!E)
{
    return SingletonByValue!E(element);
}

/// ditto
auto singleton(E)(return ref E element)
{
    return SingletonByRef!E(element);
}

///
@nogc nothrow pure @safe unittest
{
    auto singleChar = singleton('a');

    assert(singleChar.length == 1);
    assert(singleChar.front == 'a');

    singleChar.popFront();
    assert(singleChar.empty);
}

/**
 * Accumulates all elements of a range using a function.
 *
 * $(D_PSYMBOL foldl) takes a function, an input range and the initial value.
 * The function takes this initial value and the first element of the range (in
 * this order), puts them together and returns the result. The return
 * type of the function should be the same as the type of the initial value.
 * This is than repeated for all the remaining elements of the range, whereby
 * the value returned by the passed function is used at the place of the
 * initial value.
 *
 * $(D_PSYMBOL foldl) accumulates from left to right.
 *
 * Params:
 *  F = Callable accepting the accumulator and a range element.
 */
template foldl(F...)
if (F.length == 1)
{
    /**
     * Params:
     *  R     = Input range type.
     *  T     = Type of the accumulated value.
     *  range = Input range.
     *  init  = Initial value.
     *
     * Returns: Accumulated value.
     */
    auto foldl(R, T)(R range, auto ref T init)
    if (isInputRange!R && !isInfinite!R)
    {
        if (range.empty)
        {
            return init;
        }
        else
        {
            auto acc = F[0](init, getAndPopFront(range));
            return foldl(range, acc);
        }
    }
}

///
@nogc nothrow pure @safe unittest
{
    int[3] range = [1, 2, 3];
    const actual = foldl!((acc, x) => acc + x)(range[], 0);

    assert(actual == 6);
}

/**
 * Accumulates all elements of a range using a function.
 *
 * $(D_PSYMBOL foldr) takes a function, an input range and the initial value.
 * The function takes this initial value and the first element of the range (in
 * this order), puts them together and returns the result. The return
 * type of the function should be the same as the type of the initial value.
 * This is than repeated for all the remaining elements of the range, whereby
 * the value returned by the passed function is used at the place of the
 * initial value.
 *
 * $(D_PSYMBOL foldr) accumulates from right to left.
 *
 * Params:
 *  F = Callable accepting the accumulator and a range element.
 */
template foldr(F...)
if (F.length == 1)
{
    /**
     * Params:
     *  R     = Bidirectional range type.
     *  T     = Type of the accumulated value.
     *  range = Bidirectional range.
     *  init  = Initial value.
     *
     * Returns: Accumulated value.
     */
    auto foldr(R, T)(R range, auto ref T init)
    if (isBidirectionalRange!R)
    {
        if (range.empty)
        {
            return init;
        }
        else
        {
            auto acc = F[0](init, getAndPopBack(range));
            return foldr(range, acc);
        }
    }
}

///
@nogc nothrow pure @safe unittest
{
    int[3] range = [1, 2, 3];
    int[3] output;
    const int[3] expected = [3, 2, 1];

    alias f = (acc, x) {
        acc.front = x;
        acc.popFront;
        return acc;
    };
    const actual = foldr!f(range[], output[]);

    assert(output[] == expected[]);
}
