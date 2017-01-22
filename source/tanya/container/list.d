/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Copyright: Eugene Wissner 2016-2017.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 */  
module tanya.container.list;

import tanya.container.entry;
import tanya.memory;

/**
 * Singly-linked list.
 *
 * Params:
 * 	T = Content type.
 */
struct SList(T)
{
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
			popFront();
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
		return first.next.content;
	}

	/**
	 * Inserts a new element at the beginning.
	 *
	 * Params:
	 * 	x = New element.
	 */
	void insertFront(ref T x)
	{
		auto temp = allocator.make!(SEntry!T);
		
		temp.content = x;
		temp.next = first.next;
		first.next = temp;
	}

	/// Ditto.
	void insertFront(T x)
	{
		insertFront(x);
	}

	/// Ditto.
	alias insert = insertFront;

	///
	unittest
	{
		SList!int l;

		l.insertFront(8);
		assert(l.front == 8);
		l.insertFront(9);
		assert(l.front == 9);
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
	void popFront()
	in
	{
		assert(!empty);
	}
	body
	{
		auto n = first.next.next;

		allocator.dispose(first.next);
		first.next = n;
	}

	///
	unittest
	{
		SList!int l;

		l.insertFront(8);
		l.insertFront(9);
		assert(l.front == 9);
		l.popFront();
		assert(l.front == 8);
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

	/// 0th element of the list.
	private SEntry!T first;

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

private unittest
{
	interface Stuff
	{
	}
	static assert(is(SList!Stuff));
}
