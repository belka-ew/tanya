/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
module tanya.memory.tests.lifetime;

import tanya.memory.allocator;
import tanya.memory.lifetime;
import tanya.test.stub;

@nogc nothrow pure @safe unittest
{
    int[] p;

    p = defaultAllocator.resize(p, 20);
    assert(p.length == 20);

    p = defaultAllocator.resize(p, 30);
    assert(p.length == 30);

    p = defaultAllocator.resize(p, 10);
    assert(p.length == 10);

    p = defaultAllocator.resize(p, 0);
    assert(p is null);
}

@nogc nothrow pure @system unittest
{
    static struct S
    {
        ~this() @nogc nothrow pure @safe
        {
        }
    }
    auto p = cast(S[]) defaultAllocator.allocate(S.sizeof);

    defaultAllocator.dispose(p);
}

// Works with interfaces.
@nogc nothrow pure @safe unittest
{
    interface I
    {
    }
    class C : I
    {
    }
    auto c = defaultAllocator.make!C();
    I i = c;

    defaultAllocator.dispose(i);
    defaultAllocator.dispose(i);
}

// Handles "Cannot access frame pointer" error.
@nogc nothrow pure @safe unittest
{
    struct F
    {
        ~this() @nogc nothrow pure @safe
        {
        }
    }
    static assert(is(typeof(emplace!F((void[]).init))));
}

// Can emplace structs without a constructor
@nogc nothrow pure @safe unittest
{
    static assert(is(typeof(emplace!WithDtor(null, WithDtor()))));
    static assert(is(typeof(emplace!WithDtor(null))));
}

// Doesn't call a destructor on uninitialized elements
@nogc nothrow pure @system unittest
{
    static struct SWithDtor
    {
        private bool canBeInvoked = false;
        ~this() @nogc nothrow pure @safe
        {
            assert(this.canBeInvoked);
        }
    }
    void[SWithDtor.sizeof] memory = void;
    auto actual = emplace!SWithDtor(memory[], SWithDtor(true));
    assert(actual.canBeInvoked);
}

// Initializes structs if no arguments are given
@nogc nothrow pure @safe unittest
{
    static struct SEntry
    {
        byte content;
    }
    ubyte[1] mem = [3];

    assert(emplace!SEntry(cast(void[]) mem[0 .. 1]).content == 0);
}

// Postblit is called when emplacing a struct
@nogc nothrow pure @system unittest
{
    static struct S
    {
        bool called = false;
        this(this) @nogc nothrow pure @safe
        {
            this.called = true;
        }
    }
    S target;
    S* sp = &target;

    emplace!S(sp[0 .. 1], S());
    assert(target.called);
}

// Is pure.
@nogc nothrow pure @system unittest
{
    struct S
    {
        this(this)
        {
        }
    }
    S source, target = void;
    static assert(is(typeof({ moveEmplace(source, target); })));
}

// Moves nested.
@nogc nothrow pure @system unittest
{
    struct Nested
    {
        void method() @nogc nothrow pure @safe
        {
        }
    }
    Nested source, target = void;
    moveEmplace(source, target);
    assert(source == target);
}

// Emplaces static arrays.
@nogc nothrow pure @system unittest
{
    static struct S
    {
        size_t member;
        this(size_t i) @nogc nothrow pure @safe
        {
            this.member = i;
        }
        ~this() @nogc nothrow pure @safe
        {
        }
    }
    S[2] source = [ S(5), S(5) ], target = void;
    moveEmplace(source, target);
    assert(source[0].member == 0);
    assert(target[0].member == 5);
    assert(source[1].member == 0);
    assert(target[1].member == 5);
}

// Moves if source is target.
@nogc nothrow pure @safe unittest
{
    int x = 5;
    move(x, x);
    assert(x == 5);
}

