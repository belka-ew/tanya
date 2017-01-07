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
	static if (is(T == class) || is(T == interface))
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
			if (op == "--" || op == "++")
		in
		{
			assert(counter > 0);
		}
		body
		{
			mixin("return " ~ op ~ "counter;");
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
		assert(storage is null || allocator_ !is null);
	}

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
		this.allocator_ = allocator;
	}

	/**
	 * Increases the reference counter by one.
	 */
	this(this)
	{
		if (count != 0)
		{
			++storage;
		}
	}

	/**
	 * Decreases the reference counter by one.
	 *
	 * If the counter reaches 0, destroys the owned object.
	 */
	~this()
	{
		if (storage !is null && !(storage.counter && --storage))
		{
			allocator_.dispose(storage);
		}
	}

	/**
	 * Takes ownership over $(D_PARAM rhs). Initializes this
	 * $(D_PSYMBOL RefCounted) if needed.
	 *
	 * If it is the last reference of the previously owned object,
	 * it will be destroyed.
	 *
	 * To reset the $(D_PSYMBOL RefCounted) assign $(D_KEYWORD null).
	 *
	 * If the allocator wasn't set before, $(D_PSYMBOL defaultAllocator) will
	 * be used. If you need a different allocator, create a new
	 * $(D_PSYMBOL RefCounted) and assign it.
	 *
	 * Params:
	 * 	rhs = $(D_KEYWORD this).
	 */
	ref typeof(this) opAssign(Payload rhs)
	{
		if (storage is null)
		{
			storage = allocator.make!RefCountedStorage(allocator);
		}
		else if (storage > 1)
		{
			--storage;
			storage = allocator.make!RefCountedStorage(allocator);
		}
		else if (cast(RefCountedStorage) storage is null)
		{
			// Created with refCounted. Always destroyed togethter with the pointer.
			assert(storage.counter != 0);
			allocator.dispose(storage);
			storage = allocator.make!RefCountedStorage(allocator);
		}
		else
		{
			allocator.dispose(storage.payload);
		}
		move(rhs, storage.payload);
		return this;
	}

	/// Ditto.
	ref typeof(this) opAssign(typeof(null))
	{
		if (storage is null)
		{
			return this;
		}
		else if (storage > 1)
		{
			--storage;
			storage = null;
		}
		else if (cast(RefCountedStorage) storage is null)
		{
			// Created with refCounted. Always destroyed togethter with the pointer.
			assert(storage.counter != 0);
			allocator.dispose(storage);
			return this;
		}
		else
		{
			allocator.dispose(storage.payload);
		}
		return this;
	}

	/// Ditto.
	ref typeof(this) opAssign(typeof(this) rhs)
	{
		swap(allocator_, rhs.allocator_);
		swap(storage, rhs.storage);
		return this;
	}

	/**
	 * Returns: Reference to the owned object.
	 */
	inout(Payload) get() inout pure nothrow @safe @nogc
	in
	{
		assert(count > 0, "Attempted to access an uninitialized reference.");
	}
	body
	{
		return storage.payload;
	}

	static if (isPointer!Payload)
	{
		/**
		 * Params:
		 * 	op = Operation. 
		 *
		 * Dereferences the pointer. It is defined only for pointers, not for
		 * reference types like classes, that can be accessed directly.
		 *
		 * Returns: Reference to the pointed value.
		 */
		ref T opUnary(string op)()
			if (op == "*")
		{
			return *storage.payload;
		}
	}

	/**
	 * Returns: Whether this $(D_PSYMBOL RefCounted) already has an internal 
	 *          storage.
	 */
	@property bool isInitialized() const
	{
		return storage !is null;
	}

	/**
	 * Returns: The number of $(D_PSYMBOL RefCounted) instances that share
	 *          ownership over the same pointer (including $(D_KEYWORD this)).
	 *          If this $(D_PSYMBOL RefCounted) isn't initialized, returns `0`.
	 */
	@property size_t count() const
	{
		return storage is null ? 0 : storage.counter;
	}

	mixin DefaultAllocator;
	alias get this;
}

///
unittest
{
	auto rc = RefCounted!int(defaultAllocator.make!int(5), defaultAllocator);
	auto val = rc.get;

	*val = 8;
	assert(*rc.storage.payload == 8);

	val = null;
	assert(rc.storage.payload !is null);
	assert(*rc.storage.payload == 8);

	*rc = 9;
	assert(*rc.storage.payload == 9);
}

version (unittest)
{
	private class A
	{
		uint *destroyed;

		this(ref uint destroyed) @nogc
		{
			this.destroyed = &destroyed;
		}

		~this() @nogc
		{
			++(*destroyed);
		}
	}

	private struct B
	{
		int prop;
		@disable this();
		this(int param1) @nogc
		{
			prop = param1;
		}
	}
}

private unittest
{
	uint destroyed;
	auto a = defaultAllocator.make!A(destroyed);

	assert(destroyed == 0);
	{
		auto rc = RefCounted!A(a, defaultAllocator);
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
	rc = defaultAllocator.make!int(8);
	assert(rc.count == 1);
}

private unittest
{
	static assert(is(typeof(RefCounted!int.storage.payload) == int*));
	static assert(is(typeof(RefCounted!A.storage.payload) == A));

	static assert(is(RefCounted!B));
	static assert(is(RefCounted!A));
}

/**
 * Constructs a new object of type $(D_PARAM T) and wraps it in a
 * $(D_PSYMBOL RefCounted) using $(D_PARAM args) as the parameter list for
 * the constructor of $(D_PARAM T).
 *
 * This function is more efficient than the using of $(D_PSYMBOL RefCounted)
 * directly, since it allocates only ones (the internal storage and the
 * object).
 *
 * Params:
 * 	T         = Type of the constructed object.
 * 	A         = Types of the arguments to the constructor of $(D_PARAM T).
 * 	allocator = Allocator.
 * 	args      = Constructor arguments of $(D_PARAM T).
 * 
 * Returns: Newly created $(D_PSYMBOL RefCounted!T).
 */
RefCounted!T refCounted(T, A...)(shared Allocator allocator, auto ref A args)
	if (!is(T == interface) && !isAbstractClass!T
         && !isArray!T && !isAssociativeArray!T)
{
	auto rc = typeof(return)(allocator);

	immutable storageSize = alignedSize(stateSize!(RefCounted!T.Storage));
	immutable size = alignedSize(stateSize!T + storageSize);

	auto mem = (() @trusted => allocator.allocate(size))();
	if (mem is null)
	{
		onOutOfMemoryError();
	}
	scope (failure)
	{
		() @trusted { allocator.deallocate(mem); }();
	}
	rc.storage = emplace!(RefCounted!T.Storage)(mem[0 .. storageSize]);

	static if (is(T == class))
	{
		rc.storage.payload = emplace!T(mem[storageSize .. $], args);
	}
	else
	{
		auto ptr = (() @trusted => (cast(T*) mem[storageSize .. $].ptr))();
		rc.storage.payload = emplace!T(ptr, args);
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

private @nogc unittest
{
	struct E
	{
	}
	auto b = defaultAllocator.refCounted!B(15);
	static assert(is(typeof(b.storage.payload) == B*));
	static assert(is(typeof(b.prop) == int));
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
