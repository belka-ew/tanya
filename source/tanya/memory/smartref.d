/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Smart pointers.
 *
 * A smart pointer is an object that wraps a raw pointer or a reference
 * (class, dynamic array) to manage its lifetime.
 *
 * This module provides two kinds of lifetime management strategies:
 * $(UL
 *  $(LI Reference counting)
 *  $(LI Unique ownership)
 * )
 *
 * Copyright: Eugene Wissner 2016-2017.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/memory/smartref.d,
 *                 tanya/memory/smartref.d)
 */
module tanya.memory.smartref;

import std.algorithm.comparison;
import tanya.algorithm.mutation;
import tanya.conv;
import tanya.exception;
import tanya.memory;
import tanya.meta.trait;
import tanya.range.primitive;

private template Payload(T)
{
    static if (isPolymorphicType!T || isArray!T)
    {
        alias Payload = T;
    }
    else
    {
        alias Payload = T*;
    }
}

private final class RefCountedStore(T)
{
    T payload;
    size_t counter = 1;

    size_t opUnary(string op)()
    if (op == "--" || op == "++")
    in
    {
        assert(this.counter > 0);
    }
    body
    {
        mixin("return " ~ op ~ "counter;");
    }

    int opCmp(const size_t counter)
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
}

private void separateDeleter(T)(RefCountedStore!T storage,
                                shared Allocator allocator)
{
    allocator.dispose(storage.payload);
    allocator.dispose(storage);
}

private void unifiedDeleter(T)(RefCountedStore!T storage,
                               shared Allocator allocator)
{
    auto ptr1 = finalize(storage);
    auto ptr2 = finalize(storage.payload);
    allocator.deallocate(ptr1.ptr[0 .. ptr1.length + ptr2.length]);
}

/**
 * Reference-counted object containing a $(D_PARAM T) value as payload.
 * $(D_PSYMBOL RefCounted) keeps track of all references of an object, and
 * when the reference count goes down to zero, frees the underlying store.
 *
 * Params:
 *  T = Type of the reference-counted value.
 */
struct RefCounted(T)
{
    private alias Storage = RefCountedStore!(Payload!T);

    private Storage storage;
    private void function(Storage storage,
                          shared Allocator allocator) @nogc deleter;

    invariant
    {
        assert(this.storage is null || this.allocator_ !is null);
        assert(this.storage is null || this.deleter !is null);
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
    this(Payload!T value, shared Allocator allocator = defaultAllocator)
    {
        this(allocator);
        this.storage = allocator.make!Storage();
        this.deleter = &separateDeleter!(Payload!T);

        this.storage.payload = value;
    }

    /// ditto
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
            ++this.storage;
        }
    }

    /**
     * Decreases the reference counter by one.
     *
     * If the counter reaches 0, destroys the owned object.
     */
    ~this()
    {
        if (this.storage !is null && !(this.storage > 0 && --this.storage))
        {
            deleter(this.storage, allocator);
        }
    }

    /**
     * Takes ownership over $(D_PARAM rhs). Initializes this
     * $(D_PSYMBOL RefCounted) if needed.
     *
     * If it is the last reference of the previously owned object,
     * it will be destroyed.
     *
     * To reset $(D_PSYMBOL RefCounted) assign $(D_KEYWORD null).
     *
     * If the allocator wasn't set before, $(D_PSYMBOL defaultAllocator) will
     * be used. If you need a different allocator, create a new
     * $(D_PSYMBOL RefCounted) and assign it.
     *
     * Params:
     *  rhs = New object.
     *
     * Returns: $(D_KEYWORD this).
     */
    ref typeof(this) opAssign(Payload!T rhs)
    {
        if (this.storage is null)
        {
            this.storage = allocator.make!Storage();
            this.deleter = &separateDeleter!(Payload!T);
        }
        else if (this.storage > 1)
        {
            --this.storage;
            this.storage = allocator.make!Storage();
            this.deleter = &separateDeleter!(Payload!T);
        }
        else
        {
            finalize(this.storage.payload);
            this.storage.payload = Payload!T.init;
        }
        this.storage.payload = rhs;
        return this;
    }

    /// ditto
    ref typeof(this) opAssign(typeof(null))
    {
        if (this.storage is null)
        {
            return this;
        }
        else if (this.storage > 1)
        {
            --this.storage;
        }
        else
        {
            deleter(this.storage, allocator);
        }
        this.storage = null;

        return this;
    }

    /// ditto
    ref typeof(this) opAssign(typeof(this) rhs)
    {
        swap(this.allocator_, rhs.allocator_);
        swap(this.storage, rhs.storage);
        swap(this.deleter, rhs.deleter);
        return this;
    }

    /**
     * Returns: Reference to the owned object.
     *
     * Precondition: $(D_INLINECODE cound > 0).
     */
    inout(Payload!T) get() inout
    in
    {
        assert(count > 0, "Attempted to access an uninitialized reference");
    }
    body
    {
        return this.storage.payload;
    }

    version (D_Ddoc)
    {
        /**
         * Dereferences the pointer. It is defined only for pointers, not for
         * reference types like classes, that can be accessed directly.
         *
         * Params:
         *  op = Operation. 
         *
         * Returns: Reference to the pointed value.
         */
        ref inout(T) opUnary(string op)() inout
        if (op == "*");
    }
    else static if (isPointer!(Payload!T))
    {
        ref inout(T) opUnary(string op)() inout
        if (op == "*")
        {
            return *this.storage.payload;
        }
    }

    /**
     * Returns: Whether this $(D_PSYMBOL RefCounted) already has an internal 
     *          storage.
     */
    @property bool isInitialized() const
    {
        return this.storage !is null;
    }

    /**
     * Returns: The number of $(D_PSYMBOL RefCounted) instances that share
     *          ownership over the same pointer (including $(D_KEYWORD this)).
     *          If this $(D_PSYMBOL RefCounted) isn't initialized, returns `0`.
     */
    @property size_t count() const
    {
        return this.storage is null ? 0 : this.storage.counter;
    }

    mixin DefaultAllocator;
    alias get this;
}

