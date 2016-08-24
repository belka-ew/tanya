/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Copyright: Eugene Wissner 2016.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 */  
module tanya.container.vector;

import tanya.memory;

@nogc:

/**
 * One dimensional array. It allocates automatically if needed.
 *
 * If you assign a value:
 * ---
 * auto v = make!(Vector!int)(defaultAllocator);
 * int value = 5;
 *
 * v[1000] = value;
 *
 * finalize(defaultAllocator, v);
 * ---
 * it will allocate not only for one, but for 1000 elements. So this
 * implementation is more suitable for sequential data with random access.
 *
 * Params:
 * 	T = Content type.
 */
class Vector(T)
{
@nogc:
	/**
	 * Creates a new $(D_PSYMBOL Vector).
	 *
	 * Params:
	 * 	length    = Initial length.
	 * 	allocator = The allocator should be used for the element
	 * 	            allocations.
	 */
	this(size_t length, Allocator allocator = defaultAllocator)
	{
		this.allocator = allocator;
		vector = makeArray!T(allocator, length);
	}

	/// Ditto.
	this(Allocator allocator = defaultAllocator)
	{
		this(0, allocator);
	}

	/**
	 * Removes all elements from the vector.
	 */
	~this()
	{
		finalize(allocator, vector);
	}

	/**
	 * Returns: Vector length.
	 */
	@property size_t length() const
	{
		return vector.length;
	}

	/**
	 * Expans/shrinks the vector.
	 *
	 * Params:
	 * 	length = New length.
	 */
	@property void length(size_t length)
	{
		resizeArray!T(allocator, vector, length);
	}

    ///
    unittest
    {
        auto v = make!(Vector!int)(defaultAllocator);

        v.length = 5;
        assert(v.length == 5);

		// TODO
        v.length = 7;
        assert(v.length == 7);

        v.length = 0;
        assert(v.length == 0);

        finalize(defaultAllocator, v);
    }

	/**
	 * Returns: $(D_KEYWORD true) if the vector is empty.
	 */
	@property bool empty() const
	{
		return length == 0;
	}

	static if (isFinalizable!T)
	{
		/**
		 * Removes an elements from the vector.
		 *
		 * Params:
		 * 	pos = Element index.
		 */
		void remove(size_t pos)
		{
			auto el = vector[pos];
			finalize(allocator, el);
		}
	}

	/**
	 * Assigns a value. Allocates if needed.
	 *
	 * Params:
	 * 	value = Value.
	 *
	 * Returns: Assigned value.
	 */
	T opIndexAssign(T value, size_t pos)
	{
		if (pos >= length)
		{
			resizeArray!T(allocator, vector, pos + 1);
		}
		return vector[pos] = value;
	}

	///
	unittest
	{
        auto v = make!(Vector!int)(defaultAllocator);
        int[2] values = [5, 15];

		assert(v.length == 0);
		v[1] = values[0];
		assert(v.length == 2);
		v[3] = values[0];
		assert(v.length == 4);
		v[4] = values[1];
		assert(v.length == 5);

        finalize(defaultAllocator, v);
	}

	/**
	 * Returns: The value on index $(D_PARAM pos).
	 */
	ref T opIndex(in size_t pos)
	in
	{
		assert(length > pos);
	}
	body
	{
		return vector[pos];
	}

	///
	unittest
	{
        auto v = make!(Vector!int)(defaultAllocator);
        int[2] values = [5, 15];

		v[1] = values[0];
		assert(v[1] is values[0]);
		v[3] = values[0];
		assert(v[3] is values[0]);
		v[4] = values[1];
		assert(v[4] is values[1]);
		v[0] = values[1];
		assert(v[0] is values[1]);

        finalize(defaultAllocator, v);
	}

