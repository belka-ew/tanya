/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Copyright: Eugene Wissner 2016.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 */
module tanya.memory;

public
{
    import tanya.memory.allocator;
    import std.experimental.allocator : make, dispose, shrinkArray, expandArray, makeArray, dispose;
}

shared Allocator allocator;

@property ref shared(Allocator) defaultAllocator()
{
    import tanya.memory.mallocator;
    if (allocator is null)
    {
        allocator = Mallocator.instance;
    }
    return allocator;
}
