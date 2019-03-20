/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
module tanya.container.tests.entry;

import tanya.container.entry;
import tanya.test.stub;

// Can be constructed with non-copyable key/values
@nogc nothrow pure @safe unittest
{
    static assert(is(Bucket!NonCopyable));
    static assert(is(Bucket!(NonCopyable, NonCopyable)));

    static assert(is(HashArray!((ref NonCopyable) => 0U, NonCopyable)));
    static assert(is(HashArray!((ref NonCopyable) => 0U, NonCopyable, NonCopyable)));
}
