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
import std.range.primitives;
import std.traits;
import tanya.memory;

/**
 * One dimensional array.
 *
 * Params:
 * 	T = Content type.
 */
template Vector(T)
{
	/**
	 * Defines the container's primary range.
	 */
	struct Range
	{
		private Vector* data;

		private @property ref inout(Vector) outer() inout return
		{
			return *data;
		}

		private size_t start, end;

		invariant
		{
			assert(start <= end);
			assert(start == 0 || end > 0);
		}

		protected this(ref Vector data, in size_t a, in size_t b)
		{
			this.data = &data;
			start = a;
			end = b;
		}

		@property Range save()
		{
			return this;
		}

		@property bool empty() inout const
		{
			return start == end;
		}

		@property size_t length() inout const
		{
			return end - start;
		}

		alias opDollar = length;

		@property ref inout(T) front() inout
		in
		{
			assert(!empty);
		}
		body
		{
			return outer[start];
		}

		@property ref inout(T) back() inout
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

		ref inout(T) opIndex(in size_t i) inout
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

		static if (isMutable!Vector)
		{
			Range opIndexAssign(in T value)
			in
			{
				assert(end <= outer.length);
			}
			body
			{
				return outer[start .. end] = value;
			}

			Range opSliceAssign(in T value, in size_t i, in size_t j)
			in
			{
				assert(start + j <= end);
			}
			body
			{
				return outer[start + i .. start + j] = value;
			}

			Range opSliceAssign(in Range value, in size_t i, in size_t j)
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

	struct Vector
	{
		private size_t length_;

		invariant
		{
			assert(length_ <= vector.length);
		}

		/// Internal representation.
		private T[] vector;

		/// The allocator.
		private shared Allocator allocator;

		/**
		 * Creates an empty $(D_PSYMBOL Vector).
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
		 * Creates a new $(D_PSYMBOL Vector).
		 *
		 * Params:
		 *  U      = Variadic template for the constructor parameters.
		 * 	params = Values to initialize the array with. The last parameter can
		 * 	         be an allocator, if not, $(D_PSYMBOL defaultAllocator) is used.
		 */
		this(U...)(U params)
		{
			static if (isImplicitlyConvertible!(typeof(params[$ - 1]), Allocator))
			{
				allocator = params[$ - 1];
				auto values = params[0 .. $ - 1];
			}
			else
			{
				allocator = defaultAllocator;
				alias values = params;
			}

			resizeArray!T(allocator, vector, values.length);
			length_ = values.length;

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
			if (allocator is null)
			{
				allocator = defaultAllocator;
			}
			dispose(allocator, vector);
		}

		/**
		 * Removes all elements.
		 */
		void clear()
		{
			length_ = 0;
		}

		///
		unittest
		{
			auto v = defaultAllocator.make!(Vector!int)(18, 20, 15);
			v.clear();
			assert(v.length == 0);
		}

		/**
		 * Returns: How many elements the vector can contain without reallocating.
		 */
		@property size_t capacity() inout const
		{
			return vector.length;
		}

		/**
		 * Returns: Vector length.
		 */
		@property size_t length() inout const
		{
			return length_;
		}

		/// Ditto.
		size_t opDollar() inout const
		{
			return length;
		}

		/**
		 * Reserves space for $(D_PARAM n) elements.
		 */
		void reserve(in size_t n)
		{
			if (allocator is null)
			{
				allocator = defaultAllocator;
			}
			if (vector.length < n)
			{
				allocator.resizeArray!T(vector, n);
			}
		}

		///
		unittest
		{
			Vector!int v;
			assert(v.capacity == 0);
			assert(v.length == 0);

			v.reserve(3);
			assert(v.capacity == 3);
			assert(v.length == 0);
		}

		/**
		 * Expands/shrinks the vector.
		 *
		 * Params:
		 * 	len = New length.
		 */
		@property void length(in size_t len)
		{
			reserve(len);
			length_ = len;
		}

		///
		unittest
		{
			Vector!int v;

			v.length = 5;
			assert(v.length == 5);
			assert(v.capacity == 5);

			v.length = 7;
			assert(v.length == 7);
			assert(v.capacity == 7);

			v.length = 0;
			assert(v.length == 0);
			assert(v.capacity == 7);
		}

		/**
		 * Returns: $(D_KEYWORD true) if the vector is empty.
		 */
		@property bool empty() inout const
		{
			return length == 0;
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
		size_t removeBack(in size_t howMany = 1)
		{
			immutable toRemove = min(howMany, length);

			static if (hasElaborateDestructor!T)
			{
				foreach (ref e; vector[$ - toRemove ..$])
				{
					allocator.dispose(e);
				}
			}
			length_ -= toRemove;

			return toRemove;
		}

		/// Ditto.
		alias remove = removeBack;

		///
		unittest
		{
			auto v = Vector!int(5, 18, 17);

			assert(v.removeBack(0) == 0);
			assert(v.removeBack(2) == 2);
			assert(v.removeBack(3) == 1);
			assert(v.removeBack(3) == 0);
		}

		/**
		 * Inserts the $(D_PARAM el) into the vector.
		 *
		 * Returns: The number of elements inserted.
		 */
		size_t insertBack(in T el)
		{
			reserve(length + 1);
			vector[length] = el;
			++length_;
			return 1;
		}

		/// Ditto.
		size_t insertBack(in Range el)
		{
			immutable newLength = length + el.length;

			reserve(newLength);
			vector[length .. newLength] = el.data.vector[el.start .. el.end];
			length_ = newLength;

			return el.length;
		}

		/// Ditto.
		size_t insertBack(R)(R el)
			if (isInputRange!R && isImplicitlyConvertible!(ElementType!R, T))
		{
			immutable rLen = walkLength(el);

			reserve(length + rLen);
			while (!el.empty)
			{
				vector[length_] = el.front;
				el.popFront();
				length_++;
			}
			return rLen;
		}

		/// Ditto.
		alias insert = insertBack;

		///
		unittest
		{
			struct TestRange
			{
				int counter = 6;

				int front()
				{
					return counter;
				}

				void popFront()
				{
					counter -= 2;
				}

				bool empty()
				{
					return counter == 0;
				}
			}

			Vector!int v1;

			assert(v1.insertBack(5) == 1);
			assert(v1.length == 1);
			assert(v1.capacity == 1);
			assert(v1.back == 5);

			assert(v1.insertBack(TestRange()) == 3);
			assert(v1.length == 4);
			assert(v1.capacity == 4);
			assert(v1[0] == 5 && v1[1] == 6 && v1[2] == 4 && v1[3] == 2);

			auto v2 = Vector!int(34, 234);
			assert(v1.insertBack(v2[]) == 2);
			assert(v1.length == 6);
			assert(v1.capacity == 6);
			assert(v1[4] == 34 && v1[5] == 234);
		}

		/**
		 * Assigns a value to the element with the index $(D_PARAM pos).
		 *
		 * Params:
		 * 	value = Value.
		 * 	pos   = Position.
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
		Range opIndexAssign(in T value)
		{
			vector[0 .. $] = value;
			return opIndex();
		}

		///
		unittest
		{
			auto v1 = Vector!int(12, 1, 7);

			v1[] = 3;
			assert(v1[0] == 3);
			assert(v1[1] == 3);
			assert(v1[2] == 3);
		}

		/**
		 * Returns: The value on index $(D_PARAM pos) or a range that iterates over
		 *          elements of the vector, in forward order.
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

		/// Ditto.
		Range opIndex()
		{
			return typeof(return)(this, 0, length);
		}

		///
		unittest
		{
			auto v = Vector!int(6, 123, 34, 5);

			assert(v[0] == 6);
			assert(v[1] == 123);
			assert(v[2] == 34);
			assert(v[3] == 5);
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
		bool opEquals(typeof(this) v)
		{
			return opEquals(v);
		}

		/// Ditto.
		bool opEquals(ref typeof(this) v)
		{
			return vector == v.vector;
		}

		///
		unittest
		{
			Vector!int v1, v2;
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
				if ((result = dg(e)) != 0)
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
				if ((result = dg(i, e)) != 0)
				{
					return result;
				}
			}
			return result;
		}

		/// Ditto.
		int opApplyReverse(scope int delegate(ref T) dg)
		{
			int result;

			foreach_reverse (e; vector)
			{
				if ((result = dg(e)) != 0)
				{
					return result;
				}
			}
			return result;
		}

		/// Ditto.
		int opApplyReverse(scope int delegate(ref size_t i, ref T) dg)
		{
			int result;

			foreach_reverse (i, e; vector)
			{
				if ((result = dg(i, e)) != 0)
				{
					return result;
				}
			}
			return result;
		}

		///
		unittest
		{
			auto v = Vector!int(5, 15, 8);

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
		}

		///
		unittest
		{
			auto v = Vector!int(5, 15, 8);
			size_t i;

			foreach_reverse (j, ref e; v)
			{
				i = j;
			}
			assert(i == 0);

			foreach_reverse (j, e; v)
			{
				assert(j != 2 || e == 8);
				assert(j != 1 || e == 15);
				assert(j != 0 || e == 5);
			}
		}

		/**
		 * Returns: The first element.
		 *
		 * Precondition: $(D_INLINECODE length > 0)
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
			auto v = Vector!int(5);

			assert(v.front == 5);

			v.length = 2;
			v[1] = 15;
			assert(v.front == 5);
		}

		/**
		 * Returns: The last element.
		 *
		 * Precondition: $(D_INLINECODE length > 0)
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
			auto v = Vector!int(5);

			assert(v.back == 5);

			v.length = 2;
			v[1] = 15;
			assert(v.back == 15);
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
		Range opSlice(in size_t i, in size_t j)
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
		Range opSliceAssign(in T value, in size_t i, in size_t j)
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
		Range opSliceAssign(in Range value, in size_t i, in size_t j)
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
		Range opSliceAssign(in T[] value, in size_t i, in size_t j)
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
			auto v1 = Vector!int(3, 3, 3);
			auto v2 = Vector!int(1, 2);

			v1[0 .. 2] = 286;
			assert(v1[0] == 286);
			assert(v1[1] == 286);
			assert(v1[2] == 3);

			v2[0 .. $] = v1[1 .. 3];
			assert(v2[0] == 286);
			assert(v2[1] == 3);
		}
	}
}

///
unittest
{
	auto v = Vector!int(5, 15, 8);

	assert(v.front == 5);
	assert(v[1] == 15);
	assert(v.back == 8);
}

private unittest
{
//	const Vector!int v;
}
