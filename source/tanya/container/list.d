/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Linked list.
 *
 * Copyright: Eugene Wissner 2016-2017.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 */
module tanya.container.list;

import std.algorithm.comparison;
import std.algorithm.mutation;
import std.algorithm.searching;
import std.range.primitives;
import std.traits;
import tanya.container.entry;
import tanya.memory;

private struct Range(E)
    if (__traits(isSame, TemplateOf!E, SEntry))
{
    private alias T = typeof(E.content);

    private E* head;

    private this(E* head)
    {
        this.head = head;
    }

    @property Range save()
    {
        return this;
    }

    @property size_t length() const
    {
        return count(opIndex());
    }

    @property bool empty() const
    {
        return head is null;
    }

    @property ref inout(T) front() inout
    in
    {
        assert(!empty);
    }
    body
    {
        return head.content;
    }

    void popFront()
    in
    {
        assert(!empty);
    }
    body
    {
        head = head.next;
    }

    Range opIndex()
    {
        return typeof(return)(head);
    }

    Range!(const E) opIndex() const
    {
        return typeof(return)(head);
    }
}

/**
 * Singly-linked list.
 *
 * Params:
 *  T = Content type.
 */
struct SList(T)
{
    private alias Entry = SEntry!T;

    // 0th element of the list.
    private Entry* head;

    /**
     * Removes all elements from the list.
     */
    ~this()
    {
        clear();
    }

    /**
     * Removes all contents from the list.
     */
    void clear()
    {
        while (!empty)
        {
            removeFront();
        }
    }

    ///
    unittest
    {
        SList!int l;

        l.insertFront(8);
        l.insertFront(5);
        l.clear();
        assert(l.empty);
    }

    /**
     * Returns: First element.
     */
    @property ref inout(T) front() inout
    in
    {
        assert(!empty);
    }
    body
    {
        return head.content;
    }

    /**
     * Inserts a new element at the beginning.
     *
     * Params:
     *  R = Type of the inserted value(s).
     *  x = New element.
     *
     * Returns: The number of elements inserted.
     */
    size_t insertFront(R)(ref R x) @trusted
        if (isImplicitlyConvertible!(R, T))
    {
        head = allocator.make!Entry(x, head);
        return 1;
    }

    /// Ditto.
    size_t insertFront(R)(R x) @trusted
        if (isImplicitlyConvertible!(R, T))
    {
        auto temp = cast(Entry*) allocator.allocate(Entry.sizeof);

        x.moveEmplace(temp.content);
        temp.next = head;

        head = temp;
        return 1;
    }

    /// Ditto.
    size_t insertFront(R)(R el)
        if (!isInfinite!R
         && isInputRange!R
         && isImplicitlyConvertible!(ElementType!R, T))
    {
        size_t retLength;
        foreach (e; el)
        {
            retLength += insertFront(e);
        }
        return retLength;
    }

    /// Ditto.
    size_t insertFront(size_t R)(T[R] el)
    {
        return insertFront!(T[])(el[]);
    }

    /// Ditto.
    alias insert = insertFront;

    ///
    @nogc @safe unittest
    {
        SList!int l1;

        assert(l1.insertFront(8) == 1);
        assert(l1.front == 8);
        assert(l1.insertFront(9) == 1);
        assert(l1.front == 9);

        SList!int l2;
        assert(l2.insertFront([25, 30, 15]) == 3);
        assert(l2.front == 15);

        l2.insertFront(l1[]);
        assert(l2.length == 5);
        assert(l2.front == 8);
    }

    /**
     * Returns: How many elements are in the list.
     */
    @property size_t length() const
    {
        return count(opIndex());
    }

    ///
    unittest
    {
        SList!int l;

        l.insertFront(8);
        l.insertFront(9);
        assert(l.length == 2);
        l.removeFront();
        assert(l.length == 1);
        l.removeFront();
        assert(l.length == 0);
    }

    /**
     * Comparison for equality.
     *
     * Params:
     *  that = The list to compare with.
     *
     * Returns: $(D_KEYWORD true) if the lists are equal, $(D_KEYWORD false)
     *          otherwise.
     */
    bool opEquals()(auto ref typeof(this) that) @trusted
    {
        return equal(opIndex(), that[]);
    }

