/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Dynamic memory management.
 *
 * Copyright: Eugene Wissner 2016-2018.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/memory/package.d,
 *                 tanya/memory/package.d)
 */
module tanya.memory;

import std.algorithm.mutation;
import tanya.conv;
import tanya.exception;
public import tanya.memory.allocator;
import tanya.meta.trait;
import tanya.range.primitive;

/**
 * The mixin generates common methods for classes and structs using
 * allocators. It provides a protected member, constructor and a read-only property,
 * that checks if an allocator was already set and sets it to the default
 * one, if not (useful for structs which don't have a default constructor).
 */
mixin template DefaultAllocator()
{
    /// Allocator.
    protected shared Allocator allocator_;

    /**
     * Params:
     *  allocator = The allocator should be used.
     *
     * Precondition: $(D_INLINECODE allocator_ !is null)
     */
    this(shared Allocator allocator) @nogc nothrow pure @safe
    in
    {
        assert(allocator !is null);
    }
    do
    {
        this.allocator_ = allocator;
    }

    /**
     * This property checks if the allocator was set in the constructor
     * and sets it to the default one, if not.
     *
     * Returns: Used allocator.
     *
     * Postcondition: $(D_INLINECODE allocator !is null)
     */
    @property shared(Allocator) allocator() @nogc nothrow pure @safe
    out (allocator)
    {
        assert(allocator !is null);
    }
    do
    {
        if (allocator_ is null)
        {
            allocator_ = defaultAllocator;
        }
        return allocator_;
    }

    /// ditto
    @property shared(Allocator) allocator() const @nogc nothrow pure @trusted
    out (allocator)
    {
        assert(allocator !is null);
    }
    do
    {
        if (allocator_ is null)
        {
            return defaultAllocator;
        }
        return cast(shared Allocator) allocator_;
    }
}

// From druntime
extern (C)
private void _d_monitordelete(Object h, bool det) @nogc nothrow pure;

shared Allocator allocator;

private shared(Allocator) getAllocatorInstance() @nogc nothrow
{
    if (allocator is null)
    {
        version (TanyaNative)
        {
            import tanya.memory.mmappool;
            defaultAllocator = MmapPool.instance;
        }
        else
        {
            import tanya.memory.mallocator;
            defaultAllocator = Mallocator.instance;
        }
    }
    return allocator;
}

/**
 * Returns: Default allocator.
 *
 * Postcondition: $(D_INLINECODE allocator !is null).
 */
@property shared(Allocator) defaultAllocator() @nogc nothrow pure @trusted
out (allocator)
{
    assert(allocator !is null);
}
do
{
    return (cast(GetPureInstance!Allocator) &getAllocatorInstance)();
}

/**
 * Sets the default allocator.
 *
 * Params:
 *  allocator = $(D_PSYMBOL Allocator) instance.
 *
 * Precondition: $(D_INLINECODE allocator !is null).
 */
@property void defaultAllocator(shared(Allocator) allocator) @nogc nothrow @safe
in
{
    assert(allocator !is null);
}
do
{
    .allocator = allocator;
}

/**
 * Returns the size in bytes of the state that needs to be allocated to hold an
 * object of type $(D_PARAM T).
 *
 * There is a difference between the `.sizeof`-property and
 * $(D_PSYMBOL stateSize) if $(D_PARAM T) is a class or an interface.
 * `T.sizeof` is constant on the given architecture then and is the same as
 * `size_t.sizeof` and `ptrdiff_t.sizeof`. This is because classes and
 * interfaces are reference types and `.sizeof` returns the size of the
 * reference which is the same as the size of a pointer. $(D_PSYMBOL stateSize)
 * returns the size of the instance itself.
 *
 * The size of a dynamic array is `size_t.sizeof * 2` since a dynamic array
 * stores its length and a data pointer. The size of the static arrays is
 * calculated differently since they are value types. It is the array length
 * multiplied by the element size.
 *
 * `stateSize!void` is `1` since $(D_KEYWORD void) is mostly used as a synonym
 * for $(D_KEYWORD byte)/$(D_KEYWORD ubyte) in `void*`.
 *
 * Params:
 *  T = Object type.
 *
 * Returns: Size of an instance of type $(D_PARAM T).
 */
