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

import tanya.memory;

/**
 * Queue.
 *
 * Params:
 * 	T = Content type.
 */
class Queue(T)
{
@nogc:
	/**
	 * Creates a new $(D_PSYMBOL Queue).
	 *
	 * Params:
	 * 	allocator = The allocator should be used for the element
	 * 	            allocations.
	 */
	this(Allocator allocator = defaultAllocator)
	{
		this.allocator = allocator;
	}

	/**
	 * Removes all elements from the queue.
	 */
	~this()
	{
		foreach (e; this)
		{
            static if (isFinalizable!T)
            {
                finalize(allocator, e);
            }
		}
	}

	/**
	 * Returns: First element.
	 */
	@property ref T front()
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
	typeof(this) insertBack(T x)
	{
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

		return this;
	}

	alias insert = insertBack;

	///
	unittest
	{
		auto q = make!(Queue!int)(defaultAllocator);
		int[2] values = [8, 9];

		q.insertBack(values[0]);
		assert(q.front is values[0]);
		q.insertBack(values[1]);
		assert(q.front is values[0]);

		finalize(defaultAllocator, q);
	}

	/**
	 * Inserts a new element.
	 *
	 * Params:
	 * 	x = New element.
	 *
	 * Returns: $(D_KEYWORD this).
	 */
	typeof(this) opOpAssign(string Op)(ref T x)
		if (Op == "~")
	{
		return insertBack(x);
	}

	///
	unittest
	{
		auto q = make!(Queue!int)(defaultAllocator);
		int value = 5;

		assert(q.empty);

		q ~= value;

		assert(q.front == value);
		assert(!q.empty);

		finalize(defaultAllocator, q);
	}

	/**
	 * Returns: $(D_KEYWORD true) if the queue is empty.
	 */
	@property bool empty() const @safe pure nothrow
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

		finalize(defaultAllocator, q);
	}

	/**
	 * Move position to the next element.
	 *
	 * Returns: $(D_KEYWORD this).
	 */
	typeof(this) popFront()
	in
	{
		assert(!empty);
	}
	body
	{
		auto n = first.next.next;

		finalize(allocator, first.next);
		first.next = n;

        return this;
	}

	///
	unittest
	{
		auto q = make!(Queue!int)(defaultAllocator);
		int[2] values = [8, 9];

		q.insertBack(values[0]);
		q.insertBack(values[1]);
		assert(q.front is values[0]);
		q.popFront();
		assert(q.front is values[1]);

		finalize(defaultAllocator, q);
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

	private Allocator allocator;
}

///
unittest
{
	auto q = make!(Queue!int)(defaultAllocator);

	finalize(defaultAllocator, q);
}
