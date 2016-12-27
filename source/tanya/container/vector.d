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

import core.exception;
import std.algorithm.comparison;
import std.range.primitives;
import std.traits;
public import tanya.enums : IL;
import tanya.memory;

version (unittest)
{
	struct TestA
	{
		~this() @nogc
		{
		}
	}
}

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
	struct Range(V)
	{
		private alias E = typeof(data.vector[0]);

		private V* data;

		private @property ref inout(V) outer() inout return
		{
			return *data;
		}

		private size_t start, end;

		invariant
		{
			assert(start <= end);
		}

		private this(ref inout V data, in size_t a, in size_t b) inout
		in
		{
			assert(a <= b);
			assert(b <= data.length);
		}
		body
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

		@property ref inout(E) front() inout
		{
			return outer[start];
		}

		@property ref inout(E) back() inout
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

		ref inout(E) opIndex(in size_t i) inout
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

		static if (isMutable!V)
		{
			Range opIndexAssign(T value)
			{
				return outer[start .. end] = value;
			}

			Range opSliceAssign(T value, in size_t i, in size_t j)
			{
				return outer[start + i .. start + j] = value;
			}

			Range opSliceAssign(Range value, in size_t i, in size_t j)
			{
				return outer[start + i .. start + j] = value;
			}

			Range opSliceAssign(T[] value, in size_t i, in size_t j)
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

		/**
		 * Creates a new $(D_PSYMBOL Vector).
		 *
		 * Params:
		 * 	U         = Type of the static array with the initial elements.
		 * 	params    = Values to initialize the array with. Use $(D_PSYMBOL IL)
		 * 	            to generate a list.
		 * 	allocator = Allocator.
		 */
		this(U)(U init, shared Allocator allocator = defaultAllocator)
			if (isStaticArray!U)
		in
		{
			assert(allocator !is null);
			static assert(init.length > 0);
		}
		body
		{
			this(allocator);
			allocator.resize!(T, false)(vector, init.length);
			vector[0 .. $] = init[0 .. $];
			length_ = init.length;
		}

		/// Ditto.
		this(U)(U init, shared Allocator allocator = defaultAllocator) const
			if (isStaticArray!U)
		in
		{
			assert(allocator !is null);
			static assert(init.length > 0);
		}
		body
		{
			allocator_ = cast(const shared Allocator) allocator;

			T[] buf;
			allocator.resize!(T, false)(buf, init.length);
			buf[0 .. $] = init[0 .. $];
			vector = cast(const(T[])) buf;
			length_ = init.length;
		}

		/// Ditto.
		this(U)(U init, shared Allocator allocator = defaultAllocator) immutable
			if (isStaticArray!U)
		in
		{
			assert(allocator !is null);
			static assert(init.length > 0);
		}
		body
		{
			allocator_ = cast(immutable Allocator) allocator;

			T[] buf;
			allocator.resize!(T, false)(buf, init.length);
			buf[0 .. $] = init[0 .. $];
			vector = cast(immutable(T[])) buf;
			length_ = init.length;
		}

		/// Ditto.
		this(shared Allocator allocator)
		in
		{
			assert(allocator !is null);
		}
		body
		{
			allocator_ = allocator;
		}

		///
		unittest
		{
			auto v = Vector!int(IL(3, 8, 2));

			assert(v.capacity == 3);
			assert(v.length == 3);
			assert(v[0] == 3 && v[1] == 8 && v[2] == 2);
		}

		/**
		 * Destroys this $(D_PSYMBOL Vector).
		 */
		~this()
		{
			allocator.dispose(vector);
		}

		/**
		 * Removes all elements.
		 */
		void clear()
		{
			length = 0;
		}

		///
		unittest
		{
			auto v = Vector!int(IL(18, 20, 15));
			v.clear();
			assert(v.length == 0);
			assert(v.capacity == 3);
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
		alias opDollar = length;

		/**
		 * Expands/shrinks the vector.
		 *
		 * Params:
		 * 	len = New length.
		 */
		@property void length(in size_t len)
		{
			if (len > length)
			{
				reserve(len);
				vector[length .. len] = T.init;
			}
			else if (len < length)
			{
				static if (hasElaborateDestructor!T)
				{
					foreach (ref e; vector[len - 1 .. length_])
					{
						destroy(e);
					}
				}
			}
			else
			{
				return;
			}
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

			assert(v[$ - 1] == 0);
			v[$ - 1] = 3;
			assert(v[$ - 1] == 3);

			v.length = 0;
			assert(v.length == 0);
			assert(v.capacity == 7);
		}

		/**
		 * Reserves space for $(D_PARAM size) elements.
		 *
		 * Params:
		 * 	size = Desired size.
		 */
		void reserve(in size_t size) @trusted
		{
			if (vector.length < size)
			{
				void[] buf = vector;
				allocator.reallocate(buf, size * T.sizeof);
				vector = cast(T[]) buf;
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
		 * Requests the vector to reduce its capacity to fit the $(D_PARAM size).
		 *
		 * The request is non-binding. The vector won't become smaller than the
		 * $(D_PARAM length).
		 *
		 * Params:
		 * 	size = Desired size.
		 */
		void shrink(in size_t size) @trusted
		{
			auto n = max(length, size);
			void[] buf = vector;
			allocator.reallocate(buf, n * T.sizeof);
			vector = cast(T[]) buf;
		}

		///
		unittest
		{
			Vector!int v;
			assert(v.capacity == 0);
			assert(v.length == 0);

			v.reserve(5);
			v.insertBack(1);
			v.insertBack(3);
			assert(v.capacity == 5);
			assert(v.length == 2);

			v.shrink(4);
			assert(v.capacity == 4);
			assert(v.length == 2);

			v.shrink(1);
			assert(v.capacity == 2);
			assert(v.length == 2);
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

			length = length - toRemove;

			return toRemove;
		}

		/// Ditto.
		alias remove = removeBack;

		///
		unittest
		{
			auto v = Vector!int(IL(5, 18, 17));

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
		size_t insertBack(T el)
		{
			reserve(length + 1);
			vector[length] = el;
			++length_;
			return 1;
		}

		/// Ditto.
		size_t insertBack(Range!Vector el)
		{
			immutable newLength = length + el.length;

			reserve(newLength);
			vector[length .. newLength] = el.outer.vector[el.start .. el.end];
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

			auto v2 = Vector!int(IL(34, 234));
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
		T opIndexAssign(T value, in size_t pos)
		in
		{
			assert(length > pos);
		}
		body
		{
			return vector[pos] = value;
		}

		/// Ditto.
		Range!Vector opIndexAssign(T value)
		{
			vector[0 .. $] = value;
			return opIndex();
		}

		///
		unittest
		{
			auto v1 = Vector!int(IL(12, 1, 7));

			v1[] = 3;
			assert(v1[0] == 3);
			assert(v1[1] == 3);
			assert(v1[2] == 3);
		}

		/**
		 * Params:
		 * 	pos = Index.
		 *
		 * Returns: The value at a specified index.
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

		/**
		 * Returns: Random access range that iterates over elements of the vector, in
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

		///
		unittest
		{
			const v1 = Vector!int(IL(6, 123, 34, 5));

			assert(v1[0] == 6);
			assert(v1[1] == 123);
			assert(v1[2] == 34);
			assert(v1[3] == 5);
			static assert(is(typeof(v1[0]) == const(int)));
			static assert(is(typeof(v1[])));

			auto v2 = immutable Vector!int(IL(6, 123, 34, 5));
			static assert(is(typeof(v2[0]) == immutable(int)));
			static assert(is(typeof(v2[])));
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
		bool opEquals(typeof(this) v) const
		{
			return opEquals(v);
		}

		/// Ditto.
		bool opEquals(ref typeof(this) v) const
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
			auto v = Vector!int(IL(5, 15, 8));

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
			auto v = Vector!int(IL(5, 15, 8));
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
			auto v = Vector!int(IL(5));

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
			return vector[length_ - 1];
		}

		///
		unittest
		{
			auto v = Vector!int(IL(5));

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
		Range!Vector opSliceAssign(T value, in size_t i, in size_t j)
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
		Range!Vector opSliceAssign(Range!Vector value, in size_t i, in size_t j)
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
		Range!Vector opSliceAssign(T[] value, in size_t i, in size_t j)
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
			auto v1 = Vector!int(IL(3, 3, 3));
			auto v2 = Vector!int(IL(1, 2));

			v1[0 .. 2] = 286;
			assert(v1[0] == 286);
			assert(v1[1] == 286);
			assert(v1[2] == 3);

			v2[0 .. $] = v1[1 .. 3];
			assert(v2[0] == 286);
			assert(v2[1] == 3);
		}

		mixin DefaultAllocator;
	}
}

///
unittest
{
	auto v = Vector!int(IL(5, 15, 8));

	assert(v.front == 5);
	assert(v[1] == 15);
	assert(v.back == 8);
}

private @nogc unittest
{
	// Test the destructor can be called at the end of the scope.
	auto a = Vector!A();

	// Test that structs can be members of the vector.
	static assert(is(typeof(Vector!TestA())));
}

private @nogc unittest
{
	const v1 = Vector!int();
	const Vector!int v2;
	const v3 = Vector!int(IL(1, 5, 8));
	static assert(is(typeof(v3.vector) == const(int[])));
	static assert(is(typeof(v3.vector[0]) == const(int)));

	immutable v4 = immutable Vector!int();
	immutable v5 = immutable Vector!int(IL(2, 5, 8));
	static assert(is(typeof(v4.vector) == immutable(int[])));
	static assert(is(typeof(v4.vector[0]) == immutable(int)));
}

private @nogc unittest
{
	// Test that immutable/const vectors return usable ranges.
	auto v = immutable Vector!int(IL(1, 2, 4));
	auto r = v[];

	assert(r.back == 4);
	r.popBack();
	assert(r.back == 2);
	r.popBack();
	assert(r.back == 1);
	r.popBack();
}

private @nogc unittest
{
	Vector!int v1;
	const Vector!int v2;

	auto r1 = v1[];
	auto r2 = v1[];

	assert(r1.length == 0);
	assert(r2.empty);
	assert(r1 == r2);
}
