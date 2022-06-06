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
 * Copyright: Eugene Wissner 2018-2021.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/algorithm/iteration.d,
 *                 tanya/algorithm/iteration.d)
 */
module tanya.algorithm.iteration;

import std.typecons;
import tanya.memory.lifetime;
import tanya.meta.trait;
import tanya.meta.transform;
import tanya.range;

private struct SingletonByValue(E)
{
    private Nullable!E element;

    @disable this();

    private this(U)(ref U element)
    if (is(U == E))
    {
        this.element = move(element);
    }

    private this(U)(ref U element)
    if (is(Unqual!U == Nullable!(Unqual!E)) || is(Unqual!U == Nullable!(const E)))
    {
        if (!element.isNull)
        {
            this.element = element.get;
        }
    }

    @property ref inout(E) front() inout
    in
    {
        assert(!empty);
    }
    do
    {
        return this.element.get;
    }

    alias back = front;

    void popFront()
    in
    {
        assert(!empty);
    }
    do
    {
        this.element.nullify();
    }

    alias popBack = popFront;

    @property bool empty() const
    {
        return this.element.isNull;
    }

    @property size_t length() const
    {
        return !this.element.isNull;
    }

    auto save()
    {
        return SingletonByValue!E(this.element);
    }

    ref inout(E) opIndex(size_t i) inout
    in
    {
        assert(!empty);
        assert(i == 0);
    }
    do
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
    in
    {
        assert(!empty);
    }
    do
    {
        return *this.element;
    }

    alias back = front;

    void popFront()
    in
    {
        assert(!empty);
    }
    do
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

    ref inout(E) opIndex(size_t i) inout return
    in
    {
        assert(!empty);
        assert(i == 0);
    }
    do
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
 * $(D_PSYMBOL foldr) takes a function, a bidirectional range and the initial
 * value. The function takes this initial value and the first element of the
 * range (in this order), puts them together and returns the result. The return
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
    auto foldr(R, T)(scope R range, auto ref T init)
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
