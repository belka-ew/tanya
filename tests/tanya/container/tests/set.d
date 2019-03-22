/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
module tanya.container.tests.set;

import tanya.container.set;
import tanya.memory.allocator;
import tanya.test.stub;

// Basic insertion logic.
@nogc nothrow pure @safe unittest
{
    Set!int set;

    assert(set.insert(5) == 1);
    assert(5 in set);
    assert(set.capacity == 3);

    assert(set.insert(5) == 0);
    assert(5 in set);
    assert(set.capacity == 3);

    assert(set.insert(9) == 1);
    assert(9 in set);
    assert(5 in set);
    assert(set.capacity == 3);

    assert(set.insert(7) == 1);
    assert(set.insert(8) == 1);
    assert(8 in set);
    assert(5 in set);
    assert(9 in set);
    assert(7 in set);
    assert(set.capacity == 7);

    assert(set.insert(16) == 1);
    assert(16 in set);
    assert(set.capacity == 7);
}

// Static checks.
@nogc nothrow pure @safe unittest
{
    import tanya.range.primitive;

    static assert(isBidirectionalRange!(Set!int.ConstRange));
    static assert(isBidirectionalRange!(Set!int.Range));

    static assert(!isInfinite!(Set!int.Range));
    static assert(!hasLength!(Set!int.Range));

    static assert(is(Set!uint));
    static assert(is(Set!long));
    static assert(is(Set!ulong));
    static assert(is(Set!short));
    static assert(is(Set!ushort));
    static assert(is(Set!bool));
}

@nogc nothrow pure @safe unittest
{
    const Set!int set;
    assert(set[].empty);
}

@nogc nothrow pure @safe unittest
{
    Set!int set;
    set.insert(8);

    auto r1 = set[];
    auto r2 = r1.save();

    r1.popFront();
    assert(r1.empty);

    r2.popBack();
    assert(r2.empty);
}

// Initial capacity is 0.
@nogc nothrow pure @safe unittest
{
    auto set = Set!int(defaultAllocator);
    assert(set.capacity == 0);
}

// Capacity is set to a prime.
@nogc nothrow pure @safe unittest
{
    auto set = Set!int(8);
    assert(set.capacity == 13);
}

// Constructs by reference
@nogc nothrow pure @safe unittest
{
    auto set1 = Set!int(7);
    auto set2 = Set!int(set1);
    assert(set1.length == set2.length);
    assert(set1.capacity == set2.capacity);
}

// Constructs by value
@nogc nothrow pure @safe unittest
{
    auto set = Set!int(Set!int(7));
    assert(set.capacity == 7);
}

// Assigns by reference
@nogc nothrow pure @safe unittest
{
    auto set1 = Set!int(7);
    Set!int set2;
    set1 = set2;
    assert(set1.length == set2.length);
    assert(set1.capacity == set2.capacity);
}

// Assigns by value
@nogc nothrow pure @safe unittest
{
    Set!int set;
    set = Set!int(7);
    assert(set.capacity == 7);
}

// Postblit copies
@nogc nothrow pure @safe unittest
{
    auto set = Set!int(7);
    void testFunc(Set!int set)
    {
        assert(set.capacity == 7);
    }
    testFunc(set);
}

// Hasher can take argument by ref
@nogc nothrow pure @safe unittest
{
    static assert(is(Set!(int, (const ref x) => cast(size_t) x)));
}

// Can have non-copyable elements
@nogc nothrow pure @safe unittest
{
    @NonCopyable @Hashable
    static struct S
    {
        mixin StructStub;
    }
    static assert(is(Set!S));
}
