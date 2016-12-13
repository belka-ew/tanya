/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Copyright: Eugene Wissner 2016.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:belka@caraus.de, Eugene Wissner)
 */
module tanya.memory.types;

import core.exception;
import std.algorithm.comparison;
import std.algorithm.mutation;
import std.conv;
import std.traits;
import tanya.memory;
import tanya.traits;

/**
 * Reference-counted object containing a $(D_PARAM T) value as payload.
 * $(D_PSYMBOL RefCounted) keeps track of all references of an object, and
 * when the reference count goes down to zero, frees the underlying store.
 *
 * Params:
 * 	T = Type of the reference-counted value.
 */
struct RefCounted(T)
{
	static if (isReference!T)
	{
		private alias Payload = T;
	}
	else
	{
		private alias Payload = T*;
	}

	private class Storage
	{
		private Payload payload;
		private size_t counter = 1;

		private final size_t opUnary(string op)() pure nothrow @safe @nogc
			if (op == "--")
		in
		{
			assert(counter > 0);
		}
		body
		{
			return --counter;
		}

		private final size_t opUnary(string op)() pure nothrow @safe @nogc
			if (op == "++")
		out
		{
			assert(counter > 0);
		}
		body
		{
			return ++counter;
		}

		private final int opCmp(size_t counter) const pure nothrow @safe @nogc
		{
			if (this.counter > counter)
			{
				return 1;
			}
			else if (this.counter < counter)
			{
				return -1;
			}
			else
			{
				return 0;
			}
		}

		private final int opEquals(size_t counter) const pure nothrow @safe @nogc
		{
			return this.counter == counter;
		}
	}

	private final class RefCountedStorage : Storage
	{
		private shared Allocator allocator;

		this(shared Allocator allocator) pure nothrow @safe @nogc
		in
		{
			assert(allocator !is null);
		}
		body
		{
			this.allocator = allocator;
		}

		~this() nothrow @nogc
		{
			allocator.dispose(payload);
		}
	}

	private Storage storage;

	invariant
	{
		assert(storage is null || allocator !is null);
	}

	private shared Allocator allocator;

	/**
	 * Takes ownership over $(D_PARAM value), setting the counter to 1.
	 * $(D_PARAM value) may be a pointer, an object or a dynamic array.
	 *
	 * Params:
	 * 	value     = Value whose ownership is taken over.
	 * 	allocator = Allocator used to destroy the $(D_PARAM value) and to
	 * 	            allocate/deallocate internal storage.
	 *
	 * Precondition: $(D_INLINECODE allocator !is null)
	 */
	this(Payload value, shared Allocator allocator = defaultAllocator)
	{
		this(allocator);
		storage = allocator.make!RefCountedStorage(allocator);
		move(value, storage.payload);
	}

	/// Ditto.
	this(shared Allocator allocator)
	in
	{
		assert(allocator !is null);
	}
	body
	{
		this.allocator = allocator;
	}

	/**
	 * Increases the reference counter by one.
	 */
	this(this) pure nothrow @safe @nogc
	{
		if (storage !is null)
		{
			++storage;
		}
	}

	/**
	 * Decreases the reference counter by one.
	 *
	 * If the counter reaches 0, destroys the owned value.
	 */
	~this() @trusted
	{
		if (storage !is null && !--storage)
		{
			allocator.dispose(storage);
		}
	}

	/**
	 * Takes ownership over $(D_PARAM rhs). Initializes this
	 * $(D_PSYMBOL RefCounted) if needed.
	 *
	 * If it is the last reference of the previously owned object,
	 * it will be destroyed.
	 *
	 * If the allocator wasn't set before, $(D_PSYMBOL defaultAllocator) will
	 * be used. If you need a different allocator, create a new
	 * $(D_PSYMBOL RefCounted).
	 *
	 * Params:
	 * 	rhs = Object whose ownership is taken over.
	 */
	ref T opAssign(T rhs)
	{
		if (allocator is null)
		{
			allocator = defaultAllocator;
		}
		if (storage is null)
		{
			storage = allocator.make!RefCountedStorage(allocator);

			static if (!isReference!T)
			{
				storage.payload = cast(T*) allocator.allocate(stateSize!T).ptr;
			}

		}
		static if (isReference!T)
		{
			if (storage > 1)
			{
				--storage;
			}
			else
			{
				allocator.dispose(storage.payload);
			}
		}
		move(rhs, payload);
		return payload;
	}

	/// Ditto.
	ref typeof(this) opAssign(typeof(this) rhs)
	{
		swap(allocator, rhs.allocator);
		swap(storage, rhs.storage);
		return this;
	}

	/**
	 * Defines the casting to the original type.
	 *
	 * Params:
	 * 	T = Target type.
	 *
	 * Returns: Owned value.
	 */
	inout(T2) opCast(T2)() inout pure nothrow @safe @nogc
		if (is(T : T2))
	{
		return get;
	}

