/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

module tanya.algorithm.tests.iteration;

import tanya.algorithm.iteration;
import tanya.range;
import tanya.test.stub;

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