template stateSize(T)
{
    static if (isPolymorphicType!T)
    {
        enum size_t stateSize = __traits(classInstanceSize, T);
    }
    else
    {
        enum size_t stateSize = T.sizeof;
    }
}

///
@nogc nothrow pure @safe unittest
{
    static assert(stateSize!int == 4);
    static assert(stateSize!bool == 1);
    static assert(stateSize!(int[]) == (size_t.sizeof * 2));
    static assert(stateSize!(short[3]) == 6);

    static struct Empty
    {
    }
    static assert(stateSize!Empty == 1);
    static assert(stateSize!void == 1);
}

/**
 * Params:
 *  size      = Raw size.
 *  alignment = Alignment.
 *
 * Returns: Aligned size.
 */
size_t alignedSize(const size_t size, const size_t alignment = 8)
pure nothrow @safe @nogc
{
    return (size - 1) / alignment * alignment + alignment;
}

/*
 * Internal function used to create, resize or destroy a dynamic array. It
 * may throw $(D_PSYMBOL OutOfMemoryError). The new
 * allocated part of the array isn't initialized. This function can be trusted
 * only in the data structures that can ensure that the array is
 * allocated/rellocated/deallocated with the same allocator.
 *
 * Params:
 *  T         = Element type of the array being created.
 *  allocator = The allocator used for getting memory.
 *  array     = A reference to the array being changed.
 *  length    = New array length.
 *
 * Returns: $(D_PARAM array).
 */
package(tanya) T[] resize(T)(shared Allocator allocator,
                             auto ref T[] array,
                             const size_t length) @trusted
{
    if (length == 0)
    {
        if (allocator.deallocate(array))
        {
            return null;
        }
        else
        {
            onOutOfMemoryError();
        }
    }

    void[] buf = array;
    if (!allocator.reallocate(buf, length * T.sizeof))
    {
        onOutOfMemoryError();
    }
    // Casting from void[] is unsafe, but we know we cast to the original type.
    array = cast(T[]) buf;

    return array;
}

@nogc nothrow pure @safe unittest
{
    int[] p;

    p = defaultAllocator.resize(p, 20);
    assert(p.length == 20);

    p = defaultAllocator.resize(p, 30);
    assert(p.length == 30);

    p = defaultAllocator.resize(p, 10);
    assert(p.length == 10);

    p = defaultAllocator.resize(p, 0);
    assert(p is null);
}

/*
 * Destroys the object.
 * Returns the memory should be freed.
 */
package(tanya) void[] finalize(T)(ref T* p)
{
    if (p is null)
    {
        return null;
    }
    static if (hasElaborateDestructor!T)
    {
        destroy(*p);
    }
    return (cast(void*) p)[0 .. T.sizeof];
}

package(tanya) void[] finalize(T)(ref T p)
if (isPolymorphicType!T)
{
    if (p is null)
    {
        return null;
    }
    static if (is(T == interface))
    {
        version(Windows)
        {
            import core.sys.windows.unknwn : IUnknown;
            static assert(!is(T : IUnknown), "COM interfaces can't be destroyed in "
                                           ~ __PRETTY_FUNCTION__);
        }
        auto ob = cast(Object) p;
    }
    else
    {
        alias ob = p;
    }
    auto ptr = cast(void*) ob;
    auto support = ptr[0 .. typeid(ob).initializer.length];

    auto ppv = cast(void**) ptr;
    if (!*ppv)
    {
        return null;
    }
    auto pc = cast(ClassInfo*) *ppv;
    scope (exit)
    {
        *ppv = null;
    }

    auto c = *pc;
    do
    {
        // Assume the destructor is @nogc. Leave it nothrow since the destructor
        // shouldn't throw and if it does, it is an error anyway.
        if (c.destructor)
        {
            alias DtorType = void function(Object) pure nothrow @safe @nogc;
            (cast(DtorType) c.destructor)(ob);
        }
    }
    while ((c = c.base) !is null);

    if (ppv[1]) // if monitor is not null
    {
        _d_monitordelete(cast(Object) ptr, true);
    }
    return support;
}

package(tanya) void[] finalize(T)(ref T[] p)
{
    static if (hasElaborateDestructor!(typeof(p[0])))
    {
        foreach (ref e; p)
        {
            destroy(e);
        }
    }
    return p;
}

