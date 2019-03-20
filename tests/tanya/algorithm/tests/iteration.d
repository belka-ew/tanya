/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
module tanya.algorithm.tests.iteration;

import tanya.algorithm.iteration;
import tanya.range;
import tanya.test.stub;

// length is unknown when taking from a range without length
@nogc nothrow pure @safe unittest
{
    static struct R
    {
        mixin InputRangeStub;
    }
    auto actual = take(R(), 100);

    static assert(!hasLength!(typeof(actual)));
}

// Takes minimum length if the range length > n
@nogc nothrow pure @safe unittest
{
    auto range = take(cast(int[]) null, 8);
    assert(range.length == 0);
}

@nogc nothrow pure @safe unittest
{
    const int[9] range = [1, 2, 3, 4, 5, 6, 7, 8, 9];
    {
        auto slice = take(range[], 8)[1 .. 3];

        assert(slice.length == 2);
        assert(slice.front == 2);
        assert(slice.back == 3);
    }
    {
        auto slice = takeExactly(range[], 8)[1 .. 3];

        assert(slice.length == 2);
        assert(slice.front == 2);
        assert(slice.back == 3);
    }
}

// Elements are accessible in reverse order
@nogc nothrow pure @safe unittest
{
    const int[3] given = [1, 2, 3];
    auto actual = retro(given[]);

    assert(actual.back == given[].front);
    assert(actual[0] == 3);
    assert(actual[2] == 1);

    actual.popBack();
    assert(actual.back == 2);
    assert(actual[1] == 2);

    // Check slicing.
    auto slice = retro(given[])[1 .. $];
    assert(slice.length == 2 && slice.front == 2 && slice.back == 1);
}

// Elements can be assigned
@nogc nothrow pure @safe unittest
{
    int[4] given = [1, 2, 3, 4];
    auto actual = retro(given[]);

    actual.front = 5;
    assert(given[].back == 5);

    actual.back = 8;
    assert(given[].front == 8);

    actual[2] = 10;
    assert(given[1] == 10);
}

// Singleton range is bidirectional and random-access
@nogc nothrow pure @safe unittest
{
    static assert(isBidirectionalRange!(typeof(singleton('a'))));
    static assert(isRandomAccessRange!(typeof(singleton('a'))));

    assert({ char a; return isBidirectionalRange!(typeof(singleton(a))); });
    assert({ char a; return isRandomAccessRange!(typeof(singleton(a))); });
}

@nogc nothrow pure @safe unittest
{
    char a = 'a';
    auto single = singleton(a);

    assert(single.front == 'a');
    assert(single.back == 'a');
    assert(single[0] == 'a');
    assert(single.length == 1);
    assert(!single.empty);
}

// popFront makes SingletonByRef empty
@nogc nothrow pure @safe unittest
{
    char a = 'a';
    auto single = singleton(a);

    single.popFront();
    assert(single.empty);
    assert(single.length == 0);
    assert(single.empty);
}

// popBack makes SingletonByRef empty
@nogc nothrow pure @safe unittest
{
    char a = 'b';
    auto single = singleton(a);

    single.popBack();
    assert(single.empty);
    assert(single.length == 0);
    assert(single.empty);
}
