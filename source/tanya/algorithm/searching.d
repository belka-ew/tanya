/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Searching algorithms.
 *
 * Copyright: Eugene Wissner 2018-2020.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/algorithm/searching.d,
 *                 tanya/algorithm/searching.d)
 */
module tanya.algorithm.searching;

import tanya.range;

/**
 * Counts the elements in an input range.
 *
 * If $(D_PARAM R) has length, $(D_PSYMBOL count) returns it, otherwise it
 * iterates over the range and counts the elements.
 *
 * Params:
 *  R     = Input range type.
 *  range = Input range.
 *
 * Returns: $(D_PARAM range) length.
 */
size_t count(R)(R range)
if (isInputRange!R)
{
    static if (hasLength!R)
    {
        return range.length;
    }
    else
    {
        size_t counter;
        for (; !range.empty; range.popFront(), ++counter)
        {
        }
        return counter;
    }
}

///
@nogc nothrow pure @safe unittest
{
    int[3] array;
    assert(count(array) == 3);
}