///
@nogc @system unittest
{
    auto rc = RefCounted!int(defaultAllocator.make!int(5), defaultAllocator);
    auto val = rc.get();

    *val = 8;
    assert(*rc.storage.payload == 8);

    val = null;
    assert(rc.storage.payload !is null);
    assert(*rc.storage.payload == 8);

    *rc = 9;
    assert(*rc.storage.payload == 9);
}

@nogc @system unittest
{
    auto rc = defaultAllocator.refCounted!int(5);
    rc = defaultAllocator.make!int(7);
    assert(*rc == 7);
}

@nogc @system unittest
{
    RefCounted!int rc;
    assert(!rc.isInitialized);
    rc = null;
    assert(!rc.isInitialized);
}

@nogc @system unittest
{
    auto rc = defaultAllocator.refCounted!int(5);

    void func(RefCounted!int param) @nogc
    {
        assert(param.count == 2);
        param = defaultAllocator.make!int(7);
        assert(param.count == 1);
        assert(*param == 7);
    }
    func(rc);
    assert(rc.count == 1);
    assert(*rc == 5);
}

@nogc @system unittest
{
    RefCounted!int rc;

    void func(RefCounted!int param) @nogc
    {
        assert(param.count == 0);
        param = defaultAllocator.make!int(7);
        assert(param.count == 1);
        assert(*param == 7);
    }
    func(rc);
    assert(rc.count == 0);
}

