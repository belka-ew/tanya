/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Copyright: Eugene Wissner 2016.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 */  
module tanya.container.queue;

import std.traits;
import std.algorithm.mutation;
import tanya.container.entry;
import tanya.memory;

/**
 * FIFO queue.
 *
 * Params:
 * 	T = Content type.
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
	 * Removes all elements from the queue.
	 */
	deprecated
	void clear()
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
		for (const(Entry!T)* i = first.next; i !is null; i = i.next)
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

	version (D_Ddoc)
	{
		/**
		 * Compares two queues. Checks if all elements of the both queues are equal.
		 *
		 * Returns: Whether $(D_KEYWORD this) and $(D_PARAM that) are equal.
		 */
		deprecated
		int opEquals(ref typeof(this) that);

		/// Ditto.
		deprecated
		int opEquals(typeof(this) that);
	}
	else static if (!hasMember!(T, "opEquals")
	             || (functionAttributes!(T.opEquals) & FunctionAttribute.const_))
	{
		deprecated
		bool opEquals(in ref typeof(this) that) const
		{
			const(Entry!T)* i = first.next;
			const(Entry!T)* j = that.first.next;
			while (i !is null && j !is null)
			{
				if (i.content != j.content)
				{
					return false;
				}
				i = i.next;
				j = j.next;
			}
			return i is null && j is null;
		}

		deprecated
		bool opEquals(in typeof(this) that) const
		{
			return opEquals(that);
		}
	}
	else
	{
		deprecated
		bool opEquals(ref typeof(this) that)
		{
			Entry!T* i = first.next;
			Entry!T* j = that.first.next;
			while (i !is null && j !is null)
			{
				if (i.content != j.content)
				{
					return false;
				}
				i = i.next;
				j = j.next;
			}
			return i is null && j is null;
		}

		deprecated
		bool opEquals(typeof(this) that)
		{
			return opEquals(that);
		}
	}

	/**
	 * Returns: First element.
	 */
	deprecated("Use dequeue instead.")
	@property ref inout(T) front() inout
	in
	{
		assert(!empty);
	}
	body
	{
		return first.next.content;
	}

	/**
	 * Inserts a new element.
	 *
	 * Params:
	 * 	x = New element.
	 *
	 * Returns: $(D_KEYWORD this).
	 */
	ref typeof(this) enqueue(ref T x)
	{
		auto temp = allocator.make!(Entry!T)(x);
		if (empty)
		{
			first.next = rear = temp;
		}
		else
		{
			rear.next = temp;
			rear = rear.next;
		}
		return this;
	}

	/// Ditto.
	ref typeof(this) enqueue(T x)
	{
		return enqueue(x);
	}

	deprecated("Use enqueue instead.")
	alias insert = enqueue;

	deprecated("Use enqueue instead.")
	alias insertBack = enqueue;

	///
	unittest
	{
		Queue!int q;

		assert(q.empty);
		q.enqueue(8).enqueue(9);
		assert(q.dequeue() == 8);
		assert(q.dequeue() == 9);
	}

	/**
	 * Returns: $(D_KEYWORD true) if the queue is empty.
	 */
	@property bool empty() const
	{
		return first.next is null;
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
		assert(allocator !is null);
	}
	body
	{
		auto n = first.next.next;
		T ret = move(first.next.content);

		dispose(allocator, first.next);
		first.next = n;
		return ret;
	}

	deprecated("Use dequeue instead.")
	alias popFront = dequeue;

	///
	unittest
	{
		Queue!int q;

		q.enqueue(8).enqueue(9);
		assert(q.dequeue() == 8);
		assert(q.dequeue() == 9);
	}

	/**
	 * $(D_KEYWORD foreach) iteration. The elements will be automatically
	 * dequeued.
	 *
	 * Params:
	 * 	dg = $(D_KEYWORD foreach) body.
	 */
	int opApply(scope int delegate(ref size_t i, ref T) @nogc dg)
	{
		int result;

		for (size_t i = 0; !empty; ++i)
		{
			auto e = dequeue();
			if ((result = dg(i, e)) != 0)
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
		q.enqueue(5).enqueue(4).enqueue(9);
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
		q.enqueue(5).enqueue(4).enqueue(9);
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

	/// The first element of the list.
	private Entry!T first;

	/// The last element of the list.
	private Entry!T* rear;

	mixin DefaultAllocator;
}

///
unittest
{
	Queue!int q;

	q.enqueue(5);
	assert(!q.empty);

	q.enqueue(4).enqueue(9);

	assert(q.dequeue() == 5);

	foreach (i, ref e; q)
	{
		assert(i != 0 || e == 4);
		assert(i != 1 || e == 9);
	}
	assert(q.empty);
}
