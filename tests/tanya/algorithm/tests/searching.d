/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
module tanya.algorithm.tests.searching;

import tanya.algorithm.searching;
import tanya.test.stub;

@nogc nothrow pure @safe unittest
{
    @Count(3)
    static struct Range
    {
        mixin InputRangeStub!int;
    }
    assert(count(Range()) == 3);
}
