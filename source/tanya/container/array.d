/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Single-dimensioned array.
 *
 * Copyright: Eugene Wissner 2016-2019.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/container/array.d,
 *                 tanya/container/array.d)
 */
module tanya.container.array;

import core.checkedint;
import tanya.algorithm.comparison;
import tanya.algorithm.mutation;
import tanya.memory.allocator;
import tanya.memory.lifetime;
import tanya.meta.trait;
import tanya.meta.transform;
import tanya.range;

/**
 * Random-access range for the $(D_PSYMBOL Array).
 *
 * Params:
 *  A = Array type.
 */
struct Range(A)
{
    private alias E = PointerTarget!(typeof(A.data));
    private E* begin, end;
    private A* container;

    invariant (this.begin <= this.end);
    invariant (this.container !is null);
    invariant (this.begin >= this.container.data);
    invariant (this.end <= this.container.data + this.container.length);

    private this(return ref A container, return E* begin, return E* end)
    @trusted
    in (begin <= end)
    in (begin >= container.data)
    in (end <= container.data + container.length)
    {
        this.container = &container;
        this.begin = begin;
        this.end = end;
    }

    @disable this();

    @property Range save()
    {
        return this;
    }

    @property bool empty() const
    {
        return this.begin == this.end;
    }

    @property size_t length() const
    {
        return this.end - this.begin;
    }

    alias opDollar = length;

    @property ref inout(E) front() inout
    in (!empty)
    {
        return *this.begin;
    }

    @property ref inout(E) back() inout @trusted
    in (!empty)
    {
        return *(this.end - 1);
    }

    void popFront() @trusted
    in (!empty)
    {
        ++this.begin;
    }

    void popBack() @trusted
    in (!empty)
    {
        --this.end;
    }

    ref inout(E) opIndex(size_t i) inout @trusted
    in (i < length)
    {
        return *(this.begin + i);
    }

    Range opIndex()
    {
        return typeof(return)(*this.container, this.begin, this.end);
    }

    A.ConstRange opIndex() const
    {
        return typeof(return)(*this.container, this.begin, this.end);
    }

    Range opSlice(size_t i, size_t j) @trusted
    in (i <= j)
    in (j <= length)
    {
        return typeof(return)(*this.container, this.begin + i, this.begin + j);
    }

    A.ConstRange opSlice(size_t i, size_t j) const @trusted
    in (i <= j)
    in (j <= length)
    {
        return typeof(return)(*this.container, this.begin + i, this.begin + j);
    }

    inout(E)[] get() inout
    {
        return this.begin[0 .. length];
    }
}

/**
 * One dimensional array.
 *
 * Params:
 *  T = Content type.
 */
struct Array(T)
{
    /// The range types for $(D_PSYMBOL Array).
    alias Range = .Range!Array;

    /// ditto
    alias ConstRange = .Range!(const Array);

    private size_t length_;
    private T* data;
    private size_t capacity_;

    invariant (this.length_ <= this.capacity_);
    invariant (this.capacity_ == 0 || this.data !is null);

    /**
     * Creates a new $(D_PSYMBOL Array) with the elements from a static array.
     *
     * Params:
     *  R         = Static array size.
     *  init      = Values to initialize the array with.
     *  allocator = Allocator.
     */
    this(size_t R)(T[R] init, shared Allocator allocator = defaultAllocator)
    {
        this(allocator);
        insertBack!(T[])(init[]);
    }

    /**
     * Creates a new $(D_PSYMBOL Array) with the elements from an input range.
     *
     * Params:
     *  R         = Type of the initial range.
     *  init      = Values to initialize the array with.
     *  allocator = Allocator.
     */
    this(R)(scope R init, shared Allocator allocator = defaultAllocator)
    if (!isInfinite!R
     && isInputRange!R
     && isImplicitlyConvertible!(ElementType!R, T))
    {
        this(allocator);
        insertBack(init);
    }

