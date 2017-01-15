/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Copyright: Eugene Wissner 2016-2017.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 */  
module tanya.container.vector;

import core.checkedint;
import core.exception;
import std.algorithm.comparison;
import std.algorithm.mutation;
import std.conv;
import std.range.primitives;
import std.meta;
import std.traits;
public import tanya.meta.gen : IL;
import tanya.memory;

version (unittest)
{
	import tanya.container.entry;
	struct SWithDtor
	{
		~this() @nogc
		{
		}
	}
}

// Defines the container's primary range.
private struct Range(E)
{
	private E* begin, end;

	invariant
	{
		assert(begin <= end);
	}

	private this(E* begin, E* end)
	in
	{
		assert(begin <= end);
	}
	body
	{
		this.begin = begin;
		this.end = end;
	}

	private this(in E* begin, in E* end) const
	in
	{
		assert(begin <= end);
	}
	body
	{
		this.begin = begin;
		this.end = end;
	}

	@property Range save()
	{
		return this;
	}

	@property bool empty() const
	{
		return begin == end;
	}

	@property size_t length() const
	{
		return end - begin;
	}

	alias opDollar = length;

	@property ref inout(E) front() inout @trusted
	in
	{
		assert(!empty);
	}
	body
	{
		return *begin;
	}

	@property ref inout(E) back() inout @trusted
	in
	{
		assert(!empty);
	}
	body
	{
		return *(end - 1);
	}

	void popFront() @trusted
	in
	{
		assert(!empty);
	}
	body
	{
		++begin;
	}

	void popBack() @trusted
	in
	{
		assert(!empty);
	}
	body
	{
		--end;
	}

	ref inout(E) opIndex(in size_t i) inout @trusted
	in
	{
		assert(i < length);
	}
	body
	{
		return *(begin + i);
	}

	Range opIndex()
	{
		return typeof(return)(begin, end);
	}

	const(Range) opIndex() const
	{
		return typeof(return)(begin, end);
	}

	Range opSlice(in size_t i, in size_t j)
	in
	{
		assert(i <= j);
		assert(j < length);
	}
	body
	{
		return typeof(return)(begin + i, begin + j);
	}

	const(Range) opSlice(in size_t i, in size_t j) const
	in
	{
		assert(i <= j);
		assert(j < length);
	}
	body
	{
		return typeof(return)(begin + i, begin + j);
	}

	bool opEquals()(Range that) const @trusted
	{
		if (length != that.length)
		{
			return false;
		}
		for (const(E)* i = begin; i != end; ++i)
		{
			if (*i != that.front)
			{
				return false;
			}
			that.popFront();
		}
		return true;
	}

	inout(E[]) get() inout
	{
		return begin[0 .. length];
	}

	static if (isMutable!E)
	{
		bool opEquals(Range that) @trusted
		{
			if (length != that.length)
			{
				return false;
			}
			for (E* i = begin; i != end; ++i)
			{
				if (*i != that.front)
				{
					return false;
				}
				that.popFront();
			}
			return true;
		}

		ref E opIndexAssign(ref E value, in size_t pos) @trusted
		in
		{
			assert(length > pos);
		}
		body
		{
			return *(begin + pos) = value;
		}

		/// Ditto.
		E opIndexAssign(E value, in size_t pos)
		{
			return opIndexAssign(value, pos);
		}

		Range opIndexAssign(ref E value) @trusted
		{
			E* begin = this.begin;
			for (E* e = this.begin; e != end; ++e)
			{
				*e = value;
			}
			return typeof(return)(begin, end);
		}

		Range opIndexAssign(E value)
		{
			return opIndexAssign(value);
		}

		Range opSliceAssign(ref E value, in size_t i, in size_t j) @trusted
		in
		{
			assert(i <= j);
			assert(j < length);
		}
		body
		{
			E* begin = this.begin + i;
			E* end = this.begin + j;
			for (E* e = begin; e != end; ++e)
			{
				*e = value;
			}
			return typeof(return)(begin, end);
		}

		Range opSliceAssign(E value)
		{
			return opSliceAssign(value);
		}

		Range opSliceAssign(R)(R value, in size_t i, in size_t j) @trusted
			if (!isInfinite!R
			 && isInputRange!R
			 && isImplicitlyConvertible!(ElementType!R, T))
		in
		{
			assert(j - i == walkLength(value));
		}
		body
		{
			T* begin = this.begin + i;
			const T* end = this.begin + j;
			for (T* v = begin; v != end; ++v, value.popFront())
			{
				*v = value.front;
			}
			return typeof(return)(begin, end);
		}

		Range opSliceAssign(R)(R value, in size_t i, in size_t j)
			if (isStaticArray!R && isImplicitlyConvertible!(ElementType!R, T))
		{
			return opSliceAssign(value[], i, j);
		}
	}
}

