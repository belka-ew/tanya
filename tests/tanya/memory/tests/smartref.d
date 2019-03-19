/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
module tanya.memory.tests.smartref;

import tanya.memory;
import tanya.memory.smartref;
import tanya.meta.trait;
import tanya.test.stub;

@nogc @system unittest
{
    auto rc = defaultAllocator.refCounted!int(5);
    rc = defaultAllocator.make!int(7);
    assert(*rc == 7);
}

@nogc @system unittest
{
    RefCounted!int rc;
    assert(!rc.isInitialized);
    rc = null;
    assert(!rc.isInitialized);
}

@nogc @system unittest
{
    auto rc = defaultAllocator.refCounted!int(5);

    void func(RefCounted!int param) @nogc
    {
        assert(param.count == 2);
        param = defaultAllocator.make!int(7);
        assert(param.count == 1);
        assert(*param == 7);
    }
    func(rc);
    assert(rc.count == 1);
    assert(*rc == 5);
}

@nogc @system unittest
{
    RefCounted!int rc;

    void func(RefCounted!int param) @nogc
    {
        assert(param.count == 0);
        param = defaultAllocator.make!int(7);
        assert(param.count == 1);
        assert(*param == 7);
    }
    func(rc);
    assert(rc.count == 0);
}

@nogc @system unittest
{
    RefCounted!int rc1, rc2;
    static assert(is(typeof(rc1 = rc2)));
}

@nogc @system unittest
{
    auto rc = RefCounted!int(defaultAllocator);
    assert(!rc.isInitialized);
    assert(rc.allocator is defaultAllocator);
}

@nogc @system unittest
{
    auto rc = defaultAllocator.refCounted!int(5);
    assert(rc.count == 1);

    void func(RefCounted!int rc) @nogc
    {
        assert(rc.count == 2);
        rc = null;
        assert(!rc.isInitialized);
        assert(rc.count == 0);
    }

    assert(rc.count == 1);
    func(rc);
    assert(rc.count == 1);

    rc = null;
    assert(!rc.isInitialized);
    assert(rc.count == 0);
}

@nogc @system unittest
{
    auto rc = defaultAllocator.refCounted!int(5);
    assert(*rc == 5);

    void func(RefCounted!int rc) @nogc
    {
        assert(rc.count == 2);
        rc = defaultAllocator.refCounted!int(4);
        assert(*rc == 4);
        assert(rc.count == 1);
    }
    func(rc);
    assert(*rc == 5);
}

@nogc @system unittest
{
    auto rc = defaultAllocator.refCounted!(int[])(5);
    assert(rc.length == 5);
}

@nogc @system unittest
{
    auto p1 = defaultAllocator.make!int(5);
    auto p2 = p1;
    auto rc = RefCounted!int(p1, defaultAllocator);
    assert(rc.get() is p2);
}

@nogc @system unittest
{
    size_t destroyed;
    {
        auto rc = defaultAllocator.refCounted!WithDtor(destroyed);
    }
    assert(destroyed == 1);
}

@nogc nothrow pure @system unittest
{
    auto s = defaultAllocator.unique!int(5);
    assert(*s == 5);

    s = null;
    assert(s is null);
}

@nogc nothrow pure @system unittest
{
    auto s = defaultAllocator.unique!int(5);
    assert(*s == 5);

    s = defaultAllocator.unique!int(4);
    assert(*s == 4);
}

@nogc nothrow pure @system unittest
{
    auto p1 = defaultAllocator.make!int(5);
    auto p2 = p1;

    auto rc = Unique!int(p1, defaultAllocator);
    assert(rc.get() is p2);
}

@nogc nothrow pure @system unittest
{
    auto rc = Unique!int(defaultAllocator);
    assert(rc.allocator is defaultAllocator);
}

@nogc @system unittest
{
    uint destroyed;
    auto a = defaultAllocator.make!A(destroyed);

    assert(destroyed == 0);
    {
        auto rc = RefCounted!A(a, defaultAllocator);
        assert(rc.count == 1);

        void func(RefCounted!A rc) @nogc @system
        {
            assert(rc.count == 2);
        }
        func(rc);

        assert(rc.count == 1);
    }
    assert(destroyed == 1);

    RefCounted!int rc;
    assert(rc.count == 0);
    rc = defaultAllocator.make!int(8);
    assert(rc.count == 1);
}

@nogc nothrow pure @safe unittest
{
    static assert(is(ReturnType!(RefCounted!int.get) == inout int*));
    static assert(is(ReturnType!(RefCounted!A.get) == inout A));
    static assert(is(ReturnType!(RefCounted!B.get) == inout B*));
}

@nogc nothrow pure @safe unittest
{
    static assert(is(RefCounted!B));
    static assert(is(RefCounted!A));
}

@nogc @system unittest
{
    struct E
    {
    }
    auto b = defaultAllocator.refCounted!B(15);
    static assert(is(typeof(b.prop) == int));
    static assert(!is(typeof(defaultAllocator.refCounted!B())));

    static assert(is(typeof(defaultAllocator.refCounted!E())));
    static assert(!is(typeof(defaultAllocator.refCounted!E(5))));
    {
        auto rc = defaultAllocator.refCounted!B(3);
        assert(rc.get().prop == 3);
    }
    {
        auto rc = defaultAllocator.refCounted!E();
        assert(rc.count);
    }
}

@nogc nothrow pure @safe unittest
{
    static assert(is(typeof(defaultAllocator.unique!B(5))));
    static assert(is(typeof(defaultAllocator.unique!(int[])(5))));
}

private class A
{
    uint *destroyed;

    this(ref uint destroyed) @nogc
    {
        this.destroyed = &destroyed;
    }

    ~this() @nogc
    {
        ++(*destroyed);
    }
}

private struct B
{
    int prop;
    @disable this();
    this(int param1) @nogc
    {
        prop = param1;
    }
}
