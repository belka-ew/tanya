/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
module tanya.math.tests.random;

import tanya.math.random;
import tanya.memory.allocator;

static if (is(PlatformEntropySource)) @nogc @system unittest
{
    import tanya.memory.smartref : unique;

    auto source = defaultAllocator.unique!PlatformEntropySource();

    assert(source.threshold == 32);
    assert(source.strong);
}
