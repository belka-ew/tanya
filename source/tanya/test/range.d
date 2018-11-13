/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Range generators for tests.

 * Copyright: Eugene Wissner 2018.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/test/range.d,
 *                 tanya/test/range.d)
 */
module tanya.test.range;

package(tanya) struct Empty
{
}

package(tanya) template InputRange()
{
    import tanya.meta.metafunction : AliasSeq;

    private alias attributes = AliasSeq!(__traits(getAttributes, typeof(this)));

    static foreach (attribute; attributes)
    {
        static if (is(attribute == Empty))
        {
            @property bool empty() const @nogc nothrow pure @safe
            {
                return true;
            }
        }
    }

    void popFront() @nogc nothrow pure @safe
    {
        static foreach (attribute; attributes)
        {
            static if (is(attribute == Empty))
            {
                assert(false);
            }
        }
    }

    int front() @nogc nothrow pure @safe
    {
        static foreach (attribute; attributes)
        {
            static if (is(attribute == Empty))
            {
                assert(false);
            }
        }
    }
}
