/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * FIFO queue.
 *
 * Copyright: Eugene Wissner 2016-2018.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/container/queue.d,
 *                 tanya/container/queue.d)
 */
deprecated("Use tanya.container.list.DList instead")
module tanya.container.queue;

import tanya.algorithm.mutation;
import tanya.container.entry;
import tanya.exception;
import tanya.memory;
import tanya.meta.trait;

/**
 * FIFO queue.
 *
 * Params:
 *  T = Content type.
 */
struct Queue(T)
{
    /**
     * Removes all elements from the queue.
     */
    ~this()
    {
        while (!empty)
        {
            dequeue();
        }
    }

    /**
     * Returns how many elements are in the queue. It iterates through the queue
     * to count the elements.
     *
     * Returns: How many elements are in the queue.
     */
    size_t length() const
    {
        size_t len;
        for (const(SEntry!T)* i = first; i !is null; i = i.next)
        {
            ++len;
        }
        return len;
    }

    ///
    unittest
    {
        Queue!int q;

        assert(q.length == 0);
        q.enqueue(5);
        assert(q.length == 1);
        q.enqueue(4);
        assert(q.length == 2);
        q.enqueue(9);
        assert(q.length == 3);

        q.dequeue();
        assert(q.length == 2);
        q.dequeue();
        assert(q.length == 1);
        q.dequeue();
        assert(q.length == 0);
    }

    private void enqueueEntry(ref SEntry!T* entry)
    {
        if (empty)
        {
            first = rear = entry;
        }
        else
        {
            rear.next = entry;
            rear = rear.next;
        }
    }

    private SEntry!T* allocateEntry()
    {
        auto temp = cast(SEntry!T*) allocator.allocate(SEntry!T.sizeof);
        if (temp is null)
        {
            onOutOfMemoryError();
        }
        return temp;
    }

    /**
     * Inserts a new element.
     *
     * Params:
     *  x = New element.
     */
    void enqueue(ref T x)
    {
        auto temp = allocateEntry();

        *temp = SEntry!T.init;
        temp.content = x;

        enqueueEntry(temp);
    }

    /// ditto
    void enqueue(T x)
    {
        auto temp = allocateEntry();

        moveEmplace(x, (*temp).content);
        (*temp).next = null;

        enqueueEntry(temp);
    }

    ///
    unittest
    {
        Queue!int q;

        assert(q.empty);
        q.enqueue(8);
        q.enqueue(9);
        assert(q.dequeue() == 8);
        assert(q.dequeue() == 9);
    }

    /**
     * Returns: $(D_KEYWORD true) if the queue is empty.
     */
    @property bool empty() const
    {
        return first is null;
    }

    ///
    unittest
    {
        Queue!int q;
        int value = 7;

        assert(q.empty);
        q.enqueue(value);
        assert(!q.empty);
    }

    /**
     * Move the position to the next element.
     *
     * Returns: Dequeued element.
     */
    T dequeue()
    in
    {
        assert(!empty);
    }
    do
    {
        auto n = first.next;
        T ret = move(first.content);

        allocator.dispose(first);
        first = n;
        return ret;
    }

    ///
    unittest
    {
        Queue!int q;

        q.enqueue(8);
        q.enqueue(9);
        assert(q.dequeue() == 8);
        assert(q.dequeue() == 9);
    }

    /**
     * $(D_KEYWORD foreach) iteration. The elements will be automatically
     * dequeued.
     *
     * Params:
     *  dg = $(D_KEYWORD foreach) body.
     *
     * Returns: The value returned from $(D_PARAM dg).
     */
    int opApply(scope int delegate(ref size_t i, ref T) @nogc dg)
    {
        int result;

        for (size_t i; !empty; ++i)
        {
            auto e = dequeue();
            if ((result = dg(i, e)) != 0)
            {
                return result;
            }
        }
        return result;
    }

    /// ditto
    int opApply(scope int delegate(ref T) @nogc dg)
    {
        int result;

        while (!empty)
        {
            auto e = dequeue();
            if ((result = dg(e)) != 0)
            {
                return result;
            }
        }
        return result;
    }

    ///
    unittest
    {
        Queue!int q;

        size_t j;
        q.enqueue(5);
        q.enqueue(4);
        q.enqueue(9);
        foreach (i, e; q)
        {
            assert(i != 2 || e == 9);
            assert(i != 1 || e == 4);
            assert(i != 0 || e == 5);
            ++j;
        }
        assert(j == 3);
        assert(q.empty);

        j = 0;
        q.enqueue(5);
        q.enqueue(4);
        q.enqueue(9);
        foreach (e; q)
        {
            assert(j != 2 || e == 9);
            assert(j != 1 || e == 4);
            assert(j != 0 || e == 5);
            ++j;
        }
        assert(j == 3);
        assert(q.empty);
    }

    private SEntry!T* first;
    private SEntry!T* rear;

    mixin DefaultAllocator;
}

///
unittest
{
    Queue!int q;

    q.enqueue(5);
    assert(!q.empty);

    q.enqueue(4);
    q.enqueue(9);

    assert(q.dequeue() == 5);

    foreach (i, ref e; q)
    {
        assert(i != 0 || e == 4);
        assert(i != 1 || e == 9);
    }
    assert(q.empty);
}
