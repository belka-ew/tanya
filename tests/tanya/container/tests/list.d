/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
module tanya.container.tests.list;

import tanya.container.list;
import tanya.test.stub;

@nogc nothrow pure @safe unittest
{
    interface Stuff
    {
    }
    static assert(is(SList!Stuff));
}

@nogc nothrow pure @safe unittest
{
    auto l = SList!int(0, 0);
    assert(l.empty);
}

// foreach called using opIndex().
@nogc nothrow pure @safe unittest
{
    SList!int l;
    size_t i;

    l.insertFront(5);
    l.insertFront(4);
    l.insertFront(9);
    foreach (e; l)
    {
        assert(i != 0 || e == 9);
        assert(i != 1 || e == 4);
        assert(i != 2 || e == 5);
        ++i;
    }
}

@nogc nothrow pure @safe unittest
{
    auto l1 = SList!int();
    auto l2 = SList!int([9, 4]);
    l1 = l2[];
    assert(l1 == l2);
}

@nogc nothrow pure @safe unittest
{
    class A
    {
    }
    static assert(is(SList!(A*)));
    static assert(is(DList!(A*)));
}

// Removes all elements
@nogc nothrow pure @safe unittest
{
    auto l = DList!int([5]);
    assert(l.remove(l[]).empty);
}

@nogc nothrow pure @safe unittest
{
    auto l1 = DList!int([5, 234, 30, 1]);
    auto l2 = DList!int([5, 1]);
    auto r = l1[];

    r.popFront();
    r.popBack();
    assert(r.front == 234);
    assert(r.back == 30);

    assert(!l1.remove(r).empty);
    assert(l1 == l2);
}

@nogc nothrow pure @safe unittest
{
    auto l = DList!int(0, 0);
    assert(l.empty);
}

@nogc nothrow pure @safe unittest
{
    DList!int l;
    l.insertAfter(l[], 234);
    assert(l.front == 234);
    assert(l.back == 234);
}

@nogc nothrow pure @safe unittest
{
    auto l1 = DList!int();
    auto l2 = DList!int([9, 4]);
    l1 = l2[];
    assert(l1 == l2);
}

// Sets the new head
@nogc nothrow pure @safe unittest
{
    auto l1 = DList!int([5, 234, 30, 1]);
    auto l2 = DList!int([1]);
    auto r = l1[];

    r.popBack();

    assert(!l1.remove(r).empty);
    assert(l1 == l2);
}

// Can have non-copyable elements
@nogc nothrow pure @safe unittest
{
    static assert(is(SList!NonCopyable));
    static assert(is(DList!NonCopyable));
}
