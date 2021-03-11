/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
module tanya.net.tests.iface;

import std.algorithm.comparison;
import tanya.net.iface;

@nogc nothrow @safe unittest
{
    version (linux)
    {
        assert(equal(indexToName(1)[], "lo"));
    }
    else version (Windows)
    {
        assert(equal(indexToName(1)[], "loopback_0"));
    }
    else
    {
        assert(equal(indexToName(1)[], "lo0"));
    }
    assert(indexToName(uint.max).empty);
}
