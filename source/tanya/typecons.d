/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Type constructors.
 *
 * Copyright: Eugene Wissner 2017.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 */
module tanya.typecons;

import std.meta;

/**
 * $(D_PSYMBOL Pair) can store two heterogeneous objects. The objects can be
 * accessed than by the index. The objects can by accessed by index as
 * $(D_INLINECODE obj[0]) and $(D_INLINECODE obj[1]).
 */
template Pair(Field1, Field2)
{
    /// Field types.
    alias Types = AliasSeq!(Field1, Field2);

    struct Pair
    {
        /// Represents the values of the $(D_PSYMBOL Pair) as a list of values.
        Types expand;

        alias expand this;
    }
}

///
unittest
{
    static assert(is(Pair!(int, int)));
    static assert(!is(Pair!(int, 5)));
}
