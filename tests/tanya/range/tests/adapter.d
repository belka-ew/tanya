/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
module tanya.range.tests.adapter;

import tanya.range;

private struct Container
{
    void insertBack(const(char)[])
    {
    }
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