    /**
     * Initializes this array from another one.
     *
     * If $(D_PARAM init) is passed by value, it won't be copied, but moved.
     * If the allocator of ($D_PARAM init) matches $(D_PARAM allocator),
     * $(D_KEYWORD this) will just take the ownership over $(D_PARAM init)'s
     * storage, otherwise, the storage will be allocated with
     * $(D_PARAM allocator) and all elements will be moved;
     * $(D_PARAM init) will be destroyed at the end.
     *
     * If $(D_PARAM init) is passed by reference, it will be copied.
     *
     * Params:
     *  R         = Source array type.
     *  init      = Source array.
     *  allocator = Allocator.
     */
    this(R)(ref R init, shared Allocator allocator = defaultAllocator)
    if (is(Unqual!R == Array))
    {
        this(allocator);
        insertBack(init[]);
    }

    /// ditto
    this(R)(R init, shared Allocator allocator = defaultAllocator) @trusted
    if (is(R == Array))
    {
        this(allocator);
        if (allocator is init.allocator)
        {
            // Just steal all references and the allocator.
            this.data = init.data;
            this.length_ = init.length_;
            this.capacity_ = init.capacity_;

            // Reset the source array, so it can't destroy the moved storage.
            init.length_ = init.capacity_ = 0;
            init.data = null;
        }
        else
        {
            // Move each element.
            reserve(init.length_);
            foreach (ref target; slice(init.length_))
            {
                moveEmplace(*init.data++, target);
            }
            this.length_ = init.length_;
            // Destructor of init should destroy it here.
        }
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        auto v1 = Array!int([1, 2, 3]);
        auto v2 = Array!int(v1);
        assert(v1 == v2);

        auto v3 = Array!int(Array!int([1, 2, 3]));
        assert(v1 == v3);
        assert(v3.length == 3);
        assert(v3.capacity == 3);
    }

    /**
     * Creates a new $(D_PSYMBOL Array).
     *
     * Params:
     *  len       = Initial length of the array.
     *  init      = Initial value to fill the array with.
     *  allocator = Allocator.
     */
    this()(size_t len,
           auto ref T init,
           shared Allocator allocator = defaultAllocator)
    {
        this(allocator);
        reserve(len);
        uninitializedFill(slice(len), init);
        length_ = len;
    }

    /// ditto
    this(size_t len, shared Allocator allocator = defaultAllocator)
    {
        this(allocator);
        length = len;
    }

    /// ditto
    this(shared Allocator allocator)
    in (allocator !is null)
    {
        allocator_ = allocator;
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        auto v = Array!int([3, 8, 2]);

        assert(v.capacity == 3);
        assert(v.length == 3);
        assert(v[0] == 3 && v[1] == 8 && v[2] == 2);
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        auto v = Array!int(3, 5);

        assert(v.capacity == 3);
        assert(v.length == 3);
        assert(v[0] == 5 && v[1] == 5 && v[2] == 5);
    }

    /**
     * Destroys this $(D_PSYMBOL Array).
     */
    ~this()
    {
        clear();
        (() @trusted => allocator.deallocate(slice(capacity)))();
    }

    static if (isCopyable!T)
    {
        this(this)
        {
            auto buf = slice(this.length);
            this.length_ = capacity_ = 0;
            this.data = null;
            insertBack(buf);
        }
    }
    else
    {
        @disable this(this);
    }

    /**
     * Removes all elements.
     */
    void clear()
    {
        length = 0;
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        auto v = Array!int([18, 20, 15]);
        v.clear();
        assert(v.length == 0);
        assert(v.capacity == 3);
    }

    /**
     * Returns: How many elements the array can contain without reallocating.
     */
    @property size_t capacity() const
    {
        return capacity_;
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        auto v = Array!int(4);
        assert(v.capacity == 4);
    }

    /**
     * Returns: Array length.
     */
    @property size_t length() const
    {
        return length_;
    }

    /// ditto
    size_t opDollar() const
    {
        return length;
    }