@nogc @system unittest
{
    RefCounted!int rc1, rc2;
    static assert(is(typeof(rc1 = rc2)));
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

@nogc @system unittest
{
    uint destroyed;
    auto a = defaultAllocator.make!A(destroyed);

    assert(destroyed == 0);
    {
        auto rc = RefCounted!A(a, defaultAllocator);
        assert(rc.count == 1);

        void func(RefCounted!A rc) @nogc @system
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

@nogc @system unittest
{
    auto rc = RefCounted!int(defaultAllocator);
    assert(!rc.isInitialized);
    assert(rc.allocator is defaultAllocator);
}

@nogc @system unittest
{
    auto rc = defaultAllocator.refCounted!int(5);
    assert(rc.count == 1);

    void func(RefCounted!int rc) @nogc
    {
        assert(rc.count == 2);
        rc = null;
        assert(!rc.isInitialized);
        assert(rc.count == 0);
    }

    assert(rc.count == 1);
    func(rc);
    assert(rc.count == 1);

    rc = null;
    assert(!rc.isInitialized);
    assert(rc.count == 0);
}

@nogc @system unittest
{
    auto rc = defaultAllocator.refCounted!int(5);
    assert(*rc == 5);

    void func(RefCounted!int rc) @nogc
    {
        assert(rc.count == 2);
        rc = defaultAllocator.refCounted!int(4);
        assert(*rc == 4);
        assert(rc.count == 1);
    }
    func(rc);
    assert(*rc == 5);
}

@nogc nothrow pure @safe unittest
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
 *  T         = Type of the constructed object.
 *  A         = Types of the arguments to the constructor of $(D_PARAM T).
 *  allocator = Allocator.
 *  args      = Constructor arguments of $(D_PARAM T).
 * 
 * Returns: Newly created $(D_PSYMBOL RefCounted!T).
 *
 * Precondition: $(D_INLINECODE allocator !is null)
 */
RefCounted!T refCounted(T, A...)(shared Allocator allocator, auto ref A args)
if (!is(T == interface) && !isAbstractClass!T
 && !isAssociativeArray!T && !isArray!T)
in
{
    assert(allocator !is null);
}
body
{
    auto rc = typeof(return)(allocator);

    const storageSize = alignedSize(stateSize!(RefCounted!T.Storage));
    const size = alignedSize(stateSize!T + storageSize);

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
    rc.storage.payload = emplace!T(mem[storageSize .. $], args);

    rc.deleter = &unifiedDeleter!(Payload!T);
    return rc;
}

/**
 * Constructs a new array with $(D_PARAM size) elements and wraps it in a
 * $(D_PSYMBOL RefCounted).
 *
 * Params:
 *  T         = Array type.
 *  size      = Array size.
 *  allocator = Allocator.
 *
 * Returns: Newly created $(D_PSYMBOL RefCounted!T).
 *
 * Precondition: $(D_INLINECODE allocator !is null
 *                           && size <= size_t.max / ElementType!T.sizeof)
 */
RefCounted!T refCounted(T)(shared Allocator allocator, const size_t size)
@trusted
if (isArray!T)
in
{
    assert(allocator !is null);
    assert(size <= size_t.max / ElementType!T.sizeof);
}
body
{
    return RefCounted!T(allocator.make!T(size), allocator);
}

///
@nogc @system unittest
{
    auto rc = defaultAllocator.refCounted!int(5);
    assert(rc.count == 1);

    void func(RefCounted!int param) @nogc
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

@nogc @system unittest
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
        assert(rc.get().prop == 3);
    }
    {
        auto rc = defaultAllocator.refCounted!E();
        assert(rc.count);
    }
}

@nogc @system unittest
{
    auto rc = defaultAllocator.refCounted!(int[])(5);
    assert(rc.length == 5);
}

@nogc @system unittest
{
    auto p1 = defaultAllocator.make!int(5);
    auto p2 = p1;
    auto rc = RefCounted!int(p1, defaultAllocator);
    assert(rc.get() is p2);
}

@nogc @system unittest
{
    static bool destroyed;

    static struct F
    {
        ~this() @nogc nothrow @safe
        {
            destroyed = true;
        }
    }
    {
        auto rc = defaultAllocator.refCounted!F();
    }
    assert(destroyed);
}

/**
 * $(D_PSYMBOL Unique) stores an object that gets destroyed at the end of its scope.
 *
 * Params:
 *  T = Value type.
 */
struct Unique(T)
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
    this(Payload!T value, shared Allocator allocator = defaultAllocator)
    {
        this(allocator);
        this.payload = value;
    }

    /// ditto
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
     * $(D_PSYMBOL Unique) is noncopyable.
     */
    @disable this(this);

    /**
     * Destroys the owned object.
     */
    ~this()
    {
        allocator.dispose(this.payload);
    }

    /**
     * Initialized this $(D_PARAM Unique) and takes ownership over
     * $(D_PARAM rhs).
     *
     * To reset $(D_PSYMBOL Unique) assign $(D_KEYWORD null).
     *
     * If the allocator wasn't set before, $(D_PSYMBOL defaultAllocator) will
     * be used. If you need a different allocator, create a new
     * $(D_PSYMBOL Unique) and assign it.
     *
     * Params:
     *  rhs = New object.
     *
     * Returns: $(D_KEYWORD this).
     */
    ref typeof(this) opAssign(Payload!T rhs)
    {
        allocator.dispose(this.payload);
        this.payload = rhs;
        return this;
    }

    /// ditto
    ref typeof(this) opAssign(typeof(null))
    {
        allocator.dispose(this.payload);
        return this;
    }

    /// ditto
    ref typeof(this) opAssign(typeof(this) rhs)
    {
        swap(this.allocator_, rhs.allocator_);
        swap(this.payload, rhs.payload);

        return this;
    }

    ///
    @nogc nothrow pure @system unittest
    {
        auto rc = defaultAllocator.unique!int(5);
        rc = defaultAllocator.make!int(7);
        assert(*rc == 7);
    }

    /**
     * Returns: Reference to the owned object.
     */
    inout(Payload!T) get() inout
    {
        return this.payload;
    }

    version (D_Ddoc)
    {
        /**
         * Dereferences the pointer. It is defined only for pointers, not for
         * reference types like classes, that can be accessed directly.
         *
         * Params:
         *  op = Operation. 
         *
         * Returns: Reference to the pointed value.
         */
        ref inout(T) opUnary(string op)() inout
        if (op == "*");
    }
    else static if (isPointer!(Payload!T))
    {
        ref inout(T) opUnary(string op)() inout
        if (op == "*")
        {
            return *this.payload;
        }
    }

    /**
     * Returns: Whether this $(D_PSYMBOL Unique) holds some value.
     */
    @property bool isInitialized() const
    {
        return this.payload !is null;
    }

    ///
    @nogc nothrow pure @system unittest
    {
        Unique!int u;
        assert(!u.isInitialized);
    }

    /**
     * Sets the internal pointer to $(D_KEYWORD). The allocator isn't changed.
     *
     * Returns: Reference to the owned object.
     */
    Payload!T release()
    {
        auto payload = this.payload;
        this.payload = null;
        return payload;
    }

    ///
    @nogc nothrow pure @system unittest
    {
        auto u = defaultAllocator.unique!int(5);
        assert(u.isInitialized);

        auto i = u.release();
        assert(*i == 5);
        assert(!u.isInitialized);
    }

    mixin DefaultAllocator;
    alias get this;
}

///
@nogc nothrow pure @system unittest
{
    auto p = defaultAllocator.make!int(5);
    auto s = Unique!int(p, defaultAllocator);
    assert(*s == 5);
}

///
@nogc nothrow @system unittest
{
    static bool destroyed;

    static struct F
    {
        ~this() @nogc nothrow @safe
        {
            destroyed = true;
        }
    }
    {
        auto s = Unique!F(defaultAllocator.make!F(), defaultAllocator);
    }
    assert(destroyed);
}

/**
 * Constructs a new object of type $(D_PARAM T) and wraps it in a
 * $(D_PSYMBOL Unique) using $(D_PARAM args) as the parameter list for
 * the constructor of $(D_PARAM T).
 *
 * Params:
 *  T         = Type of the constructed object.
 *  A         = Types of the arguments to the constructor of $(D_PARAM T).
 *  allocator = Allocator.
 *  args      = Constructor arguments of $(D_PARAM T).
 * 
 * Returns: Newly created $(D_PSYMBOL Unique!T).
 *
 * Precondition: $(D_INLINECODE allocator !is null)
 */
Unique!T unique(T, A...)(shared Allocator allocator, auto ref A args)
if (!is(T == interface) && !isAbstractClass!T
 && !isAssociativeArray!T && !isArray!T)
in
{
    assert(allocator !is null);
}
body
{
    auto payload = allocator.make!(T, A)(args);
    return Unique!T(payload, allocator);
}

/**
 * Constructs a new array with $(D_PARAM size) elements and wraps it in a
 * $(D_PSYMBOL Unique).
 *
 * Params:
 *  T         = Array type.
 *  size      = Array size.
 *  allocator = Allocator.
 *
 * Returns: Newly created $(D_PSYMBOL Unique!T).
 *
 * Precondition: $(D_INLINECODE allocator !is null
 *                           && size <= size_t.max / ElementType!T.sizeof)
 */
Unique!T unique(T)(shared Allocator allocator, const size_t size)
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
    return Unique!T(payload, allocator);
}

@nogc nothrow pure @safe unittest
{
    static assert(is(typeof(defaultAllocator.unique!B(5))));
    static assert(is(typeof(defaultAllocator.unique!(int[])(5))));
}

@nogc nothrow pure @system unittest
{
    auto s = defaultAllocator.unique!int(5);
    assert(*s == 5);

    s = null;
    assert(s is null);
}

@nogc nothrow pure @system unittest
{
    auto s = defaultAllocator.unique!int(5);
    assert(*s == 5);

    s = defaultAllocator.unique!int(4);
    assert(*s == 4);
}

@nogc nothrow pure @system unittest
{
    auto p1 = defaultAllocator.make!int(5);
    auto p2 = p1;

    auto rc = Unique!int(p1, defaultAllocator);
    assert(rc.get() is p2);
}

@nogc nothrow pure @system unittest
{
    auto rc = Unique!int(defaultAllocator);
    assert(rc.allocator is defaultAllocator);
}