    /// Ditto.
    bool opEquals()(in auto ref typeof(this) that) const @trusted
    {
        return equal(opIndex(), that[]);
    }

    ///
    unittest
    {
        SList!int l1, l2;

        l1.insertFront(8);
        l1.insertFront(9);
        l2.insertFront(8);
        l2.insertFront(10);
        assert(l1 != l2);

        l1.removeFront();
        assert(l1 != l2);

        l2.removeFront();
        assert(l1 == l2);

        l1.removeFront();
        assert(l1 != l2);

        l2.removeFront();
        assert(l1 == l2);
    }

    /**
     * Returns: $(D_KEYWORD true) if the list is empty.
     */
    @property bool empty() const
    {
        return head is null;
    }

    /**
     * Returns the first element and moves to the next one.
     *
     * Returns: The first element.
     *
     * Precondition: $(D_INLINECODE !empty)
     */
    void removeFront()
    in
    {
        assert(!empty);
    }
    body
    {
        auto n = head.next;

        allocator.dispose(head);
        head = n;
    }

    ///
    unittest
    {
        SList!int l;

        l.insertFront(8);
        l.insertFront(9);
        assert(l.front == 9);
        l.removeFront();
        assert(l.front == 8);
        l.removeFront();
        assert(l.empty);
    }

    /**
     * Removes $(D_PARAM howMany) elements from the list.
     *
     * Unlike $(D_PSYMBOL removeFront()), this method doesn't fail, if it could not
     * remove $(D_PARAM howMany) elements. Instead, if $(D_PARAM howMany) is
     * greater than the list length, all elements are removed.
     *
     * Params:
     *  howMany = How many elements should be removed.
     *
     * Returns: The number of elements removed.
     */
    size_t removeFront(in size_t howMany)
    out (removed)
    {
        assert(removed <= howMany);
    }
    body
    {
        size_t i;
        for (; i < howMany && !empty; ++i)
        {
            removeFront();
        }
        return i;
    }

    /// Ditto.
    alias remove = removeFront;

    ///
    unittest
    {
        SList!int l;

        l.insertFront(8);
        l.insertFront(5);
        l.insertFront(4);
        assert(l.removeFront(0) == 0);
        assert(l.removeFront(2) == 2);
        assert(l.removeFront(3) == 1);
        assert(l.removeFront(3) == 0);
    }

    /**
     * $(D_KEYWORD foreach) iteration.
     *
     * Params:
     *  dg = $(D_KEYWORD foreach) body.
     *
     * Returns: The value returned from $(D_PARAM dg).
     */
    int opApply(scope int delegate(ref size_t i, ref T) @nogc dg)
    {
        int result;
        size_t i;

        for (auto pos = head; pos; pos = pos.next, ++i)
        {
            result = dg(i, pos.content);

            if (result != 0)
            {
                return result;
            }
        }
        return result;
    }

    /// Ditto.
    int opApply(scope int delegate(ref T) @nogc dg)
    {
        int result;

        for (auto pos = head; pos; pos = pos.next)
        {
            result = dg(pos.content);

            if (result != 0)
            {
                return result;
            }
        }
        return result;
    }

    ///
    unittest
    {
        SList!int l;

        l.insertFront(5);
        l.insertFront(4);
        l.insertFront(9);
        foreach (i, e; l)
        {
            assert(i != 0 || e == 9);
            assert(i != 1 || e == 4);
            assert(i != 2 || e == 5);
        }
    }

    Range!Entry opIndex()
    {
        return typeof(return)(head);
    }

    Range!(const Entry) opIndex() const
    {
        return typeof(return)(head);
    }

    mixin DefaultAllocator;
}

///
unittest
{
    SList!int l;
    size_t i;

    l.insertFront(5);
    l.insertFront(4);
    l.insertFront(9);
    foreach (e; l)
    {
        assert(i != 0 || e == 9);
        assert(i != 1 || e == 4);
        assert(i != 2 || e == 5);
        ++i;
    }
    assert(i == 3);
}

unittest
{
    interface Stuff
    {
    }
    static assert(is(SList!Stuff));
}
