/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
module tanya.container.tests.array;

import tanya.algorithm.comparison;
import tanya.container.array;
import tanya.memory;
import tanya.test.stub;

// const arrays return usable ranges
@nogc nothrow pure @safe unittest
{
    auto v = const Array!int([1, 2, 4]);
    auto r1 = v[];

    assert(r1.back == 4);
    r1.popBack();
    assert(r1.back == 2);
    r1.popBack();
    assert(r1.back == 1);
    r1.popBack();
    assert(r1.length == 0);

    static assert(!is(typeof(r1[0] = 5)));
    static assert(!is(typeof(v[0] = 5)));

    const r2 = r1[];
    static assert(is(typeof(r2[])));
}

@nogc nothrow pure @safe unittest
{
    Array!int v1;
    const Array!int v2;

    auto r1 = v1[];
    auto r2 = v1[];

    assert(r1.length == 0);
    assert(r2.empty);
    assert(r1 == r2);

    v1.insertBack([1, 2, 4]);
    assert(v1[] == v1);
    assert(v2[] == v2);
    assert(v2[] != v1);
    assert(v1[] != v2);
    assert(v1[].equal(v1[]));
    assert(v2[].equal(v2[]));
    assert(!v1[].equal(v2[]));
}

@nogc nothrow pure @safe unittest
{
    struct MutableEqualsStruct
    {
        bool opEquals(typeof(this) that) @nogc nothrow pure @safe
        {
            return true;
        }
    }
    struct ConstEqualsStruct
    {
        bool opEquals(const typeof(this) that) const @nogc nothrow pure @safe
        {
            return true;
        }
    }
    auto v1 = Array!ConstEqualsStruct();
    auto v2 = Array!ConstEqualsStruct();
    assert(v1 == v2);
    assert(v1[] == v2);
    assert(v1 == v2[]);
    assert(v1[].equal(v2[]));

    auto v3 = const Array!ConstEqualsStruct();
    auto v4 = const Array!ConstEqualsStruct();
    assert(v3 == v4);
    assert(v3[] == v4);
    assert(v3 == v4[]);
    assert(v3[].equal(v4[]));

    auto v7 = Array!MutableEqualsStruct(1, MutableEqualsStruct());
    auto v8 = Array!MutableEqualsStruct(1, MutableEqualsStruct());
    assert(v7 == v8);
    assert(v7[] == v8);
    assert(v7 == v8[]);
    assert(v7[].equal(v8[]));
}

// Destructor can destroy empty arrays
@nogc nothrow pure @safe unittest
{
    auto v = Array!WithDtor();
}

@nogc nothrow pure @safe unittest
{
    class A
    {
    }
    A a1, a2;
    auto v1 = Array!A([a1, a2]);

    static assert(is(Array!(A*)));
}

@nogc nothrow pure @safe unittest
{
    auto v = Array!int([5, 15, 8]);
    {
        size_t i;

        foreach (e; v)
        {
            assert(i != 0 || e == 5);
            assert(i != 1 || e == 15);
            assert(i != 2 || e == 8);
            ++i;
        }
        assert(i == 3);
    }
    {
        size_t i = 3;

        foreach_reverse (e; v)
        {
            --i;
            assert(i != 2 || e == 8);
            assert(i != 1 || e == 15);
            assert(i != 0 || e == 5);
        }
        assert(i == 0);
    }
}

// const constructor tests
@nogc nothrow pure @safe unittest
{
    auto v1 = const Array!int([1, 2, 3]);
    auto v2 = Array!int(v1);
    assert(v1.get !is v2.get);
    assert(v1 == v2);

    auto v3 = const Array!int(Array!int([1, 2, 3]));
    assert(v1 == v3);
    assert(v3.length == 3);
    assert(v3.capacity == 3);
}

@nogc nothrow pure @safe unittest
{
    auto v1 = Array!int(defaultAllocator);
}

@nogc nothrow pure @safe unittest
{
    Array!int v;
    auto r = v[];
    assert(r.length == 0);
    assert(r.empty);
}

@nogc nothrow pure @safe unittest
{
    auto v1 = const Array!int([5, 15, 8]);
    Array!int v2;
    v2 = v1[0 .. 2];
    assert(equal(v1[0 .. 2], v2[]));
}

// Move assignment
@nogc nothrow pure @safe unittest
{
    Array!int v1;
    v1 = Array!int([5, 15, 8]);
}

// Postblit is safe
@nogc nothrow pure @safe unittest
{
    auto array = Array!int(3);
    void func(Array!int arg)
    {
        assert(arg.capacity == 3);
    }
    func(array);
}

// Can have non-copyable elements
@nogc nothrow pure @safe unittest
{
    static assert(is(Array!NonCopyable));
    static assert(is(typeof({ Array!NonCopyable.init[0] = NonCopyable(); })));
}
