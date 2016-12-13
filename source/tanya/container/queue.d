/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Copyright: Eugene Wissner 2016.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:belka@caraus.de, Eugene Wissner)
 */  
module tanya.container.queue;

import tanya.memory;

/**
 * Queue.
 *
 * Params:
 * 	T = Content type.
 */
struct Queue(T)
{
	/**
	 * Creates a new $(D_PSYMBOL Queue).
	 *
	 * Params:
	 * 	allocator = The allocator should be used for the element
	 * 	            allocations.
	 */
	this(shared Allocator allocator)
	{
		this.allocator = allocator;
	}

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
		auto q = defaultAllocator.make!(Queue!int);

		assert(q.empty);
		q.insertBack(8);
		q.insertBack(9);
		q.clear();
		assert(q.empty);

		defaultAllocator.dispose(q);
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
	void insertBack(T x)
	{
		if (allocator is null)
		{
			allocator = defaultAllocator;
		}
		Entry* temp = make!Entry(allocator);
		
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
	alias insert = insertBack;

	///
	unittest
	{
		auto q = make!(Queue!int)(defaultAllocator);

		assert(q.empty);
		q.insertBack(8);
		assert(q.front == 8);
		q.insertBack(9);
		assert(q.front == 8);

		dispose(defaultAllocator, q);
	}

	/**
	 * Returns: $(D_KEYWORD true) if the queue is empty.
	 */
	@property bool empty() inout const pure nothrow @safe
	{
		return first.next is null;
	}

	///
	unittest
	{
		auto q = make!(Queue!int)(defaultAllocator);
		int value = 7;

		assert(q.empty);
		q.insertBack(value);
		assert(!q.empty);

		dispose(defaultAllocator, q);
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
		auto q = make!(Queue!int)(defaultAllocator);

		q.insertBack(8);
		q.insertBack(9);
		assert(q.front == 8);
		q.popFront();
		assert(q.front == 9);

		dispose(defaultAllocator, q);
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
		auto q = Queue!int(defaultAllocator);

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

	/**
	 * Queue entry.
	 */
	protected struct Entry
	{
		/// Queue item content.
		T content;

		/// Next list item.
		Entry* next;
	}

	/// The first element of the list.
	protected Entry first;

	/// The last element of the list.
	protected Entry* rear;

	/// The allocator.
	protected shared Allocator allocator;
}

///
unittest
{
	auto q = Queue!int(defaultAllocator);

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