/**
 * One dimensional array.
 *
 * Params:
 * 	T = Content type.
 */
struct Vector(T)
{
	private size_t length_;
	private T* vector;
	private size_t capacity_;

	invariant
	{
		assert(length_ <= capacity_);
		assert(capacity_ == 0 || vector !is null);
	}

	/**
	 * Creates a new $(D_PSYMBOL Vector).
	 *
	 * Params:
	 * 	R         = Type of the static array with the initial elements.
	 * 	init      = Values to initialize the array with. Use $(D_PSYMBOL IL).
	 * 	            to generate a list.
	 * 	allocator = Allocator.
	 */
	this(R)(auto in ref R init, shared Allocator allocator = defaultAllocator)
		if (isStaticArray!R && isImplicitlyConvertible!(ElementType!R, T))
	{
		this(allocator);
		insertBack(init[]);
	}

	/// Ditto.
	this(R)(auto in ref R init, shared Allocator allocator = defaultAllocator)
		if (!isInfinite!R
		 && isInputRange!R
		 && isImplicitlyConvertible!(ElementType!R, T))
	{
		this(allocator);
		insertBack(init);
	}

	/**
	 * Initializes this vector from another one.
	 *
	 * If $(D_PARAM init) is passed by value, it won't be copied, but moved
	 * If the allocator of ($D_PARAM init) matches $(D_PARAM allocator),
	 * $(D_KEYWORD this) will just take the ownership over $(D_PARAM init)'s
	 * storage, otherwise, the storage will be allocated with
	 * $(D_PARAM allocator) and all elements will be moved;
	 * $(D_PARAM init) will be destroyed at the end.
	 *
	 * If $(D_PARAM init) is passed by reference, it will be copied.
	 *
	 * Params:
	 * 	init      = Source vector.
	 * 	allocator = Allocator.
	 */
	this(ref Vector init, shared Allocator allocator = defaultAllocator) @trusted
	{
		this(allocator);
		insertBack(init[]);
	}

	/// Ditto.
	this(Vector init, shared Allocator allocator = defaultAllocator) @trusted
	{
		if (allocator is init.allocator)
		{
			// Just steal all references and the allocator.
			this(init.allocator);
			vector = init.vector;
			length_ = init.length_;
			capacity_ = init.capacity_;

			// Reset the source vector, so it can't destroy the moved storage.
			init.length_ = init.capacity_ = 0;
			init.vector = null;
		}
		else
		{
			// Move each element.
			this(allocator);
			reserve(init.length);

			const T* end = vector + init.length;
			for (T* src = init.vector, dest = vector; dest != end; ++src, ++dest)
			{
				moveEmplace(*src, *dest);
			}
			length_ = init.length;
			// Destructor of init should destroy it here.
		}
	}

	///
	@nogc @safe unittest
	{
		auto v1 = Vector!int(IL(1, 2, 3));
		auto v2 = Vector!int(v1);
		assert(v1.vector !is v2.vector);
		assert(v1 == v2);

		auto v3 = Vector!int(Vector!int(IL(1, 2, 3)));
		assert(v1 == v3);
		assert(v3.length == 3);
		assert(v3.capacity == 3);
	}

	/**
	 * Creates a new $(D_PSYMBOL Vector).
	 *
	 * Params:
	 * 	len       = Initial length of the vector.
	 * 	allocator = Allocator.
	 */
	this(size_t len, shared Allocator allocator = defaultAllocator)
	{
		this(allocator);
		length = len;
	}

