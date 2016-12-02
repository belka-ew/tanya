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

import std.algorithm.comparison;
import std.traits;
import tanya.memory;

/**
 * One dimensional array.
 *
 * Params:
 * 	T = Content type.
 */
class Vector(T)
{
	/**
	 * Defines the container's primary range.
	 */
	struct Range(V)
	{
		private V[1] data;

		private @property ref inout(V) outer() inout
		{
			return data[0];
		}

		private size_t start, end;

		invariant
		{
			assert(start <= end);
		}

		private alias ElementType = typeof(data[0].vector[0]);

		private this(V data, in size_t a, in size_t b)
		{
			this.data = data;
			start = a;
			end = b;
		}

		@property Range save()
		{
			return this;
		}

		@property bool empty() const
		{
			return start >= end;
		}

		@property size_t length() const
		{
			return end - start;
		}

		alias opDollar = length;

		@property ref inout(ElementType) front() inout
		in
		{
			assert(!empty);
		}
		body
		{
			return outer[start];
		}

		@property ref inout(ElementType) back() inout
		in
		{
			assert(!empty);
		}
		body
		{
			return outer[end - 1];
		}

		void popFront()
		in
		{
			assert(!empty);
		}
		body
		{
			++start;
		}

		void popBack()
		in
		{
			assert(!empty);
		}
		body
		{
			--end;
		}

		ref inout(ElementType) opIndex(in size_t i) inout
		in
		{
			assert(start + i < end);
		}
		body
		{
			return outer[start + i];
		}

		Range opIndex()
		{
			return typeof(return)(outer, start, end);
		}

		Range opSlice(in size_t i, in size_t j)
		in
		{
			assert(i <= j);
			assert(start + j <= end);
		}
		body
		{
			return typeof(return)(outer, start + i, start + j);
		}

		Range!(const(V)) opIndex() const
		{
			return typeof(return)(outer, start, end);
		}

		Range!(const(V)) opSlice(in size_t i, in size_t j) const
		in
		{
			assert(i <= j);
			assert(start + j <= end);
		}
		body
		{
			return typeof(return)(outer, start + i, start + j);
		}

		static if (isMutable!V)
		{
			Range opIndexAssign(in ElementType value)
			in
			{
				assert(end <= outer.length);
			}
			body
			{
				return outer[start .. end] = value;
			}

			Range opSliceAssign(in ElementType value, in size_t i, in size_t j)
			in
			{
				assert(start + j <= end);
			}
			body
			{
				return outer[start + i .. start + j] = value;
			}

			Range opSliceAssign(in Range!Vector value, in size_t i, in size_t j)
			in
			{
				assert(length == value.length);
			}
			body
			{
				return outer[start + i .. start + j] = value;
			}

			Range opSliceAssign(in T[] value, in size_t i, in size_t j)
			in
			{
				assert(j - i == value.length);
			}
			body
			{
				return outer[start + i .. start + j] = value;
			}
		}
	}

	/**
	 * Creates an empty $(D_PSYMBOL Vector).
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
	 * Creates a new $(D_PSYMBOL Vector).
	 *
	 * Params:
	 *  U      = Variadic template for the constructor parameters.
	 * 	params = Values to initialize the array with. The last parameter can
	 * 	         be an allocator, if not, $(D_PSYMBOL theAllocator) is used.
	 */
	this(U...)(U params)
	{
		static if (isImplicitlyConvertible!(typeof(params[$ - 1]), IAllocator))
		{
			allocator = params[$ - 1];
			auto values = params[0 .. $ - 1];
		}
		else
		{
			allocator = theAllocator;
			alias values = params;
		}

		resizeArray!T(allocator, vector, values.length);
		foreach (i, v; values)
		{
			vector[i] = v;
		}
	}

	/**
	 * Destroys this $(D_PSYMBOL Vector).
	 */
	~this()
	{
		dispose(allocator, vector);
	}

	/**
	 * Removes all elements.
	 */
	void clear()
	{
		resizeArray!T(allocator, vector, 0);
	}

	///
	unittest
	{
		auto v = theAllocator.make!(Vector!int)(18, 20, 15);

		v.clear();
		assert(v.length == 0);
	}

	/**
	 * Returns: Vector length.
	 */
	@property size_t length() const
	{
		return vector.length;
	}

	/// Ditto.
	size_t opDollar() const
	{
		return length;
	}

