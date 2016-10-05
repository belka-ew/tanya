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
	this(shared Allocator allocator = defaultAllocator)
	{
		this.allocator = allocator;
        reset();
	}

	/**
	 * Removes all elements from the list.
	 */
	~this()
	{
		while (!empty)
		{
            static if (isFinalizable!T)
            {
                dispose(allocator, front);
            }
			popFront();
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
		auto l = make!(SList!int)(defaultAllocator);
		int[2] values = [8, 9];

		l.front = values[0];
		assert(l.front == values[0]);
		l.front = values[1];
		assert(l.front == values[1]);

		dispose(defaultAllocator, l);
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
		auto l = make!(SList!int)(defaultAllocator);
		int value = 5;

		assert(l.empty);

		l ~= value;

		assert(l.front == value);
		assert(!l.empty);

		dispose(defaultAllocator, l);
	}

	/**
	 * Returns: $(D_KEYWORD true) if the list is empty.
	 */
	@property bool empty() const @safe pure nothrow
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
		auto l = make!(SList!int)(defaultAllocator);
		int[2] values = [8, 9];

		l.front = values[0];
		l.front = values[1];
		assert(l.front == values[1]);
		l.popFront();
		assert(l.front == values[0]);

		dispose(defaultAllocator, l);
	}

	/**
	 * Returns the current item from the list and removes from the list.
	 *
	 * Params:
	 * 	x = The item should be removed.
	 *
	 * Returns: Removed item.
	 */
	T remove()
	in
	{
		assert(!empty);
	}
	body
	{
		auto temp = position.next.next;
		auto content = position.next.content;

		dispose(allocator, position.next);
		position.next = temp;

		return content;
	}

	///
	unittest
	{
		auto l = make!(SList!int)(defaultAllocator);
		int[3] values = [8, 5, 4];

		l.front = values[0];
		l.front = values[1];
		assert(l.remove() == 5);
		l.front = values[2];
		assert(l.remove() == 4);
		assert(l.remove() == 8);
		assert(l.empty);

		dispose(defaultAllocator, l);
	}

    /**
     * Resets the current position.
     *
	 * Returns: $(D_KEYWORD this).
     */
    typeof(this) reset()
    {
        position = &first;
        return this;
    }

	///
	unittest
	{
		auto l = make!(SList!int)(defaultAllocator);
		int[2] values = [8, 5];

		l.current = values[0];
		l.current = values[1];
		assert(l.current == 5);
		l.advance();
		assert(l.current == 8);
		l.reset();
		assert(l.current == 5);

		dispose(defaultAllocator, l);
	}

	/**
	 * $(D_KEYWORD foreach) iteration.
	 *
	 * Params:
	 * 	dg = $(D_KEYWORD foreach) body.
	 */
	int opApply(int delegate(ref size_t i, ref T) dg)
	{
		int result;
		size_t i;

		for (position = first.next; position; position = position.next, ++i)
		{
			result = dg(i, position.content);

			if (result != 0)
			{
				return result;
			}
		}
		reset();

		return result;
	}

	///
	unittest
	{
		auto l = make!(SList!int)(defaultAllocator);
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

		dispose(defaultAllocator, l);
	}

	/// Ditto.
	int opApply(int delegate(ref T) dg)
	{
		int result;

		for (position = first.next; position; position = position.next)
		{
			result = dg(position.content);

			if (result != 0)
			{
				return result;
			}
		}
		reset();

		return result;
	}

	///
	unittest
	{
		auto l = make!(SList!int)(defaultAllocator);
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

		dispose(defaultAllocator, l);
	}

	/**
	 * Returns: $(D_KEYWORD true) if the current position is the end position.
	 */
	@property bool end() const
	{
		return empty || position.next.next is null;
	}

	/**
	 * Moves to the next element and returns it.
	 *
	 * Returns: The element on the next position.
	 */
	T advance()
	in
	{
		assert(!end);
	}
	body
	{
		position = position.next;
		return position.content;
	}

	/**
	 * Returns: Element on the current position.
	 */
	@property ref T current()
	in
	{
		assert(!empty);
	}
	body
	{
		return position.next.content;
	}

	/**
	 * Inserts a new element at the current position.
	 *
	 * Params:
	 * 	x = New element.
	 */
	@property void current(T x)
	{
		Entry* temp = make!Entry(allocator);
		
		temp.content = x;
		temp.next = position.next;
		position.next = temp;
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

	/// Current position in the list.
	protected Entry* position;

	private shared Allocator allocator;
}

interface Stuff
{
}

///
unittest
{
	auto l = make!(SList!Stuff)(defaultAllocator);

	dispose(defaultAllocator, l);
}
