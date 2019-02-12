/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Range adapters transform some data structures into ranges.
 *
 * Copyright: Eugene Wissner 2018-2019.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/range/adapter.d,
 *                 tanya/range/adapter.d)
 */
module tanya.range.adapter;

import tanya.functional;
import tanya.meta.trait;
import tanya.range;

version (unittest)
{
    static struct Container
    {
        void insertBack(const(char)[])
        {
        }
    }
}

package (tanya) auto backInserter(Container)(return ref Container container)
if (hasMember!(Container, "insertBack"))
{
    static struct BackInserter
    {
        private Container* container;

        this(ref Container container) @trusted
        {
            this.container = &container;
        }

        void opCall(T)(auto ref T data)
        {
            this.container.insertBack(forward!data);
        }
    }
    return BackInserter(container);
}

@nogc nothrow pure @safe unittest
{
    auto func()()
    {
        Container container;
        return backInserter(container);
    }
    static assert(!is(typeof(func!())));
}

@nogc nothrow pure @safe unittest
{
    Container container;
    static assert(isOutputRange!(typeof(backInserter(container)), string));
}