	/**
	 * Returns: Reference to the owned object.
	 */
	ref inout(T) get() inout pure nothrow @safe @nogc
	in
	{
		assert(storage !is null, "Attempted to access an uninitialized reference.");
	}
	body
	{
		static if (isReference!T)
		{
			return storage.payload;
		}
		else
		{
			return *storage.payload;
		}
	}

	/**
	 * Returns: The number of $(D_PSYMBOL RefCounted) instances that share
	 *          ownership over the same pointer (including $(D_KEYWORD this)).
	 *          If this $(D_PSYMBOL RefCounted) isn't initialized, returns 0.
	 */
	@property size_t count() const pure nothrow @safe @nogc
	{
		return storage is null ? 0 : storage.counter;
	}

	pragma(inline, true)
	private ref inout(T) payload() inout return pure nothrow @safe @nogc
	{
		static if (isReference!T)
		{
			return storage.payload;
		}
		else
		{
			return *storage.payload;
		}
	}

	alias get this;
}

version (unittest)
{
	class A
	{
		uint *destroyed;

		this(ref uint destroyed)
		{
			this.destroyed = &destroyed;
		}

		~this()
		{
			++(*destroyed);
		}
	}

	struct B
	{
		int prop;
		@disable this();
		this(int param1)
		{
			prop = param1;
		}
	}
}

///
unittest
{
	struct S
	{
		RefCounted!(ubyte[]) member;

		this(ref ubyte[] member)
		{
			assert(!this.member.count);
			this.member = member;
			assert(this.member.count);
		}
	}

	auto arr = defaultAllocator.makeArray!ubyte(2);
	{
		auto a = S(arr);
		assert(a.member.count == 1);

		void func(S a)
		{
			assert(a.member.count == 2);
		}
		func(a);

		assert(a.member.count == 1);
	}
	// arr is destroyed.
}

private unittest
{
	uint destroyed;
	auto a = defaultAllocator.make!A(destroyed);

	assert(destroyed == 0);
	{
		auto rc = RefCounted!A(a);
		assert(rc.count == 1);

		void func(RefCounted!A rc)
		{
			assert(rc.count == 2);
		}
		func(rc);

		assert(rc.count == 1);
	}
	assert(destroyed == 1);

	RefCounted!int rc;
	assert(rc.count == 0);
	rc = 8;
	assert(rc.count == 1);
}

private unittest
{
	auto val = defaultAllocator.make!int(5);
	auto rc = RefCounted!int(val);

	//static assert(is(typeof(rc.payload_) == int*));
	static assert(is(typeof(cast(int) rc) == int));

	//static assert(is(typeof(RefCounted!(int*).payload_) == int*));

	static assert(is(typeof(cast(A) (RefCounted!A())) == A));
	static assert(is(typeof(cast(Object) (RefCounted!A())) == Object));
	static assert(!is(typeof(cast(int) (RefCounted!A()))));

	static assert(is(RefCounted!B));
	static assert(is(RefCounted!A));
}

/**
 * Constructs a new object of type $(D_PARAM T) and wraps it in a
 * $(D_PSYMBOL RefCounted) using $(D_PARAM args) as the parameter list for
 * the constructor of $(D_PARAM T).
 *
 * Params:
 * 	T    = Type of the constructed object.
 * 	A    = Types of the arguments to the constructor of $(D_PARAM T).
 * 	args = Constructor arguments of $(D_PARAM T).
 * 
 * Returns: Newly created $(D_PSYMBOL RefCounted!T).
 */
RefCounted!T refCounted(T, A...)(shared Allocator allocator, auto ref A args)
	if (!is(T == interface) && !isAbstractClass!T)
{
	auto rc = typeof(return)(allocator);
	static if (isDynamicArray!T)
	{
		rc = allocator.makeArray!(ForeachType!T)(args);
	}
	else static if (isReference!T)
	{
		rc = allocator.make!T(args);
	}
	else
	{
		rc.storage = allocator.make!(RefCounted!T.RefCountedStorage)(allocator);
		rc.storage.payload = allocator.make!T(args);
	}
	return rc;
}

///
unittest
{
	auto rc = defaultAllocator.refCounted!int(5);
	assert(rc.count == 1);

	void func(RefCounted!int param)
	{
		if (param.count == 2)
		{
			func(param);
		}
		else
		{
			assert(param.count == 3);
		}
	}
	func(rc);

	assert(rc.count == 1);
}

private unittest
{
	struct E
	{
	}
	//static assert(is(typeof(defaultAllocator.refCounted!bool(false))));
	static assert(is(typeof(defaultAllocator.refCounted!B(5))));
	static assert(!is(typeof(defaultAllocator.refCounted!B())));

	static assert(is(typeof(defaultAllocator.refCounted!E())));
	static assert(!is(typeof(defaultAllocator.refCounted!E(5))));
	{
		auto rc = defaultAllocator.refCounted!B(3);
		assert(rc.get.prop == 3);
	}
	{
		auto rc = defaultAllocator.refCounted!E();
		assert(rc.count);
	}
}
