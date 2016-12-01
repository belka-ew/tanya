/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Copyright: Eugene Wissner 2016.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 */  
module tanya.container.list;

import tanya.memory;

/**
 * Singly linked list.
 *
 * Params:
 * 	T = Content type.
 */
class SList(T)
{
	/**
	 * Creates a new $(D_PSYMBOL SList).
	 *
	 * Params:
	 * 	allocator = The allocator should be used for the element
	 * 	            allocations.
	 */
	this(IAllocator allocator = theAllocator)
	{
		this.allocator = allocator;
	}

	/**
	 * Removes all elements from the list.
	 */
	~this()
	{
		clear();
	}

	/**
	 * Remove all contents from the $(D_PSYMBOL SList).
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
		auto l = make!(SList!int)(theAllocator);
		int[2] values = [8, 5];

		l.front = values[0];
		l.front = values[1];
		l.clear();
		assert(l.empty);

		dispose(theAllocator, l);
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
	 * Inserts a new element at the beginning.
	 *
	 * Params:
	 * 	x = New element.
	 */
	@property void front(T x)
	{
		Entry* temp = make!Entry(allocator);
		
		temp.content = x;
		temp.next = first.next;
		first.next = temp;
	}

	///
	unittest
	{
		auto l = make!(SList!int)(theAllocator);
		int[2] values = [8, 9];

		l.front = values[0];
		assert(l.front == values[0]);
		l.front = values[1];
		assert(l.front == values[1]);

		dispose(theAllocator, l);
	}

	/**
	 * Inserts a new element at the beginning.
	 *
	 * Params:
	 * 	x = New element.
	 *
	 * Returns: $(D_KEYWORD this).
	 */
	typeof(this) opOpAssign(string Op)(ref T x)
		if (Op == "~")
	{
		front = x;
		return this;
	}

	///
	unittest
	{
		auto l = make!(SList!int)(theAllocator);
		int value = 5;

		assert(l.empty);

		l ~= value;

		assert(l.front == value);
		assert(!l.empty);

		dispose(theAllocator, l);
	}

	/**
	 * Returns: $(D_KEYWORD true) if the list is empty.
	 */
	@property bool empty() const
	{
		return first.next is null;
	}

	/**
	 * Returns the first element and moves to the next one.
	 *
	 * Returns: The first element.
	 */
	T popFront()
	in
	{
		assert(!empty);
	}
	body
	{
		auto n = first.next.next;
		auto content = first.next.content;

		dispose(allocator, first.next);
		first.next = n;

        return content;
	}

	///
	unittest
	{
		auto l = make!(SList!int)(theAllocator);
		int[2] values = [8, 9];

		l.front = values[0];
		l.front = values[1];
		assert(l.front == values[1]);
		l.popFront();
		assert(l.front == values[0]);

		dispose(theAllocator, l);
	}

	/**
	 * Removes $(D_PARAM howMany) elements from the list.
	 *
	 * Unlike $(D_PSYMBOL popFront()), this method doesn't fail, if it could not
	 * remove $(D_PARAM howMany) elements. Instead, if $(D_PARAM howMany) is
	 * greater than the list length, all elements are removed.
	 *
	 * Params:
	 * 	howMany = How many elements should be removed.
	 *
	 * Returns: The number of elements removed.
	 */
	size_t removeFront(in size_t howMany = 1)
	{
		size_t i;
		for (; i < howMany && !empty; ++i)
		{
			popFront();
		}
		return i;
	}

	/// Ditto.
	alias remove = removeFront;

	///
	unittest
	{
		auto l = make!(SList!int)(theAllocator);
		int[3] values = [8, 5, 4];

		l.front = values[0];
		l.front = values[1];
		l.front = values[2];
		assert(l.removeFront(0) == 0);
		assert(l.removeFront(2) == 2);
		assert(l.removeFront(3) == 1);
		assert(l.removeFront(3) == 0);

		dispose(theAllocator, l);
	}

	/**
	 * $(D_KEYWORD foreach) iteration.
	 *
	 * Params:
	 * 	dg = $(D_KEYWORD foreach) body.
	 */
	int opApply(scope int delegate(ref size_t i, ref T) dg)
	{
		int result;
		size_t i;

		for (auto pos = first.next; pos; pos = pos.next, ++i)
		{
			result = dg(i, pos.content);

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
		auto l = make!(SList!int)(theAllocator);
		int[3] values = [5, 4, 9];

		l.front = values[0];
		l.front = values[1];
		l.front = values[2];
		foreach (i, e; l)
		{
			assert(i != 0 || e == values[2]);
			assert(i != 1 || e == values[1]);
			assert(i != 2 || e == values[0]);
		}

		dispose(theAllocator, l);
	}

	/// Ditto.
	int opApply(scope int delegate(ref T) dg)
	{
		int result;

		for (auto pos = first.next; pos; pos = pos.next)
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
		auto l = make!(SList!int)(theAllocator);
		int[3] values = [5, 4, 9];
		size_t i;

		l.front = values[0];
		l.front = values[1];
		l.front = values[2];
		foreach (e; l)
		{
			assert(i != 0 || e == values[2]);
			assert(i != 1 || e == values[1]);
			assert(i != 2 || e == values[0]);
			++i;
		}

		dispose(theAllocator, l);
	}

	/**
	 * List entry.
	 */
	protected struct Entry
	{
		/// List item content.
		T content;

		/// Next list item.
		Entry* next;
	}

	/// 0th element of the list.
	protected Entry first;

	/// Allocator.
	protected IAllocator allocator;
}

///
unittest
{
	interface Stuff
	{
	}

	auto l = make!(SList!Stuff)(theAllocator);

	dispose(theAllocator, l);
}