	/**
	 * $(D_KEYWORD foreach) iteration.
	 *
	 * Params:
	 * 	dg = $(D_KEYWORD foreach) body.
	 */
	int opApply(int delegate(ref T) @nogc dg)
	{
		int result;

		foreach (e; vector)
		{
			result = dg(e);

			if (result != 0)
			{
				return result;
			}
		}
		return result;
	}

	/// Ditto.
	int opApply(int delegate(ref size_t i, ref T) @nogc dg)
	{
		int result;

		foreach (i, e; vector)
		{
			result = dg(i, e);

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
        auto v = make!(Vector!int)(defaultAllocator, 1);
        int[3] values = [5, 15, 8];

        v[0] = values[0];
        v[1] = values[1];
        v[2] = values[2];

		int i;
		foreach (e; v)
		{
			assert(i != 0 || e is values[0]);
			assert(i != 1 || e is values[1]);
			assert(i != 2 || e is values[2]);
			++i;
		}

		foreach (j, e; v)
		{
			assert(j != 0 || e is values[0]);
			assert(j != 1 || e is values[1]);
			assert(j != 2 || e is values[2]);
		}

        finalize(defaultAllocator, v);
	}

	/**
	 * Sets the first element. Allocates if the vector is empty.
     *
     * Params:
     *  x = New element.
     */
	@property void front(ref T x)
	{
		this[0] = x;
	}

	/**
	 * Returns: The first element.
     */
	@property ref inout(T) front() inout
    in
	{
		assert(!empty);
	}
	body
	{
		return vector[0];
	}

    ///
    unittest
    {
        auto v = make!(Vector!int)(defaultAllocator, 1);
        int[2] values = [5, 15];

        v.front = values[0];
        assert(v.front == 5);

        v.front = values[1];
        assert(v.front == 15);

        finalize(defaultAllocator, v);
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
		vector[0 .. $ - 1] = vector[1..$];
		resizeArray(allocator, vector, length - 1);
		return this;
	}

	///
	unittest
	{
        auto v = make!(Vector!int)(defaultAllocator, 1);
        int[2] values = [5, 15];

        v[0] = values[0];
        v[1] = values[1];
        assert(v.front is values[0]);
        assert(v.length == 2);
		v.popFront();
        assert(v.front is values[1]);
        assert(v.length == 1);
		v.popFront();
        assert(v.empty);

        finalize(defaultAllocator, v);
	}

	/**
	 * Sets the last element. Allocates if the vector is empty.
     *
     * Params:
     *  x = New element.
     */
	@property void back(ref T x)
	{
		vector[empty ? 0 : $ - 1] = x;
	}

	/**
	 * Returns: The last element.
     */
	@property ref inout(T) back() inout
    in
	{
		assert(!empty);
	}
	body
	{
		return vector[$ - 1];
	}

    ///
    unittest
    {
        auto v = make!(Vector!int)(defaultAllocator, 1);
        int[2] values = [5, 15];

        v.back = values[0];
        assert(v.back == 5);

        v.back = values[1];
        assert(v.back == 15);

        finalize(defaultAllocator, v);
    }

	/**
	 * Move position to the previous element.
	 *
	 * Returns: $(D_KEYWORD this).
	 */
	typeof(this) popBack()
	in
	{
		assert(!empty);
	}
	body
	{
		resizeArray(allocator, vector, length - 1);
		return this;
	}

	///
	unittest
	{
        auto v = make!(Vector!int)(defaultAllocator, 1);
        int[2] values = [5, 15];

        v[0] = values[0];
        v[1] = values[1];
        assert(v.back is values[1]);
        assert(v.length == 2);
		v.popBack();
        assert(v.back is values[0]);
        assert(v.length == 1);
		v.popBack();
        assert(v.empty);

        finalize(defaultAllocator, v);
	}

	/// Container.
	protected T[] vector;

	private Allocator allocator;
}

///
unittest
{
	auto v = make!(Vector!int)(defaultAllocator);

	finalize(defaultAllocator, v);
}
