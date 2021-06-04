/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
module tanya.algorithm.tests.mutation;

import tanya.algorithm.mutation;
import tanya.range;
import tanya.test.stub;

// Returns advanced target
@nogc nothrow pure @safe unittest
{
    int[5] input = [1, 2, 3, 4, 5];
    assert(copy(input[3 .. 5], input[]).front == 3);
}

// Copies overlapping arrays
@nogc nothrow pure @safe unittest
{
    import std.algorithm.comparison : equal;

    int[6] actual = [1, 2, 3, 4, 5, 6];
    const int[6] expected = [1, 2, 1, 2, 3, 4];

    copy(actual[0 .. 4], actual[2 .. 6]);
    assert(equal(actual[], expected[]));
}

@nogc nothrow pure @safe unittest
{
    static assert(is(typeof(copy((ubyte[]).init, (ushort[]).init))));
    static assert(!is(typeof(copy((ushort[]).init, (ubyte[]).init))));
}

@nogc nothrow pure @safe unittest
{
    static struct OutPutRange
    {
        int value;

        void opCall(int value) @nogc nothrow pure @safe
        in
        {
            assert(this.value == 0);
        }
        do
        {
            this.value = value;
        }
    }
    int[1] source = [5];
    OutPutRange target;

    assert(copy(source[], target).value == 5);
}

// [] is called where possible
@nogc nothrow pure @system unittest
{
    static struct Slice
    {
        bool* slicingCalled;

        int front() @nogc nothrow pure @safe
        {
            return 0;
        }

        void front(int) @nogc nothrow pure @safe
        {
        }

        void popFront() @nogc nothrow pure @safe
        {
        }

        bool empty() @nogc nothrow pure @safe
        {
            return true;
        }

        void opIndexAssign(int) @nogc nothrow pure @safe
        {
            *this.slicingCalled = true;
        }
    }
    bool slicingCalled;
    auto range = Slice(&slicingCalled);
    fill(range, 0);
    assert(slicingCalled);
}

@nogc nothrow pure @safe unittest
{
    NonCopyable[] nonCopyable;
    initializeAll(nonCopyable);
}