    /**
     * Expands/shrinks the array.
     *
     * Params:
     *  len = New length.
     */
    @property void length(size_t len) @trusted
    {
        if (len > length)
        {
            reserve(len);
            initializeAll(this.data[length_ .. len]);
        }
        else
        {
            destroyAll(this.data[len .. this.length_]);
        }
        if (len != length)
        {
            length_ = len;
        }
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        Array!int v;

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
     * If $(D_PARAM size) is less than or equal to the $(D_PSYMBOL capacity), the
     * function call does not cause a reallocation and the array capacity is not
     * affected.
     *
     * Params:
     *  size = Desired size.
     */
    void reserve(size_t size) @trusted
    {
        if (capacity_ >= size)
        {
            return;
        }
        bool overflow;
        const byteSize = mulu(size, T.sizeof, overflow);
        assert(!overflow);

        void[] buf = this.data[0 .. this.capacity_];
        if (!allocator.reallocateInPlace(buf, byteSize))
        {
            buf = allocator.allocate(byteSize);
            if (buf is null)
            {
                onOutOfMemoryError();
            }
            scope (failure)
            {
                allocator.deallocate(buf);
            }
            for (T* src = this.data, dest = cast(T*) buf; src != end; ++src, ++dest)
            {
                moveEmplace(*src, *dest);
                static if (hasElaborateDestructor!T)
                {
                    destroy(*src);
                }
            }
            allocator.deallocate(this.data[0 .. this.capacity_]);
            this.data = cast(T*) buf;
        }
        this.capacity_ = size;
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        Array!int v;
        assert(v.capacity == 0);
        assert(v.length == 0);

        v.reserve(3);
        assert(v.capacity == 3);
        assert(v.length == 0);
    }

    /**
     * Requests the array to reduce its capacity to fit the $(D_PARAM size).
     *
     * The request is non-binding. The array won't become smaller than the
     * $(D_PARAM length).
     *
     * Params:
     *  size = Desired size.
     */
    void shrink(size_t size) @trusted
    {
        if (capacity <= size)
        {
            return;
        }
        const n = max(length, size);
        void[] buf = slice(this.capacity_);
        if (allocator.reallocateInPlace(buf, n * T.sizeof))
        {
            this.capacity_ = n;
        }
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        Array!int v;
        assert(v.capacity == 0);
        assert(v.length == 0);

        v.reserve(5);
        v.insertBack(1);
        v.insertBack(3);
        assert(v.capacity == 5);
        assert(v.length == 2);
    }

    /**
     * Returns: $(D_KEYWORD true) if the array is empty.
     */
    @property bool empty() const
    {
        return length == 0;
    }

    /**
     * Removes the value at the back of the array.
     *
     * Returns: The number of elements removed
     *
     * Precondition: $(D_INLINECODE !empty).
     */
    void removeBack()
    in (!empty)
    {
        length = length - 1;
    }

    /**
     * Removes $(D_PARAM howMany) elements from the array.
     *
     * This method doesn't fail if it could not remove $(D_PARAM howMany)
     * elements. Instead, if $(D_PARAM howMany) is greater than the array
     * length, all elements are removed.
     *
     * Params:
     *  howMany = How many elements should be removed.
     *
     * Returns: The number of elements removed
     */
    size_t removeBack(size_t howMany)
    out (removed; removed <= howMany)
    {
        const toRemove = min(howMany, length);

        length = length - toRemove;

        return toRemove;
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        auto v = Array!int([5, 18, 17]);

        assert(v.removeBack(0) == 0);
        assert(v.removeBack(2) == 2);
        assert(v.removeBack(3) == 1);
        assert(v.removeBack(3) == 0);
    }

    private inout(T)[] slice(size_t length) inout @trusted
    in (length <= capacity)
    {
        return this.data[0 .. length];
    }

    private @property inout(T)* end() inout @trusted
    {
        return this.data + this.length_;
    }

    /**
     * Remove all elements beloning to $(D_PARAM r).
     *
     * Params:
     *  r = Range originally obtained from this array.
     *
     * Returns: A range spanning the remaining elements in the array that
     *          initially were right after $(D_PARAM r).
     *
     * Precondition: $(D_PARAM r) refers to a region of $(D_KEYWORD this).
     */
    Range remove(scope Range r)
    in (r.container is &this)
    in (r.begin >= this.data)
    in (r.end <= end)
    {
        auto target = r.begin;
        auto source = r.end;
        while (source !is end)
        {
            move(*source, *target);
            ((ref s, ref t) @trusted {++s; ++t;})(source, target);
        }
        length = length - r.length;
        return Range(this, r.begin, end);
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        auto v = Array!int([5, 18, 17, 2, 4, 6, 1]);

        assert(v.remove(v[1 .. 3]).length == 4);
        assert(v[0] == 5 && v[1] == 2 && v[2] == 4 && v[3] == 6 && v[4] == 1);
        assert(v.length == 5);

        assert(v.remove(v[4 .. 4]).length == 1);
        assert(v[0] == 5 && v[1] == 2 && v[2] == 4 && v[3] == 6 && v[4] == 1);
        assert(v.length == 5);

        assert(v.remove(v[4 .. 5]).length == 0);
        assert(v[0] == 5 && v[1] == 2 && v[2] == 4 && v[3] == 6);
        assert(v.length == 4);

        assert(v.remove(v[]).length == 0);

    }

    private void moveBack(R)(ref R el) @trusted
    if (isImplicitlyConvertible!(R, T))
    {
        reserve(this.length + 1);
        moveEmplace(el, *end);
        ++this.length_;
    }

    /**
     * Inserts the $(D_PARAM el) into the array.
     *
     * Params:
     *  R  = Type of the inserted value(s) (single value, range or static array).
     *  el = Value(s) should be inserted.
     *
     * Returns: The number of elements inserted.
     */
    size_t insertBack(R)(R el)
    if (isImplicitlyConvertible!(R, T))
    {
        moveBack(el);
        return 1;
    }

    /// ditto
    size_t insertBack(R)(ref R el)
    if (isImplicitlyConvertible!(R, T))
    {
        length = length + 1;
        scope (failure)
        {
            length = length - 1;
        }
        opIndex(this.length - 1) = el;
        return 1;
    }

    /// ditto
    size_t insertBack(R)(scope R el)
    if (!isInfinite!R
     && isInputRange!R
     && isImplicitlyConvertible!(ElementType!R, T))
    {
        static if (hasLength!R)
        {
            reserve(length + el.length);
        }
        size_t retLength;
        foreach (e; el)
        {
            retLength += insertBack(e);
        }
        return retLength;
    }

    /// ditto
    size_t insertBack(size_t R)(T[R] el)
    {
        return insertBack!(T[])(el[]);
    }

    /// ditto
    alias insert = insertBack;

    ///
    @nogc nothrow pure @safe unittest
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

        Array!int v1;

        assert(v1.insertBack(5) == 1);
        assert(v1.length == 1);
        assert(v1.capacity == 1);
        assert(v1.back == 5);

        assert(v1.insertBack(TestRange()) == 3);
        assert(v1.length == 4);
        assert(v1.capacity == 4);
        assert(v1[0] == 5 && v1[1] == 6 && v1[2] == 4 && v1[3] == 2);

        assert(v1.insertBack([34, 234]) == 2);
        assert(v1.length == 6);
        assert(v1.capacity == 6);
        assert(v1[4] == 34 && v1[5] == 234);
    }