	/**
	 * Expands/shrinks the vector.
	 *
	 * Params:
	 * 	length = New length.
	 */
	@property void length(in size_t length)
	{
		resizeArray!T(allocator, vector, length);
	}

	///
	unittest
	{
		auto v = theAllocator.make!(Vector!int);

		v.length = 5;
		assert(v.length == 5);

		v.length = 7;
		assert(v.length == 7);

		v.length = 0;
		assert(v.length == 0);
	}

	/**
	 * Returns: $(D_KEYWORD true) if the vector is empty.
	 */
	@property bool empty() const
	{
		return vector.length == 0;
	}

	/**
	 * Removes $(D_PARAM howMany) elements from the vector.
	 *
	 * This method doesn't fail if it could not remove $(D_PARAM howMany)
	 * elements. Instead, if $(D_PARAM howMany) is greater than the vector
	 * length, all elements are removed.
	 *
	 * Params:
	 * 	howMany = How many elements should be removed.
	 *
	 * Returns: The number of elements removed
	 */
	size_t removeBack(in size_t howMany)
	{
		immutable toRemove = min(howMany, length);

		static if (hasElaborateDestructor!T)
		{
			foreach (ref e; vector[$ - toRemove ..$])
			{
				allocator.dispose(e);
			}
		}
		length = length - toRemove;

		return toRemove;
	}

	///
	unittest
	{
		auto v = theAllocator.make!(Vector!int)(5, 18, 17);

		assert(v.removeBack(0) == 0);
		assert(v.removeBack(2) == 2);
		assert(v.removeBack(3) == 1);
		assert(v.removeBack(3) == 0);

		theAllocator.dispose(v);
	}

	/**
	 * Assigns a value to the element with the index $(D_PARAM pos).
	 *
	 * Params:
	 * 	value = Value.
	 *
	 * Returns: Assigned value.
	 *
	 * Precondition: $(D_INLINECODE length > pos)
	 */
	T opIndexAssign(in T value, in size_t pos)
	in
	{
		assert(length > pos);
	}
	body
	{
		return vector[pos] = value;
	}

	/// Ditto.
	Range!Vector opIndexAssign(in T value)
	{
		vector[0..$] = value;
		return opIndex();
	}

	///
	unittest
	{
		auto v1 = theAllocator.make!(Vector!int)(12, 1, 7);

		v1[] = 3;
		assert(v1[0] == 3);
		assert(v1[1] == 3);
		assert(v1[2] == 3);

		theAllocator.dispose(v1);
	}


	/**
	 * Returns: The value on index $(D_PARAM pos).
	 *
	 * Precondition: $(D_INLINECODE length > pos)
	 */
	ref inout(T) opIndex(in size_t pos) inout
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
		auto v = theAllocator.make!(Vector!int)(6, 123, 34, 5);

		assert(v[0] == 6);
		assert(v[1] == 123);
		assert(v[2] == 34);
		assert(v[3] == 5);