	/**
	 * Creates a new $(D_PSYMBOL Vector).
	 *
	 * Params:
	 * 	len       = Initial length of the vector.
	 * 	init      = Initial value to fill the vector with.
	 * 	allocator = Allocator.
	 */
	this(size_t len, T init, shared Allocator allocator = defaultAllocator) @trusted
	{
		this(allocator);

		vector = cast(T*) allocator.allocate(len * T.sizeof);
		if (len == 0)
		{
			return;
		}
		reserve(len);
		uninitializedFill(vector[0 .. len], init);
		length_ = len;
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

	///
	unittest
	{
		auto v = Vector!int(3, 5);

		assert(v.capacity == 3);
		assert(v.length == 3);
		assert(v[0] == 5 && v[1] == 5 && v[2] == 5);
	}

	@safe unittest
	{
		auto v1 = Vector!int(defaultAllocator);
	}

	/**
	 * Destroys this $(D_PSYMBOL Vector).
	 */
	~this()
	{
		length = 0;
		shrink(0);
	}

	/**
	 * Copies the vector.
	 */
	this(this) @trusted
	{
		auto buf = vector;
		immutable oldLen = length_;
		length_ = capacity_ = 0;
		insertBack(buf[0 .. oldLen]);
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
		auto v = Vector!int(IL(18, 20, 15));
		v.clear();
		assert(v.length == 0);
		assert(v.capacity == 3);
	}

	/**
	 * Returns: How many elements the vector can contain without reallocating.
	 */
	@property size_t capacity() const
	{
		return capacity_;
	}

	/**
	 * Returns: Vector length.
	 */
	@property size_t length() const
	{
		return length_;
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
	 * 	len = New length.
	 */
	@property void length(in size_t len) @trusted
	{
		if (len == length_)
		{
			return;
		}
		else if (len > length_)
		{
			reserve(len);
			initializeAll(vector[length_ .. len]);
		}
		else
		{
			static if (hasElaborateDestructor!T)
			{
				const T* end = vector + length_ - 1;
				for (T* e = vector + len; e != end; ++e)
				{
					destroy(*e);
				}
			}
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
		if (capacity_ >= size)
		{
			return;
		}
		bool overflow;
		immutable byteSize = mulu(size, T.sizeof, overflow);
		assert(!overflow);

		void[] buf = vector[0 .. capacity_];
		if (!allocator.expand(buf, byteSize))
		{
			buf = allocator.allocate(byteSize);
			if (buf is null)
			{
				onOutOfMemoryErrorNoGC();
			}
			scope (failure)
			{
				allocator.deallocate(buf);
			}
			const T* end = vector + length_;
			for (T* src = vector, dest = cast(T*) buf; src != end; ++src, ++dest)
			{
				moveEmplace(*src, *dest);
				static if (hasElaborateDestructor!T)
				{
					destroy(*src);
				}
			}
			allocator.deallocate(vector[0 .. capacity_]);
			vector = cast(T*) buf;
		}
		capacity_ = size;
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
		void[] buf = vector[0 .. capacity_];
		allocator.reallocate(buf, n * T.sizeof);
		vector = cast(T*) buf;
		capacity_ = n;
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
	@property bool empty() const
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
		immutable toRemove = min(howMany, length_);

		length = length_ - toRemove;

		return toRemove;
	}

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
	 * Remove all elements beloning to $(D_PARAM r).
	 *
	 * Params:
	 * 	r = Range originally obtained from this vector.
	 *
	 * Returns: Elements in $(D_PARAM r) after removing.
	 *
	 * Precondition: $(D_PARAM r) refers to a region of $(D_KEYWORD this).
	 */
	Range!T remove(Range!T r) @trusted
	in
	{
		assert(r.begin >= vector && r.end <= vector + length_);
	}
	body
	{
		const T* end = vector + length_;
		T* a = r.begin;
		for (T* b = r.end; b != end; ++a, ++b)
		{
			*a = *b;
		}
		for (; a != end; ++a)
		{
			static if (hasElaborateDestructor!T)
			{
				destroy(*a);
			}
			--length_;
		}
		return r;
	}

	///
	unittest
	{
		auto v = Vector!int(IL(5, 18, 17, 2, 4, 6, 1));

		v.remove(v[1..3]);
		assert(v == Vector!int(IL(5, 2, 4, 6, 1)));

		v.remove(v[4..4]);
		assert(v == Vector!int(IL(5, 2, 4, 6, 1)));

		v.remove(v[4..5]);
		assert(v == Vector!int(IL(5, 2, 4, 6)));

		v.remove(v[]);
		assert(v.empty);

		v.remove(v[]);
		assert(v.empty);
	}

	/**
	 * Inserts the $(D_PARAM el) into the vector.
	 *
	 * Params:
	 * 	R  = Parameter type (single values or a range).
	 * 	el = Values should be inserted.
	 *
	 * Returns: The number of elements inserted.
	 */
	size_t insertBack(R...)(auto ref R el) @trusted
		if (allSatisfy!(ApplyRight!(isImplicitlyConvertible, T), R))
	{
		reserve(length_ + el.length);
		foreach (i; el)
		{
			emplace(vector + length_, i);
			++length_;
		}
		return el.length;
	}

	/// Ditto.
	size_t insertBack(R)(R el) @trusted
		if (!isInfinite!R
		 && isInputRange!R
		 && isImplicitlyConvertible!(ElementType!R, T))
	{
		static if (hasLength!R)
		{
			reserve(length_ + el.length);
		}
		size_t retLength;
		foreach (e; el)
		{
			insertBack(e);
			++retLength;
		}
		return retLength;
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
	ref T opIndexAssign(ref T value, in size_t pos) @trusted
	in
	{
		assert(length_ > pos);
	}
	body
	{
		return *(vector + pos) = value;
	}

	/// Ditto.
	T opIndexAssign(T value, in size_t pos)
	{
		return opIndexAssign(value, pos);
	}

	/// Ditto.
	Range!T opIndexAssign(ref T value) @trusted
	{
		const T* end = vector + length_;
		for (T* v = vector; v != end; ++v)
		{
			*v = value;
		}
		return opIndex();
	}

	/// Ditto.
	Range!T opIndexAssign(T value)
	{
		return opIndexAssign(value);
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
	ref inout(T) opIndex(in size_t pos) inout @trusted
	in
	{
		assert(length_ > pos);
	}
	body
	{
		return *(vector + pos);
	}

	/**
	 * Returns: Random access range that iterates over elements of the vector, in
	 *          forward order.
	 */
	Range!T opIndex()
	{
		return typeof(return)(vector, vector + length_);
	}

	/// Ditto.
	Range!(const T) opIndex() const
	{
		return typeof(return)(vector, vector + length_);
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
	}

	/**
	 * Comparison for equality.
	 *
	 * Params:
	 * 	v = The vector to compare with.
	 *
	 * Returns: $(D_KEYWORD true) if the vectors are equal, $(D_KEYWORD false)
	 *          otherwise.
	 */
	bool opEquals()(auto ref typeof(this) v) @trusted
	{
		if (length_ != v.length_)
		{
			return false;
		}
		const T* end = vector + length_;
		for (T* v1 = vector, v2 = v.vector; v1 != end; ++v1, ++v2)
		{
			if (*v1 != *v2)
			{
				return false;
			}
		}
		return true;
	}

	/// Ditto.
	bool opEquals()(in auto ref typeof(this) v) const @trusted
	{
		if (length_ != v.length_)
		{
			return false;
		}
		const T* end = vector + length_;
		for (const(T)* v1 = vector, v2 = v.vector; v1 != end; ++v1, ++v2)
		{
			if (*v1 != *v2)
			{
				return false;
			}
		}
		return true;
	}

	/// Ditto.
	bool opEquals(Range!T v) @trusted
	{
		if (length_ != v.length)
		{
			return false;
		}
		const T* end = vector + length_;
		for (T* v1 = vector; v1 != end; ++v1)
		{
			if (*v1 != v.front)
			{
				return false;
			}
			v.popFront();
		}
		return true;
	}

	/**
	 * Comparison for equality.
	 *
	 * Params:
	 * 	R = Right hand side type.
	 * 	v = The vector to compare with.
	 *
	 * Returns: $(D_KEYWORD true) if the vectors are equal, $(D_KEYWORD false)
	 *          otherwise.
	 */
	bool opEquals(R)(Range!R v) const @trusted
		if (is(Unqual!R == T))
	{
		if (length_ != v.length)
		{
			return false;
		}
		const T* end = vector + length_;
		for (const(T)* v1 = vector; v1 != end; ++v1)
		{
			if (*v1 != v.front)
			{
				return false;
			}
			v.popFront();
		}
		return true;
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
	int opApply(scope int delegate(ref T) @nogc dg)
	{
		T* end = vector + length_ - 1;
		for (T* begin = vector; begin != end; ++begin)
		{
			int result = dg(*begin);
			if (result != 0)
			{
				return result;
			}
		}
		return 0;
	}

	/// Ditto.
	int opApply(scope int delegate(ref size_t i, ref T) @nogc dg)
	{
		for (size_t i = 0; i < length_; ++i)
		{
			assert(i < length_);
			int result = dg(i, *(vector + i));

			if (result != 0)
			{
				return result;
			}
		}
		return 0;
	}

	/// Ditto.
	int opApplyReverse(scope int delegate(ref T) dg)
	{
		for (T* end = vector + length_ - 1; vector != end; --end)
		{
			int result = dg(*end);
			if (result != 0)
			{
				return result;
			}
		}
		return 0;
	}

	/// Ditto.
	int opApplyReverse(scope int delegate(ref size_t i, ref T) dg)
	{
		if (length_ > 0)
		{
			size_t i = length_;
			do
			{
				--i;
				assert(i < length_);
				int result = dg(i, *(vector + i));

				if (result != 0)
				{
					return result;
				}
			}
			while (i > 0);
		}
		return 0;
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
	@property ref inout(T) front() inout @trusted
	in
	{
		assert(!empty);
	}
	body
	{
		return *vector;
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
	@property ref inout(T) back() inout @trusted
	in
	{
		assert(!empty);
	}
	body
	{
		return *(vector + length_ - 1);
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
	Range!T opSlice(in size_t i, in size_t j)
	in
	{
		assert(i <= j);
		assert(j <= length_);
	}
	body
	{
		return typeof(return)(vector + i, vector + j);
	}

	/// Ditto.
	Range!(const T) opSlice(in size_t i, in size_t j) const
	in
	{
		assert(i <= j);
		assert(j <= length_);
	}
	body
	{
		return typeof(return)(vector + i, vector + j);
	}

	///
	unittest
	{
		Vector!int v;
		auto r = v[];
		assert(r.length == 0);
		assert(r.empty);
	}

	///
	unittest
	{
		auto v = Vector!int(IL(1, 2, 3));
		auto r = v[];

		assert(r.front == 1);
		assert(r.back == 3);

		r.popFront();
		assert(r.front == 2);

		r.popBack();
		assert(r.back == 2);

		assert(r.length == 1);
	}

	///
	unittest
	{
		auto v = Vector!int(IL(1, 2, 3, 4));
		auto r = v[1 .. 4];
		assert(r.length == 3);
		assert(r[0] == 2);
		assert(r[1] == 3);
		assert(r[2] == 4);

		r = v[0 .. 0];
		assert(r.length == 0);

		r = v[4 .. 4];
		assert(r.length == 0);
	}

	/**
	 * Slicing assignment.
	 *
	 * Params:
	 * 	value = New value (single value or input range).
	 * 	i     = Slice start.
	 * 	j     = Slice end.
	 *
	 * Returns: Slice with the assigned part of the vector.
	 *
	 * Precondition: $(D_INLINECODE i <= j && j <= length);
	 *               The lenghts of the range and slice match.
	 */
	Range!T opSliceAssign(ref T value, in size_t i, in size_t j) @trusted
	in
	{
		assert(i <= j);
		assert(j <= length);
	}
	body
	{
		vector[i .. j].fill(value);
		return opSlice(i, j);
	}

	/// Ditto.
	Range!T opSliceAssign(T value, in size_t i, in size_t j)
	{
		return opSliceAssign(value, i, j);
	}

	/// Ditto.
	Range!T opSliceAssign(R)(R value, in size_t i, in size_t j)
		if (!isInfinite!R
		 && isInputRange!R
		 && isImplicitlyConvertible!(ElementType!R, T))
	in
	{
		assert(i <= j);
		assert(j <= length);
		assert(j - i == walkLength(value));
	}
	body
	{
		const T* end = vector + j;
		for (T* v = vector + i; v != end; ++v, value.popFront())
		{
			*v = value.front;
		}
		return opSlice(i, j);
	}

	/// Ditto.
	Range!T opSliceAssign(R)(R value, in size_t i, in size_t j)
		if (isStaticArray!R && isImplicitlyConvertible!(ElementType!R, T))
	{
		return opSliceAssign(value[], i, j);
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

	/**
	 * Returns an array used internally by the vector to store its owned elements.
	 * The length of the returned array may differ from the size of the allocated
	 * memory for the vector: the array contains only initialized elements, but
	 * not the reserved memory.
	 *
	 * Returns: The array with elements of this vector.
	 */
	inout(T[]) get() inout
	{
		return vector[0 .. length];
	}

	///
	unittest
	{
		auto v = Vector!int(IL(1, 2, 4));
		auto data = v.get();

		assert(data[0] == 1);
		assert(data[1] == 2);
		assert(data[2] == 4);
		assert(data.length == 3);

		data = v[1 .. 2].get();
		assert(data[0] == 2);
		assert(data.length == 1);
	}

	mixin DefaultAllocator;
}

///
unittest
{
	auto v = Vector!int(IL(5, 15, 8));

	assert(v.front == 5);
	assert(v[1] == 15);
	assert(v.back == 8);

	auto r = v[];
	r[0] = 7;
	assert(r.front == 7);
	assert(r.front == v.front);
}

@nogc unittest
{
	const v1 = Vector!int();
	const Vector!int v2;
	const v3 = Vector!int(IL(1, 5, 8));
	static assert(is(PointerTarget!(typeof(v3.vector)) == const(int)));
}

@nogc unittest
{
	// Test that const vectors return usable ranges.
	auto v = const Vector!int(IL(1, 2, 4));
	auto r1 = v[];

	assert(r1.back == 4);
	r1.popBack();
	assert(r1.back == 2);
	r1.popBack();
	assert(r1.back == 1);
	r1.popBack();
	assert(r1.length == 0);

	static assert(!is(typeof(r1[0] = 5)));
	static assert(!is(typeof(v[0] = 5)));

	const r2 = r1[];
	static assert(is(typeof(r2[])));
}

@nogc unittest
{
	Vector!int v1;
	const Vector!int v2;

	auto r1 = v1[];
	auto r2 = v1[];

	assert(r1.length == 0);
	assert(r2.empty);
	assert(r1 == r2);

	v1.insertBack(1, 2, 4);
	assert(v1[] == v1);
	assert(v2[] == v2);
	assert(v2[] != v1);
	assert(v1[] != v2);
	assert(v1[] == v1[]);
	assert(v2[] == v2[]);
}

@nogc unittest
{
	auto v1 = Vector!ConstEqualsStruct();
	auto v2 = Vector!ConstEqualsStruct();
	assert(v1 == v2);
	assert(v1[] == v2);
	assert(v1 == v2[]);
	assert(v1[] == v2[]);

	auto v3 = const Vector!ConstEqualsStruct();
	auto v4 = const Vector!ConstEqualsStruct();
	assert(v3 == v4);
	assert(v3[] == v4);
	assert(v3 == v4[]);
	assert(v3[] == v4[]);

	auto v7 = Vector!MutableEqualsStruct();
	auto v8 = Vector!MutableEqualsStruct();
	assert(v7 == v8);
	assert(v7[] == v8);
	assert(v7 == v8[]);
	assert(v7[] == v8[]);
}

@nogc unittest
{
	// Implicitly convertible works.
	auto v = Vector!int(IL(cast(short) 1, cast(short) 2));
}

@nogc unittest
{
	auto v = Vector!SWithDtor(); // Destructor can destroy empty vectors.
}