    /**
     * Inserts $(D_PARAM el) before or after $(D_PARAM r).
     *
     * Params:
     *  R  = Type of the inserted value(s) (single value, range or static array).
     *  r  = Range originally obtained from this array.
     *  el = Value(s) should be inserted.
     *
     * Returns: The number of elements inserted.
     *
     * Precondition: $(D_PARAM r) refers to a region of $(D_KEYWORD this).
     */
    size_t insertAfter(R)(Range r, scope R el)
    if (!isInfinite!R
     && isInputRange!R
     && isImplicitlyConvertible!(ElementType!R, T))
    in (r.container is &this)
    in (r.begin >= this.data)
    in (r.end <= this.data + length)
    {
        const oldLength = length;
        const after = r.end - this.data;
        const inserted = insertBack(el);

        rotate(this.data[after .. oldLength], this.data[oldLength .. length]);
        return inserted;
    }

    /// ditto
    size_t insertAfter(size_t R)(Range r, T[R] el)
    in (r.container is &this)
    in (r.begin >= this.data)
    in (r.end <= this.data + length)
    {
        return insertAfter!(T[])(r, el[]);
    }

    /// ditto
    size_t insertAfter(R)(Range r, auto ref R el)
    if (isImplicitlyConvertible!(R, T))
    in (r.container is &this)
    in (r.begin >= this.data)
    in (r.end <= this.data + length)
    {
        const oldLen = length;
        const offset = r.end - this.data;

        static if (__traits(isRef, el))
        {
            insertBack(el);
        }
        else
        {
            moveBack(el);
        }
        rotate(this.data[offset .. oldLen], this.data[oldLen .. length]);

        return 1;
    }