/**
 * Destroys and deallocates $(D_PARAM p) of type $(D_PARAM T).
 * It is assumed the respective entities had been allocated with the same
 * allocator.
 *
 * Params:
 *  T         = Type of $(D_PARAM p).
 *  allocator = Allocator the $(D_PARAM p) was allocated with.
 *  p         = Object or array to be destroyed.
 */
void dispose(T)(shared Allocator allocator, auto ref T p)
{
    () @trusted { allocator.deallocate(finalize(p)); }();
    p = null;
}

@nogc nothrow pure @system unittest
{
    static struct S
    {
        ~this() @nogc nothrow pure @safe
        {
        }
    }
    auto p = cast(S[]) defaultAllocator.allocate(S.sizeof);

    defaultAllocator.dispose(p);
}

// Works with interfaces.
@nogc nothrow pure @safe unittest
{
    interface I
    {
    }
    class C : I
    {
    }
    auto c = defaultAllocator.make!C();
    I i = c;

    defaultAllocator.dispose(i);
    defaultAllocator.dispose(i);
}

/**
 * Constructs a new class instance of type $(D_PARAM T) using $(D_PARAM args)
 * as the parameter list for the constructor of $(D_PARAM T).
 *
 * Params:
 *  T         = Class type.
 *  A         = Types of the arguments to the constructor of $(D_PARAM T).
 *  allocator = Allocator.
 *  args      = Constructor arguments of $(D_PARAM T).
 *
 * Returns: Newly created $(D_PSYMBOL T).
 *
 * Precondition: $(D_INLINECODE allocator !is null)
 */
T make(T, A...)(shared Allocator allocator, auto ref A args)
if (is(T == class))
in
{
    assert(allocator !is null);
}
do
{
    auto mem = (() @trusted => allocator.allocate(stateSize!T))();
    if (mem is null)
    {
        onOutOfMemoryError();
    }
    scope (failure)
    {
        () @trusted { allocator.deallocate(mem); }();
    }

    return emplace!T(mem[0 .. stateSize!T], args);
}

/**
 * Constructs a value object of type $(D_PARAM T) using $(D_PARAM args)
 * as the parameter list for the constructor of $(D_PARAM T) and returns a
 * pointer to the new object.
 *
 * Params:
 *  T         = Object type.
 *  A         = Types of the arguments to the constructor of $(D_PARAM T).
 *  allocator = Allocator.
 *  args      = Constructor arguments of $(D_PARAM T).
 *
 * Returns: Pointer to the created object.
 *
 * Precondition: $(D_INLINECODE allocator !is null)
 */
T* make(T, A...)(shared Allocator allocator, auto ref A args)
if (!is(T == interface)
 && !is(T == class)
 && !isAssociativeArray!T
 && !isArray!T)
in
{
    assert(allocator !is null);
}
do
{
    auto mem = (() @trusted => allocator.allocate(stateSize!T))();
    if (mem is null)
    {
        onOutOfMemoryError();
    }
    scope (failure)
    {
        () @trusted { allocator.deallocate(mem); }();
    }
    return emplace!T(mem[0 .. stateSize!T], args);
}

///
@nogc nothrow pure @safe unittest
{
    int* i = defaultAllocator.make!int(5);
    assert(*i == 5);
    defaultAllocator.dispose(i);
}

/**
 * Constructs a new array with $(D_PARAM n) elements.
 *
 * Params:
 *  T         = Array type.
 *  allocator = Allocator.
 *  n         = Array size.
 *
 * Returns: Newly created array.
 *
 * Precondition: $(D_INLINECODE allocator !is null
 *                           && n <= size_t.max / ElementType!T.sizeof)
 */
T make(T)(shared Allocator allocator, const size_t n)
if (isArray!T)
in
{
    assert(allocator !is null);
    assert(n <= size_t.max / ElementType!T.sizeof);
}
do
{
    auto ret = allocator.resize!(ElementType!T)(null, n);
    ret.uninitializedFill(ElementType!T.init);
    return ret;
}

///
@nogc nothrow pure @safe unittest
{
    int[] i = defaultAllocator.make!(int[])(2);
    assert(i.length == 2);
    assert(i[0] == int.init && i[1] == int.init);
    defaultAllocator.dispose(i);
}
