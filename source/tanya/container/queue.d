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

import tanya.container.entry;
import std.traits;
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
		clear();
	}

	/**
	 * Removes all elements from the queue.
	 */
	void clear()
	{
		while (!empty)
		{
			popFront();
		}
	}

	///
	unittest
	{
		Queue!int q;

		assert(q.empty);
		q.insertBack(8);
		q.insertBack(9);
		q.clear();
		assert(q.empty);
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
		q.insertBack(5);
		assert(q.length == 1);
		q.insertBack(4);
		assert(q.length == 2);
		q.insertBack(9);
		assert(q.length == 3);

		q.popFront();
		assert(q.length == 2);
		q.popFront();
		assert(q.length == 1);
		q.popFront();
		assert(q.length == 0);
	}

	version (D_Ddoc)
	{
		/**
		 * Compares two queues. Checks if all elements of the both queues are equal.
		 *
		 * Returns: Whether $(D_KEYWORD this) and $(D_PARAM that) are equal.
		 */
		int opEquals(ref typeof(this) that);

		/// Ditto.
		int opEquals(typeof(this) that);
	}
	else static if (!hasMember!(T, "opEquals")
	             || (functionAttributes!(T.opEquals) & FunctionAttribute.const_))
	{
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

		/// Ditto.
		bool opEquals(in typeof(this) that) const
		{
			return opEquals(that);
		}
	}
	else
	{
		/**
		 * Compares two queues. Checks if all elements of the both queues are equal.
		 *
		 * Returns: How many elements are in the queue.
		 */
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

		/// Ditto.
		bool opEquals(typeof(this) that)
		{
			return opEquals(that);
		}
	}

	///
	unittest
	{
		Queue!int q1, q2;

		q1.insertBack(5);
		q1.insertBack(4);
		q2.insertBack(5);
		assert(q1 != q2);
		q2.insertBack(4);
		assert(q1 == q2);

		q2.popFront();
		assert(q1 != q2);

		q1.popFront();
		assert(q1 == q2);

		q1.popFront();
		q2.popFront();
		assert(q1 == q2);
	}

	private unittest
	{
		static assert(is(Queue!ConstEqualsStruct));
		static assert(is(Queue!MutableEqualsStruct));
		static assert(is(Queue!NoEqualsStruct));
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
		return first.next.content;
	}

	/**
	 * Inserts a new element.
	 *
	 * Params:
	 * 	x = New element.
	 */
	void insertBack(ref T x)
	{
		auto temp = allocator.make!(Entry!T);
		
		temp.content = x;

		if (empty)
		{
			first.next = rear = temp;
		}
		else
		{
			rear.next = temp;
			rear = rear.next;
		}
	}

	/// Ditto.
	void insertBack(T x)
	{
		insertBack(x);
	}

	/// Ditto.
	alias insert = insertBack;

	///
	unittest
	{
		Queue!int q;

		assert(q.empty);
		q.insertBack(8);
		assert(q.front == 8);
		q.insertBack(9);
		assert(q.front == 8);
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
		q.insertBack(value);
		assert(!q.empty);
	}

	/**
	 * Move the position to the next element.
	 */
	void popFront()
	in
	{
		assert(!empty);
		assert(allocator !is null);
	}
	body
	{
		auto n = first.next.next;

		dispose(allocator, first.next);
		first.next = n;
	}

	///
	unittest
	{
		Queue!int q;

		q.insertBack(8);
		q.insertBack(9);
		assert(q.front == 8);
		q.popFront();
		assert(q.front == 9);
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
			if ((result = dg(i, front)) != 0)
			{
				return result;
			}
			popFront();
		}
		return result;
	}

	/// Ditto.
	int opApply(scope int delegate(ref T) @nogc dg)
	{
		int result;

		while (!empty)
		{
			if ((result = dg(front)) != 0)
			{
				return result;
			}
			popFront();
		}
		return result;
	}

	///
	unittest
	{
		Queue!int q;

		size_t j;
		q.insertBack(5);
		q.insertBack(4);
		q.insertBack(9);
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
		q.insertBack(5);
		q.insertBack(4);
		q.insertBack(9);
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

	q.insertBack(5);
	assert(!q.empty);

	q.insertBack(4);
	assert(q.front == 5);

	q.insertBack(9);
	assert(q.front == 5);

	q.popFront();
	assert(q.front == 4);

	foreach (i, ref e; q)
	{
		assert(i != 0 || e == 4);
		assert(i != 1 || e == 9);
	}
	assert(q.empty);
}