    /// ditto
    size_t insertBefore(R)(Range r, scope R el)
    if (!isInfinite!R
     && isInputRange!R
     && isImplicitlyConvertible!(ElementType!R, T))
    in (r.container is &this)
    in (r.begin >= this.data)
    in (r.end <= this.data + length)
    {
        return insertAfter(Range(this, this.data, r.begin), el);
    }

    /// ditto
    size_t insertBefore(size_t R)(Range r, T[R] el)
    in (r.container is &this)
    in (r.begin >= this.data)
    in (r.end <= this.data + length)
    {
        return insertBefore!(T[])(r, el[]);
    }

    /// ditto
    size_t insertBefore(R)(Range r, auto ref R el)
    if (isImplicitlyConvertible!(R, T))
    in (r.container is &this)
    in (r.begin >= this.data)
    in (r.end <= this.data + length)
    {
        const oldLen = length;
        const offset = r.begin - this.data;

        static if (__traits(isRef, el))
        {
            insertBack(el);
        }
        else
        {
            moveBack(el);
        }
        rotate(this.data[offset .. oldLen], this.data[oldLen .. length]);

        return 1;
    }

    ///
    @nogc nothrow pure unittest
    {
        Array!int v1;
        v1.insertAfter(v1[], [2, 8]);
        assert(v1[0] == 2);
        assert(v1[1] == 8);
        assert(v1.length == 2);

        v1.insertAfter(v1[], [1, 2]);
        assert(v1[0] == 2);
        assert(v1[1] == 8);
        assert(v1[2] == 1);
        assert(v1[3] == 2);
        assert(v1.length == 4);

        v1.insertAfter(v1[0 .. 0], [1, 2]);
        assert(v1[0] == 1);
        assert(v1[1] == 2);
        assert(v1[2] == 2);
        assert(v1[3] == 8);
        assert(v1[4] == 1);
        assert(v1[5] == 2);
        assert(v1.length == 6);

        v1.insertAfter(v1[0 .. 4], 9);
        assert(v1[0] == 1);
        assert(v1[1] == 2);
        assert(v1[2] == 2);
        assert(v1[3] == 8);
        assert(v1[4] == 9);
        assert(v1[5] == 1);
        assert(v1[6] == 2);
        assert(v1.length == 7);
    }

    ///
    @nogc nothrow pure unittest
    {
        Array!int v1;
        v1.insertBefore(v1[], [2, 8]);
        assert(v1[0] == 2);
        assert(v1[1] == 8);
        assert(v1.length == 2);

        v1.insertBefore(v1[], [1, 2]);
        assert(v1[0] == 1);
        assert(v1[1] == 2);
        assert(v1[2] == 2);
        assert(v1[3] == 8);
        assert(v1.length == 4);

        v1.insertBefore(v1[0 .. 1], [1, 2]);
        assert(v1[0] == 1);
        assert(v1[1] == 2);
        assert(v1[2] == 1);
        assert(v1[3] == 2);
        assert(v1[4] == 2);
        assert(v1[5] == 8);
        assert(v1.length == 6);

        v1.insertBefore(v1[2 .. $], 9);
        assert(v1[0] == 1);
        assert(v1[1] == 2);
        assert(v1[2] == 9);
        assert(v1[3] == 1);
        assert(v1[4] == 2);
        assert(v1[5] == 2);
        assert(v1[6] == 8);
        assert(v1.length == 7);
    }

    /**
     * Assigns a value to the element with the index $(D_PARAM pos).
     *
     * Params:
     *  E     = Value type.
     *  value = Value.
     *  pos   = Position.
     *
     * Returns: Assigned value.
     *
     * Precondition: $(D_INLINECODE length > pos).
     */
    ref T opIndexAssign(E : T)(auto ref E value, size_t pos)
    {
        return opIndex(pos) = forward!value;
    }

    /// ditto
    Range opIndexAssign(E : T)(auto ref E value)
    {
        return opSliceAssign(value, 0, length);
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        Array!int a = Array!int(1);
        a[0] = 5;
        assert(a[0] == 5);
    }

    /**
     * Assigns a range or a static array.
     *
     * Params:
     *  R     = Value type.
     *  value = Value.
     *
     * Returns: Assigned value.
     *
     * Precondition: $(D_INLINECODE length == value.length).
     */
    Range opIndexAssign(size_t R)(T[R] value)
    {
        return opSliceAssign!R(value, 0, length);
    }

