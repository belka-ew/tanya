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

import tanya.algorithm.mutation;
import tanya.memory.lifetime;
import tanya.meta.trait;
import tanya.range;

private mixin template InserterCtor()
{
    private Container* container;

    private this(ref Container container) @trusted
    {
        this.container = &container;
    }
}

/**
 * If $(D_PARAM container) is a container with `insertBack`-support,
 * $(D_PSYMBOL backInserter) returns an output range that puts the elements
 * into the container with `insertBack`.
 *
 * The resulting output range supports all types `insertBack` supports.
 *
 * The range keeps a reference to the container passed to it, it doesn't use
 * any other storage. So there is no method to get the written data out of the
 * range - the container passed to $(D_PSYMBOL backInserter) contains that data
 * and can be used directly after all operations on the output range are
 * completed. It also means that the result range is not allowed to outlive its
 * container.
 *
 * Params:
 *  Container = Container type.
 *  container = Container used as an output range.
 *
 * Returns: `insertBack`-based output range.
 */
auto backInserter(Container)(return scope ref Container container)
if (hasMember!(Container, "insertBack"))
{
    static struct Inserter
    {
        void opCall(T)(auto ref T data)
        {
            this.container.insertBack(forward!data);
        }

        mixin InserterCtor;
    }
    return Inserter(container);
}

///
@nogc nothrow pure @safe unittest
{
    static struct Container
    {
        int element;

        void insertBack(int element)
        {
            this.element = element;
        }
    }
    Container container;
    backInserter(container)(5);

    assert(container.element == 5);
}

/**
 * If $(D_PARAM container) is a container with `insertFront`-support,
 * $(D_PSYMBOL frontInserter) returns an output range that puts the elements
 * into the container with `insertFront`.
 *
 * The resulting output range supports all types `insertFront` supports.
 *
 * The range keeps a reference to the container passed to it, it doesn't use
 * any other storage. So there is no method to get the written data out of the
 * range - the container passed to $(D_PSYMBOL frontInserter) contains that data
 * and can be used directly after all operations on the output range are
 * completed. It also means that the result range is not allowed to outlive its
 * container.
 *
 * Params:
 *  Container = Container type.
 *  container = Container used as an output range.
 *
 * Returns: `insertFront`-based output range.
 */
auto frontInserter(Container)(return scope ref Container container)
if (hasMember!(Container, "insertFront"))
{
    static struct Inserter
    {
        void opCall(T)(auto ref T data)
        {
            this.container.insertFront(forward!data);
        }

        mixin InserterCtor;
    }
    return Inserter(container);
}

///
@nogc nothrow pure @safe unittest
{
    static struct Container
    {
        int element;

        void insertFront(int element)
        {
            this.element = element;
        }
    }
    Container container;
    frontInserter(container)(5);

    assert(container.element == 5);
}

/**
 * $(D_PSYMBOL arrayInserter) makes an output range out of an array.
 *
 * The returned output range accepts single values as well as input ranges that
 * can be copied into the target array.
 *
 * Params:
 *  Array = Array type.
 *  array = Array.
 *
 * Returns: An output range writing into $(D_PARAM array).
 */
auto arrayInserter(Array)(return scope ref Array array)
if (isArray!Array)
{
    static if (is(Array ArrayT : ArrayT[size], size_t size))
    {
        alias E = ArrayT;
    }
    else
    {
        alias E = ElementType!Array;
    }

    static struct ArrayInserter
    {
        private E[] data;

        private this(ref Array data) @trusted
        {
            this.data = data[];
        }

        void opCall(T)(auto ref T data)
        if (is(T : E))
        in (!this.data.empty)
        {
            put(this.data, data);
        }

        void opCall(R)(auto ref R data)
        if (isInputRange!R && isOutputRange!(E[], ElementType!R))
        {
            this.data = copy(data, this.data);
        }
    }
    return ArrayInserter(array);
}

///
@nogc nothrow pure @safe unittest
{
    int[1] array;

    arrayInserter(array)(5);
    assert(array[0] == 5);
}

///
@nogc nothrow pure @safe unittest
{
    char[1] array;
    alias Actual = typeof(arrayInserter(array));

    static assert(isOutputRange!(Actual, char));
    static assert(isOutputRange!(Actual, char[]));
}