		theAllocator.dispose(v);
	}

	/**
	 * Comparison for equality.
	 *
	 * Params:
	 * 	o = The vector to compare with.
	 *
	 * Returns: $(D_KEYWORD true) if the vectors are equal, $(D_KEYWORD false)
	 *          otherwise.
	 */
	override bool opEquals(Object o)
	{
		auto v = cast(Vector) o;

		return v is null ? super.opEquals(o) : vector == v.vector;
	}

	///
	unittest
	{
		auto v1 = theAllocator.make!(Vector!int);
		auto v2 = theAllocator.make!(Vector!int);

		assert(v1 == v2);

		v1.length = 1;
		v2.length = 2;
		assert(v1 != v2);

		v1.length = 2;
		v1[0] = v2[0] = 2;
		v1[1] = 3;
		v2[1] = 4;
		assert(v1 != v2);

		v2[1] = 3;
		assert(v1 == v2);

		theAllocator.dispose(v1);
		theAllocator.dispose(v2);
	}

	/**
	 * $(D_KEYWORD foreach) iteration.
	 *
	 * Params:
	 * 	dg = $(D_KEYWORD foreach) body.
	 */
	int opApply(scope int delegate(ref T) dg)
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
	int opApply(scope int delegate(ref size_t i, ref T) dg)
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
		auto v = theAllocator.make!(Vector!int)(5, 15, 8);

		size_t i;
		foreach (j, ref e; v)
		{
			i = j;
		}
		assert(i == 2);

		foreach (j, e; v)
		{
			assert(j != 0 || e == 5);
			assert(j != 1 || e == 15);
			assert(j != 2 || e == 8);
		}
		theAllocator.dispose(v);
	}

	/**
	 * Returns: The first element.
	 *
	 * Precondition: $(D_INLINECODE length > 0)
	 */
	@property ref inout(T) front() inout
	in
	{
		assert(vector.length > 0);
	}
	body
	{
		return vector[0];
	}

	///
	unittest
	{
		auto v = theAllocator.make!(Vector!int)(5);

		assert(v.front == 5);

		v.length = 2;
		v[1] = 15;
		assert(v.front == 5);

		theAllocator.dispose(v);
	}

	/**
	 * Returns: The last element.
	 *
	 * Precondition: $(D_INLINECODE length > 0)
	 */
	@property ref inout(T) back() inout
	in
	{
		assert(vector.length > 0);
	}
	body
	{
		return vector[$ - 1];
	}

	///
	unittest
	{
		auto v = theAllocator.make!(Vector!int)(5);

		assert(v.back == 5);

		v.length = 2;
		v[1] = 15;
		assert(v.back == 15);

		theAllocator.dispose(v);
	}

	/**
	 * Returns: A range that iterates over elements of the container, in
	 *          forward order.
	 */
	Range!Vector opIndex()
	{
		return typeof(return)(this, 0, length);
	}

	/// Ditto.
	Range!(const Vector) opIndex() const
	{
		return typeof(return)(this, 0, length);
	}

	/// Ditto.
	Range!(immutable Vector) opIndex() immutable
	{
		return typeof(return)(this, 0, length);
	}

	/**
	 * Params:
	 * 	i = Slice start.
	 * 	j = Slice end.
	 *
	 * Returns: A range that iterates over elements of the container from
	 *          index $(D_PARAM i) up to (excluding) index $(D_PARAM j).
	 *
	 * Precondition: $(D_INLINECODE i <= j && j <= length)
	 */
	Range!Vector opSlice(in size_t i, in size_t j)
	in
	{
		assert(i <= j);
		assert(j <= length);
	}
	body
	{
		return typeof(return)(this, i, j);
	}

	/// Ditto.
	Range!(const Vector) opSlice(in size_t i, in size_t j) const
	in
	{
		assert(i <= j);
		assert(j <= length);
	}
	body
	{
		return typeof(return)(this, i, j);
	}

	/// Ditto.
	Range!(immutable Vector) opSlice(in size_t i, in size_t j) immutable
	in
	{
		assert(i <= j);
		assert(j <= length);
	}
	body
	{
		return typeof(return)(this, i, j);
	}

	/**
	 * Slicing assignment.
	 *
	 * Params:
	 * 	value = New value.
	 * 	i     = Slice start.
	 * 	j     = Slice end.
	 *
	 * Returns: Assigned value.
	 *
	 * Precondition: $(D_INLINECODE i <= j && j <= length);
	 *               The lenghts of the ranges and slices match.
	 */
	Range!Vector opSliceAssign(in T value, in size_t i, in size_t j)
	in
	{
		assert(i <= j);
		assert(j <= length);
	}
	body
	{
		vector[i .. j] = value;
		return opSlice(i, j);
	}

	/// Ditto.
	Range!Vector opSliceAssign(in Range!Vector value, in size_t i, in size_t j)
	in
	{
		assert(j - i == value.length);
	}
	body
	{
		vector[i .. j] = value.outer.vector[value.start .. value.end];
		return opSlice(i, j);
	}

	/// Ditto.
	Range!Vector opSliceAssign(in T[] value, in size_t i, in size_t j)
	in
	{
		assert(j - i == value.length);
	}
	body
	{
		vector[i .. j] = value;
		return opSlice(i, j);
	}

	///
	unittest
	{
		auto v1 = theAllocator.make!(Vector!int)(3, 3, 3);
		auto v2 = theAllocator.make!(Vector!int)(1, 2);

		v1[0..2] = 286;
		assert(v1[0] == 286);
		assert(v1[1] == 286);
		assert(v1[2] == 3);

		v2[0..$] = v1[1..3];
		assert(v2[0] == 286);
		assert(v2[1] == 3);

		theAllocator.dispose(v2);
		theAllocator.dispose(v1);
	}

	private T[] vector;

	private IAllocator allocator;
}

///
unittest
{
	auto v = theAllocator.make!(Vector!int)(5, 15, 8);

	assert(v.front == 5);
	assert(v[1] == 15);
	assert(v.back == 8);
}