    /// ditto
    Range opIndexAssign()(Range value)
    {
        return opSliceAssign(value, 0, length);
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        auto v1 = Array!int([12, 1, 7]);

        v1[] = 3;
        assert(v1[0] == 3);
        assert(v1[1] == 3);
        assert(v1[2] == 3);

        v1[] = [7, 1, 12];
        assert(v1[0] == 7);
        assert(v1[1] == 1);
        assert(v1[2] == 12);
    }

    /**
     * Params:
     *  pos = Index.
     *
     * Returns: The value at a specified index.
     *
     * Precondition: $(D_INLINECODE length > pos).
     */
    ref inout(T) opIndex(size_t pos) inout @trusted
    in (length > pos)
    {
        return *(this.data + pos);
    }

    /**
     * Returns: Random access range that iterates over elements of the array,
     *          in forward order.
     */
    Range opIndex() @trusted
    {
        return typeof(return)(this, this.data, this.data + length);
    }

    /// ditto
    ConstRange opIndex() const @trusted
    {
        return typeof(return)(this, this.data, this.data + length);
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        const v1 = Array!int([6, 123, 34, 5]);

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
     *  that = The array to compare with.
     *
     * Returns: $(D_KEYWORD true) if the arrays are equal, $(D_KEYWORD false)
     *          otherwise.
     */
    bool opEquals()(auto ref typeof(this) that) @trusted
    {
        return equal(this.data[0 .. length], that.data[0 .. that.length]);
    }

    /// ditto
    bool opEquals()(auto ref const typeof(this) that) const @trusted
    {
        return equal(this.data[0 .. length], that.data[0 .. that.length]);
    }

    /// ditto
    bool opEquals(Range that)
    {
        return equal(opIndex(), that);
    }

    /**
     * Comparison for equality.
     *
     * Params:
     *  R    = Right hand side type.
     *  that = Right hand side array range.
     *
     * Returns: $(D_KEYWORD true) if the array and the range are equal,
     *          $(D_KEYWORD false) otherwise.
     */
    bool opEquals(R)(R that) const
    if (is(R == Range) || is(R == ConstRange))
    {
        return equal(opIndex(), that);
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        Array!int v1, v2;
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
     * Returns: The first element.
     *
     * Precondition: $(D_INLINECODE !empty).
     */
    @property ref inout(T) front() inout
    in (!empty)
    {
        return *this.data;
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        auto v = Array!int([5]);

        assert(v.front == 5);

        v.length = 2;
        v[1] = 15;
        assert(v.front == 5);
    }

    /**
     * Returns: The last element.
     *
     * Precondition: $(D_INLINECODE !empty).
     */
    @property ref inout(T) back() inout @trusted
    in (!empty)
    {
        return *(this.data + length - 1);
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        auto v = Array!int([5]);

        assert(v.back == 5);

        v.length = 2;
        v[1] = 15;
        assert(v.back == 15);
    }

    /**
     * Params:
     *  i = Slice start.
     *  j = Slice end.
     *
     * Returns: A range that iterates over elements of the container from
     *          index $(D_PARAM i) up to (excluding) index $(D_PARAM j).
     *
     * Precondition: $(D_INLINECODE i <= j && j <= length).
     */
    Range opSlice(size_t i, size_t j) @trusted
    in (i <= j)
    in (j <= length)
    {
        return typeof(return)(this, this.data + i, this.data + j);
    }

    /// ditto
    ConstRange opSlice(size_t i, size_t j) const @trusted
    in (i <= j)
    in (j <= length)
    {
        return typeof(return)(this, this.data + i, this.data + j);
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        auto v = Array!int([1, 2, 3]);
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
    @nogc nothrow pure @safe unittest
    {
        auto v = Array!int([1, 2, 3, 4]);
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
     *  R     = Type of the assigned slice or length of the static array should
     *          be assigned.
     *  value = New value (single value, range or static array).
     *  i     = Slice start.
     *  j     = Slice end.
     *
     * Returns: Slice with the assigned part of the array.
     *
     * Precondition: $(D_INLINECODE i <= j && j <= length
     *                           && value.length == j - i)
     */
    Range opSliceAssign(size_t R)(T[R] value, size_t i, size_t j)
    @trusted
    in (i <= j)
    in (j <= length)
    {
        copy(value[], this.data[i .. j]);
        return opSlice(i, j);
    }

    /// ditto
    Range opSliceAssign(R : T)(auto ref R value, size_t i, size_t j)
    @trusted
    in (i <= j)
    in (j <= length)
    {
        fill(this.data[i .. j], value);
        return opSlice(i, j);
    }

    /// ditto
    Range opSliceAssign()(Range value, size_t i, size_t j) @trusted
    in (i <= j)
    in (j <= length)
    in (j - i == value.length)
    {
        copy(value, this.data[i .. j]);
        return opSlice(i, j);
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        auto v1 = Array!int([3, 3, 3]);
        auto v2 = Array!int([1, 2]);

        v1[0 .. 2] = 286;
        assert(v1[0] == 286);
        assert(v1[1] == 286);
        assert(v1[2] == 3);

        v2[0 .. $] = v1[1 .. 3];
        assert(v2[0] == 286);
        assert(v2[1] == 3);

        v1[0 .. 2] = [5, 8];
        assert(v1[0] == 5);
        assert(v1[1] == 8);
        assert(v1[2] == 3);
    }

    /**
     * Returns an array used internally by the array to store its owned elements.
     * The length of the returned array may differ from the size of the allocated
     * memory for the array: the array contains only initialized elements, but
     * not the reserved memory.
     *
     * Returns: The array with elements of this array.
     */
    inout(T[]) get() inout
    {
        return this.data[0 .. length];
    }

    ///
    @nogc nothrow pure @system unittest
    {
        auto v = Array!int([1, 2, 4]);
        auto data = v.get();

        assert(data[0] == 1);
        assert(data[1] == 2);
        assert(data[2] == 4);
        assert(data.length == 3);

        data = v[1 .. 2].get();
        assert(data[0] == 2);
        assert(data.length == 1);
    }

    /**
     * Assigns another array.
     *
     * If $(D_PARAM that) is passed by value, it won't be copied, but moved.
     * This array will take the ownership over $(D_PARAM that)'s storage and
     * the allocator.
     *
     * If $(D_PARAM that) is passed by reference, it will be copied.
     *
     * Params:
     *  R    = Content type.
     *  that = The value should be assigned.
     *
     * Returns: $(D_KEYWORD this).
     */
    ref typeof(this) opAssign(R)(ref R that)
    if (is(Unqual!R == Array))
    {
        return this = that[];
    }

    /// ditto
    ref typeof(this) opAssign(R)(R that)
    if (is(R == Array))
    {
        swap(this.data, that.data);
        swap(this.length_, that.length_);
        swap(this.capacity_, that.capacity_);
        swap(this.allocator_, that.allocator_);
        return this;
    }

    /**
     * Assigns a range to the array.
     *
     * Params:
     *  R    = Content type.
     *  that = The value should be assigned.
     *
     * Returns: $(D_KEYWORD this).
     */
    ref typeof(this) opAssign(R)(scope R that)
    if (!isInfinite!R
     && isInputRange!R
     && isImplicitlyConvertible!(ElementType!R, T))
    {
        length = 0;
        insertBack(that);
        return this;
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        auto v1 = const Array!int([5, 15, 8]);
        Array!int v2;
        v2 = v1;
        assert(v1 == v2);
    }

    /**
     * Assigns a static array.
     *
     * Params:
     *  R    = Static array size.
     *  that = Values to initialize the array with.
     *
     * Returns: $(D_KEYWORD this).
     */
    ref typeof(this) opAssign(size_t R)(T[R] that)
    {
        return opAssign!(T[])(that[]);
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        auto v1 = Array!int([5, 15, 8]);
        Array!int v2;

        v2 = [5, 15, 8];
        assert(v1 == v2);
    }

    mixin DefaultAllocator;
}

///
@nogc nothrow pure @safe unittest
{
    auto v = Array!int([5, 15, 8]);

    assert(v.front == 5);
    assert(v[1] == 15);
    assert(v.back == 8);

    auto r = v[];
    r[0] = 7;
    assert(r.front == 7);
    assert(r.front == v.front);
}
