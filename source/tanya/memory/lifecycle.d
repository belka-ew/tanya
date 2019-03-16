/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Lifecycle management functions, types and related exceptions.
 *
 * Copyright: Eugene Wissner 2019.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/memory/init.d,
 *                 tanya/memory/init.d)
 */
module tanya.memory.lifecycle;

import tanya.algorithm.mutation;
import tanya.conv;
import tanya.memory;
import tanya.meta.trait;
import tanya.range.primitive;

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
    destroyAll(p);
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
if (!is(T == interface)
 && !is(T == class)
 && !isAssociativeArray!T
 && !isArray!T)
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
in (allocator !is null)
in (n <= size_t.max / ElementType!T.sizeof)
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
