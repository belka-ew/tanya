/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Smart pointers.
 *
 * $(RED Deprecated. Use $(D_PSYMBOL tanya.memory.smartref) instead.
 * This module will be removed in 0.8.0.)
 *
 * Copyright: Eugene Wissner 2016-2017.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 */
deprecated("Use tanya.memory.smartref instead")
module tanya.memory.types;

import core.exception;
import std.algorithm.comparison;
import std.algorithm.mutation;
import std.conv;
import std.range;
import std.traits;
import tanya.memory;
public import tanya.memory.smartref : RefCounted, Payload;

version (unittest)
{
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

/**
 * $(D_PSYMBOL Scoped) stores an object that gets destroyed at the end of its scope.
 *
 * Params:
 *  T = Value type.
 */
struct Scoped(T)
{
    private Payload!T payload;

    invariant
    {
        assert(payload is null || allocator_ !is null);
    }

    /**
     * Takes ownership over $(D_PARAM value), setting the counter to 1.
     * $(D_PARAM value) may be a pointer, an object or a dynamic array.
     *
     * Params:
     *  value     = Value whose ownership is taken over.
     *  allocator = Allocator used to destroy the $(D_PARAM value) and to
     *              allocate/deallocate internal storage.
     *
     * Precondition: $(D_INLINECODE allocator !is null)
     */
    this()(auto ref Payload!T value,
           shared Allocator allocator = defaultAllocator)
    {
        this(allocator);

        move(value, this.payload);
        static if (__traits(isRef, value))
        {
            value = null;
        }
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
     * $(D_PSYMBOL Scoped) is noncopyable.
     */
    @disable this(this);

    /**
     * Destroys the owned object.
     */
    ~this()
    {
        if (this.payload !is null)
        {
            allocator.dispose(this.payload);
        }
    }

    /**
     * Initialized this $(D_PARAM Scoped) and takes ownership over
     * $(D_PARAM rhs).
     *
     * To reset $(D_PSYMBOL Scoped) assign $(D_KEYWORD null).
     *
     * If the allocator wasn't set before, $(D_PSYMBOL defaultAllocator) will
     * be used. If you need a different allocator, create a new
     * $(D_PSYMBOL Scoped) and assign it.
     *
     * Params:
     *  rhs = New object.
     *
     * Returns: $(D_KEYWORD this).
     */
    ref typeof(this) opAssign()(auto ref Payload!T rhs)
    {
        allocator.dispose(this.payload);
        move(rhs, this.payload);

        return this;
    }

    /// Ditto.
    ref typeof(this) opAssign(typeof(null))
    {
        allocator.dispose(this.payload);
        return this;
    }

    /// Ditto.
    ref typeof(this) opAssign(typeof(this) rhs)
    {
        swap(this.allocator_, rhs.allocator_);
        swap(this.payload, rhs.payload);

        return this;
    }

    /**
     * Returns: Reference to the owned object.
     */
    Payload!T get() pure nothrow @safe @nogc
    {
        return payload;
    }

    version (D_Ddoc)
    {
        /**
         * Params:
         *  op = Operation. 
         *
         * Dereferences the pointer. It is defined only for pointers, not for
         * reference types like classes, that can be accessed directly.
         *
         * Returns: Reference to the pointed value.
         */
        ref T opUnary(string op)()
            if (op == "*");
    }
    else static if (isPointer!(Payload!T))
    {
        ref T opUnary(string op)()
            if (op == "*")
        {
            return *payload;
        }
    }

    mixin DefaultAllocator;
    alias get this;
}

///
@nogc unittest
{
    auto p = defaultAllocator.make!int(5);
    auto s = Scoped!int(p, defaultAllocator);
    assert(p is null);
    assert(*s == 5);
}

///
@nogc unittest
{
    static bool destroyed = false;

    struct F
    {
        ~this() @nogc
        {
            destroyed = true;
        }
    }
    {
        auto s = Scoped!F(defaultAllocator.make!F(), defaultAllocator);
    }
    assert(destroyed);
}

/**
 * Constructs a new object of type $(D_PARAM T) and wraps it in a
 * $(D_PSYMBOL Scoped) using $(D_PARAM args) as the parameter list for
 * the constructor of $(D_PARAM T).
 *
 * Params:
 *  T         = Type of the constructed object.
 *  A         = Types of the arguments to the constructor of $(D_PARAM T).
 *  allocator = Allocator.
 *  args      = Constructor arguments of $(D_PARAM T).
 * 
 * Returns: Newly created $(D_PSYMBOL Scoped!T).
 *
 * Precondition: $(D_INLINECODE allocator !is null)
 */
Scoped!T scoped(T, A...)(shared Allocator allocator, auto ref A args)
    if (!is(T == interface) && !isAbstractClass!T
     && !isAssociativeArray!T && !isArray!T)
in
{
    assert(allocator !is null);
}
body
{
    auto payload = allocator.make!(T, shared Allocator, A)(args);
    return Scoped!T(payload, allocator);
}

/**
 * Constructs a new array with $(D_PARAM size) elements and wraps it in a
 * $(D_PSYMBOL Scoped).
 *
 * Params:
 *  T         = Array type.
 *  size      = Array size.
 *  allocator = Allocator.
 *
 * Returns: Newly created $(D_PSYMBOL Scoped!T).
 *
 * Precondition: $(D_INLINECODE allocator !is null
 *                           && size <= size_t.max / ElementType!T.sizeof)
 */
Scoped!T scoped(T)(shared Allocator allocator, const size_t size)
@trusted
    if (isArray!T)
in
{
    assert(allocator !is null);
    assert(size <= size_t.max / ElementType!T.sizeof);
}
body
{
    auto payload = allocator.resize!(ElementType!T)(null, size);
    return Scoped!T(payload, allocator);
}

private unittest
{
    static assert(is(typeof(defaultAllocator.scoped!B(5))));
    static assert(is(typeof(defaultAllocator.scoped!(int[])(5))));
}

private unittest
{
    auto s = defaultAllocator.scoped!int(5);
    assert(*s == 5);

    s = null;
    assert(s is null);
}

private unittest
{
    auto s = defaultAllocator.scoped!int(5);
    assert(*s == 5);

    s = defaultAllocator.scoped!int(4);
    assert(*s == 4);
}

private @nogc unittest
{
    auto p1 = defaultAllocator.make!int(5);
    auto p2 = p1;
    auto rc = Scoped!int(p1, defaultAllocator);

    assert(p1 is null);
    assert(rc.get() is p2);
}

private @nogc unittest
{
    auto rc = Scoped!int(defaultAllocator);
    assert(rc.allocator is defaultAllocator);
}
