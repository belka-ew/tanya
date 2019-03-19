/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
module tanya.net.tests.inet;

import tanya.net.inet;
import tanya.range;

// Static tests
@nogc nothrow pure @safe unittest
{
    static assert(isBidirectionalRange!(NetworkOrder!4));
    static assert(isBidirectionalRange!(NetworkOrder!8));
    static assert(!is(NetworkOrder!9));
    static assert(!is(NetworkOrder!1));
}
