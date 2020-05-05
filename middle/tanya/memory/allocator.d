/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * This module contains the interface for implementing custom allocators.
 *
 * Allocators are classes encapsulating memory allocation strategy. This allows
 * to decouple memory management from the algorithms and the data. 
 *
 * Copyright: Eugene Wissner 2016-2020.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/middle/tanya/memory/allocator.d,
 *                 tanya/memory/allocator.d)
 */
module tanya.memory.allocator;

import tanya.memory.lifetime;
import tanya.meta.trait;

/**
 * Abstract class implementing a basic allocator.
 */
interface Allocator
{
    /**
     * Returns: Alignment offered.
     */
    @property uint alignment() const shared pure nothrow @safe @nogc;

    /**
     * Allocates $(D_PARAM size) bytes of memory.
     *
     * Params:
     *  size = Amount of memory to allocate.
     *
     * Returns: Pointer to the new allocated memory.
     */
    void[] allocate(size_t size) shared pure nothrow @nogc;

    /**
     * Deallocates a memory block.
     *
     * Params:
     *  p = A pointer to the memory block to be freed.
     *
     * Returns: Whether the deallocation was successful.
     */
    bool deallocate(void[] p) shared pure nothrow @nogc;

    /**
     * Increases or decreases the size of a memory block.
     *
     * Params:
     *  p    = A pointer to the memory block.
     *  size = Size of the reallocated block.
     *
     * Returns: Pointer to the allocated memory.
     */
    bool reallocate(ref void[] p, size_t size) shared pure nothrow @nogc;

    /**
     * Reallocates a memory block in place if possible or returns
     * $(D_KEYWORD false). This function cannot be used to allocate or
     * deallocate memory, so if $(D_PARAM p) is $(D_KEYWORD null) or
     * $(D_PARAM size) is `0`, it should return $(D_KEYWORD false).
     *
     * Params:
     *  p    = A pointer to the memory block.
     *  size = Size of the reallocated block.
     *
     * Returns: $(D_KEYWORD true) if successful, $(D_KEYWORD false) otherwise.
     */
    bool reallocateInPlace(ref void[] p, size_t size)
    shared pure nothrow @nogc;
}

package template GetPureInstance(T : Allocator)
{
    alias GetPureInstance = shared(T) function()
                            pure nothrow @nogc;
}

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
    in (allocator !is null)
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
    out (allocator; allocator !is null)
    {
        if (allocator_ is null)
        {
            allocator_ = defaultAllocator;
        }
        return allocator_;
    }

    /// ditto
    @property shared(Allocator) allocator() const @nogc nothrow pure @trusted
    out (allocator; allocator !is null)
    {
        if (allocator_ is null)
        {
            return defaultAllocator;
        }
        return cast(shared Allocator) allocator_;
    }
}

shared Allocator allocator;

private shared(Allocator) getAllocatorInstance() @nogc nothrow
{
    if (allocator is null)
    {
        version (TanyaNative)
        {
            import tanya.memory.mmappool : MmapPool;
            defaultAllocator = MmapPool.instance;
        }
        else
        {
            import tanya.memory.mallocator : Mallocator;
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
out (allocator; allocator !is null)
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
in (allocator !is null)
{
    .allocator = allocator;
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

/**
 * Error thrown if memory allocation fails.
 */
final class OutOfMemoryError : Error
{
    /**
     * Constructs new error.
     *
     * Params:
     *  msg  = The message for the exception.
     *  file = The file where the exception occurred.
     *  line = The line number where the exception occurred.
     *  next = The previous exception in the chain of exceptions, if any.
     */
    this(string msg = "Out of memory",
         string file = __FILE__,
         size_t line = __LINE__,
         Throwable next = null) @nogc nothrow pure @safe
    {
        super(msg, file, line, next);
    }

    /// ditto
    this(string msg,
         Throwable next,
         string file = __FILE__,
         size_t line = __LINE__) @nogc nothrow pure @safe
    {
        super(msg, file, line, next);
    }
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
in (allocator !is null)
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
if (!isPolymorphicType!T && !isAssociativeArray!T && !isArray!T)
in (allocator !is null)
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
 *  E         = Array element type.
 *  allocator = Allocator.
 *  n         = Array size.
 *
 * Returns: Newly created array.
 *
 * Precondition: $(D_INLINECODE allocator !is null
 *                           && n <= size_t.max / E.sizeof)
 */
T make(T : E[], E)(shared Allocator allocator, size_t n)
in (allocator !is null)
in (n <= size_t.max / E.sizeof)
{
    auto ret = allocator.resize!E(null, n);

    static if (hasElaborateDestructor!E)
    {
        for (auto range = ret; range.length != 0; range = range[1 .. $])
        {
            emplace!E(cast(void[]) range[0 .. 1], E.init);
        }
    }
    else
    {
        ret[] = E.init;
    }

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

/*
 * Destroys the object.
 * Returns the memory should be freed.
 */
package void[] finalize(T)(ref T* p)
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

package void[] finalize(T)(ref T p)
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

package void[] finalize(T)(ref T[] p)
{
    destroyAllImpl!(T[], T)(p);
    return p;
}

/**
 * Allocates $(D_PSYMBOL OutOfMemoryError) in a static storage and throws it.
 *
 * Params:
 *  msg = Custom error message.
 *
 * Throws: $(D_PSYMBOL OutOfMemoryError).
 */
void onOutOfMemoryError(string msg = "Out of memory")
@nogc nothrow pure @trusted
{
    static ubyte[stateSize!OutOfMemoryError] memory;
    alias PureType = OutOfMemoryError function(string) @nogc nothrow pure;
    throw (cast(PureType) () => emplace!OutOfMemoryError(memory))(msg);
}

// From druntime
extern (C)
private void _d_monitordelete(Object h, bool det) @nogc nothrow pure;

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
