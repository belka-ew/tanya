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
		private T payload;
	}
	else
	{
		private T* payload;
	}

	private uint counter;

	invariant
	{
		assert(counter == 0 || allocator !is null);
	}

	private shared Allocator allocator;

	/**
	 * Takes ownership over $(D_PARAM value), setting the counter to 1.
	 *
	 * Params:
	 * 	value     = Value whose ownership is taken over.
	 * 	allocator = Allocator used to destroy the $(D_PARAM value) and to
	 * 	            allocate/deallocate internal storage.

	 * Precondition: $(D_INLINECODE allocator !is null)
	 */
	this(T value, shared Allocator allocator = defaultAllocator)
	in
	{
		assert(allocator !is null);
	}
	body
	{
		this(allocator);
		static if (!isReference!T)
		{
			payload = cast(T*) allocator.allocate(stateSize!T).ptr;
			move(value, *payload);
			counter = 1;
		}
		else if (value !is null)
		{
			move(value, payload);
			counter = 1;
		}
	}

	/// Ditto.
	this(shared Allocator allocator) pure nothrow @safe @nogc
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
		if (isInitialized)
		{
			++counter;
		}
	}

	/**
	 * Decreases the reference counter by one.
	 *
	 * If the counter reaches 0, destroys the owned value.
	 */
	~this()
	{
		if (isInitialized && !--counter)
		{
			static if (isReference!T)
			{
				allocator.dispose(payload);
				payload = null;
			}
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
		static if (isReference!T)
		{
			counter == 1 ? allocator.dispose(payload) : --counter;
		}
		else if (!isInitialized)
		{
			payload = cast(T*) allocator.allocate(stateSize!T).ptr;
			counter = 1;
		}
		move(rhs, get);
		return get;
	}

	/// Ditto.
	ref typeof(this) opAssign(typeof(this) rhs)
	{
		swap(counter, rhs.counter);
		swap(get, rhs.get);
		swap(allocator, rhs.allocator);

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
	in
	{
		assert(payload !is null, "Attempted to access an uninitialized reference.");
	}
	body
	{
		return get;
	}

	ref inout(T) get() inout return pure nothrow @safe @nogc
	{
		static if (isReference!T)
		{
			return payload;
		}
		else
		{
			return *payload;
		}
	}

	/**
	 * Returns: The number of $(D_PSYMBOL RefCounted) instances that share
	 *          ownership over the same pointer (including $(D_KEYWORD this)).
	 *          If this $(D_PSYMBOL RefCounted) isn't initialized, returns 0.
	 */
	@property uint count() const pure nothrow @safe @nogc
	{
		return counter;
	}

	/**
	 * Returns: Whether tihs $(D_PSYMBOL RefCounted) is initialized.
	 */
	@property bool isInitialized() const pure nothrow @safe @nogc
	{
		return counter != 0;
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
			assert(!this.member.isInitialized);
			this.member = member;
			assert(this.member.isInitialized);
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
	rc = 8;
}

private unittest
{
	auto rc = RefCounted!int(5);

	static assert(is(typeof(rc.payload) == int*));
	static assert(is(typeof(cast(int) rc) == int));

	static assert(is(typeof(RefCounted!(int*).payload) == int*));

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
	static if (isReference!T)
	{
		return typeof(return)(allocator.make!T(args), allocator);
	}
	else
	{
		auto rc = typeof(return)(allocator);
		rc.counter = 1;
		rc.payload = allocator.make!T(args);
		return rc;
	}
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
	static assert(is(typeof(defaultAllocator.refCounted!bool(false))));
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
		assert(rc.isInitialized);
	}
}
