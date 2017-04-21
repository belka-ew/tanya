/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Single-dimensioned array.
 *
 * Copyright: Eugene Wissner 2016-2017.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 */
module tanya.container.slice;

import core.checkedint;
import core.exception;
import std.algorithm.comparison;
import std.algorithm.mutation;
import std.conv;
import std.range.primitives;
import std.meta;
import std.traits;
import tanya.memory;

/**
 * Random-access range for the $(D_PSYMBOL Vector).
 *
 * Params:
 *  T = Element type.
 */
struct Slice(T)
    if (!is(Unqual!T == char))
{
    private T* begin, end;
    private alias ContainerType = CopyConstness!(T, Vector!(Unqual!T));
    private ContainerType* vector;

    invariant
    {
        assert(this.begin <= this.end);
        assert(this.vector !is null);
        assert(this.begin >= this.vector.data);
        assert(this.end <= this.vector.data + this.vector.length);
    }

    private this(ref ContainerType vector, T* begin, T* end) @trusted
    in
    {
        assert(begin <= end);
        assert(begin >= vector.data);
        assert(end <= vector.data + vector.length);
    }
    body
    {
        this.vector = &vector;
        this.begin = begin;
        this.end = end;
    }

    @disable this();

    @property Slice save()
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

    @property ref inout(T) front() inout
    in
    {
        assert(!empty);
    }
    body
    {
        return *this.begin;
    }

    @property ref inout(T) back() inout @trusted
    in
    {
        assert(!empty);
    }
    body
    {
        return *(this.end - 1);
    }

    void popFront() @trusted
    in
    {
        assert(!empty);
    }
    body
    {
        ++this.begin;
    }

    void popBack() @trusted
    in
    {
        assert(!empty);
    }
    body
    {
        --this.end;
    }

    ref inout(T) opIndex(const size_t i) inout @trusted
    in
    {
        assert(i < length);
    }
    body
    {
        return *(this.begin + i);
    }

    Slice opIndex()
    {
        return typeof(return)(*this.vector, this.begin, this.end);
    }

    Slice!(const T) opIndex() const
    {
        return typeof(return)(*this.vector, this.begin, this.end);
    }

    Slice opSlice(const size_t i, const size_t j) @trusted
    in
    {
        assert(i <= j);
        assert(j <= length);
    }
    body
    {
        return typeof(return)(*this.vector, this.begin + i, this.begin + j);
    }

    Slice!(const T) opSlice(const size_t i, const size_t j) const @trusted
    in
    {
        assert(i <= j);
        assert(j <= length);
    }
    body
    {
        return typeof(return)(*this.vector, this.begin + i, this.begin + j);
    }

    inout(T[]) get() inout @trusted
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
struct Vector(T)
    if (!is(T == char))
{
    private size_t length_;
    private T* data;
    private size_t capacity_;

    invariant
    {
        assert(this.length_ <= this.capacity_);
        assert(this.capacity_ == 0 || this.data !is null);
    }

    /**
     * Creates a new $(D_PSYMBOL Vector) with the elements from a static array.
     *
     * Params:
     *  R         = Static array size.
     *  init      = Values to initialize the vector with.
     *  allocator = Allocator.
     */
    this(size_t R)(T[R] init, shared Allocator allocator = defaultAllocator)
    {
        this(allocator);
        insertBack!(T[])(init[]);
    }

    /**
     * Creates a new $(D_PSYMBOL Vector) with the elements from an input range.
     *
     * Params:
     *  R         = Type of the initial range.
     *  init      = Values to initialize the vector with.
     *  allocator = Allocator.
     */
    this(R)(R init, shared Allocator allocator = defaultAllocator)
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
     *  R         = Vector type.
     *  init      = Source vector.
     *  allocator = Allocator.
     */
    this(R)(const ref R init, shared Allocator allocator = defaultAllocator)
        if (is(Unqual!R == Vector))
    {
        this(allocator);
        insertBack(init[]);
    }

    /// Ditto.
    this(R)(R init, shared Allocator allocator = defaultAllocator) @trusted
        if (is(R == Vector))
    {
        this(allocator);
        if (allocator is init.allocator)
        {
            // Just steal all references and the allocator.
            this.data = init.data;
            this.length_ = init.length_;
            this.capacity_ = init.capacity_;

            // Reset the source vector, so it can't destroy the moved storage.
            init.length_ = init.capacity_ = 0;
            init.data = null;
        }
        else
        {
            // Move each element.
            reserve(init.length_);
            moveEmplaceAll(init.data[0 .. init.length_], this.data[0 .. init.length_]);
            this.length_ = init.length_;
            // Destructor of init should destroy it here.
        }
    }

    ///
    @trusted @nogc unittest
    {
        auto v1 = Vector!int([1, 2, 3]);
        auto v2 = Vector!int(v1);
        assert(v1 == v2);

        auto v3 = Vector!int(Vector!int([1, 2, 3]));
        assert(v1 == v3);
        assert(v3.length == 3);
        assert(v3.capacity == 3);
    }

    private @trusted @nogc unittest // const constructor tests
    {
        auto v1 = const Vector!int([1, 2, 3]);
        auto v2 = Vector!int(v1);
        assert(v1.data !is v2.data);
        assert(v1 == v2);

        auto v3 = const Vector!int(Vector!int([1, 2, 3]));
        assert(v1 == v3);
        assert(v3.length == 3);
        assert(v3.capacity == 3);
    }

    /**
     * Creates a new $(D_PSYMBOL Vector).
     *
     * Params:
     *  len       = Initial length of the vector.
     *  init      = Initial value to fill the vector with.
     *  allocator = Allocator.
     */
    this(const size_t len, T init, shared Allocator allocator = defaultAllocator) @trusted
    {
        this(allocator);
        reserve(len);
        uninitializedFill(this.data[0 .. len], init);
        length_ = len;
    }

    /// Ditto.
    this(const size_t len, shared Allocator allocator = defaultAllocator)
    {
        this(allocator);
        length = len;
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
        auto v = Vector!int([3, 8, 2]);

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
    ~this() @trusted
    {
        clear();
        allocator.deallocate(this.data[0 .. capacity]);
    }

    /**
     * Copies the vector.
     */
    this(this)
    {
        auto buf = this.data[0 .. this.length_];
        this.length_ = capacity_ = 0;
        this.data = null;
        insertBack(buf);
    }

    /**
     * Removes all elements.
     */
    void clear()
    {
        length = 0;
    }

    ///
    unittest
    {
        auto v = Vector!int([18, 20, 15]);
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

    ///
    @safe @nogc unittest
    {
        auto v = Vector!int(4);
        assert(v.capacity == 4);
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
     *  len = New length.
     */
    @property void length(const size_t len) @trusted
    {
        if (len == length)
        {
            return;
        }
        else if (len > length)
        {
            reserve(len);
            initializeAll(this.data[length_ .. len]);
        }
        else
        {
            static if (hasElaborateDestructor!T)
            {
                const T* end = this.data + length_ - 1;
                for (T* e = this.data + len; e != end; ++e)
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
     * If $(D_PARAM size) is less than or equal to the $(D_PSYMBOL capacity), the
     * function call does not cause a reallocation and the vector capacity is not
     * affected.
     *
     * Params:
     *  size = Desired size.
     */
    void reserve(const size_t size) @trusted
    {
        if (capacity_ >= size)
        {
            return;
        }
        bool overflow;
        immutable byteSize = mulu(size, T.sizeof, overflow);
        assert(!overflow);

        void[] buf = this.data[0 .. this.capacity_];
        if (!allocator.reallocateInPlace(buf, byteSize))
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
            const T* end = this.data + this.length_;
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
    @nogc @safe unittest
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
     *  size = Desired size.
     */
    void shrink(const size_t size) @trusted
    {
        if (capacity <= size)
        {
            return;
        }
        immutable n = max(length, size);
        void[] buf = this.data[0 .. this.capacity_];
        if (allocator.reallocateInPlace(buf, n * T.sizeof))
        {
            this.capacity_ = n;
        }
    }

    ///
    @nogc @safe unittest
    {
        Vector!int v;
        assert(v.capacity == 0);
        assert(v.length == 0);

        v.reserve(5);
        v.insertBack(1);
        v.insertBack(3);
        assert(v.capacity == 5);
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
     * Removes the value at the back of the vector.
     *
     * Returns: The number of elements removed
     *
     * Precondition: $(D_INLINECODE !empty).
     */
    void removeBack()
    in
    {
        assert(!empty);
    }
    body
    {
        length = length - 1;
    }

    /**
     * Removes $(D_PARAM howMany) elements from the vector.
     *
     * This method doesn't fail if it could not remove $(D_PARAM howMany)
     * elements. Instead, if $(D_PARAM howMany) is greater than the vector
     * length, all elements are removed.
     *
     * Params:
     *  howMany = How many elements should be removed.
     *
     * Returns: The number of elements removed
     */
    size_t removeBack(const size_t howMany)
    out (removed)
    {
        assert(removed <= howMany);
    }
    body
    {
        immutable toRemove = min(howMany, length);

        length = length - toRemove;

        return toRemove;
    }

    ///
    unittest
    {
        auto v = Vector!int([5, 18, 17]);

        assert(v.removeBack(0) == 0);
        assert(v.removeBack(2) == 2);
        assert(v.removeBack(3) == 1);
        assert(v.removeBack(3) == 0);
    }

    /**
     * Remove all elements beloning to $(D_PARAM r).
     *
     * Params:
     *  r = Range originally obtained from this vector.
     *
     * Returns: A range spanning the remaining elements in the array that
     *          initially were right after $(D_PARAM r).
     *
     * Precondition: $(D_PARAM r) refers to a region of $(D_KEYWORD this).
     */
    Slice!T remove(Slice!T r) @trusted
    in
    {
        assert(r.vector is &this);
        assert(r.begin >= this.data);
        assert(r.end <= this.data + length);
    }
    body
    {
        auto end = this.data + this.length;
        moveAll(Slice!T(this, r.end, end), Slice!T(this, r.begin, end));
        length = length - r.length;
        return Slice!T(this, r.begin, this.data + length);
    }

    ///
    @safe @nogc unittest
    {
        auto v = Vector!int([5, 18, 17, 2, 4, 6, 1]);

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
        moveEmplace(el, *(this.data + this.length_));
        ++this.length_;
    }

    /**
     * Inserts the $(D_PARAM el) into the vector.
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

    /// Ditto.
    size_t insertBack(R)(ref R el) @trusted
        if (isImplicitlyConvertible!(R, T))
    {
        reserve(this.length_ + 1);
        emplace(this.data + this.length_, el);
        ++this.length_;
        return 1;
    }

    /// Ditto.
    size_t insertBack(R)(R el)
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

    /// Ditto.
    size_t insertBack(size_t R)(T[R] el)
    {
        return insertBack!(T[])(el[]);
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
     *  r  = Range originally obtained from this vector.
     *  el = Value(s) should be inserted.
     *
     * Returns: The number of elements inserted.
     *
     * Precondition: $(D_PARAM r) refers to a region of $(D_KEYWORD this).
     */
    size_t insertAfter(R)(Slice!T r, R el)
        if (!isInfinite!R
         && isInputRange!R
         && isImplicitlyConvertible!(ElementType!R, T))
    in
    {
        assert(r.vector is &this);
        assert(r.begin >= this.data);
        assert(r.end <= this.data + length);
    }
    body
    {
        immutable oldLen = length;
        immutable offset = r.end - this.data;
        immutable inserted = insertBack(el);
        bringToFront(this.data[offset .. oldLen], this.data[oldLen .. length]);
        return inserted;
    }

    /// Ditto.
    size_t insertAfter(size_t R)(Slice!T r, T[R] el)
    in
    {
        assert(r.vector is &this);
        assert(r.begin >= this.data);
        assert(r.end <= this.data + length);
    }
    body
    {
        return insertAfter!(T[])(r, el[]);
    }

    /// Ditto.
    size_t insertAfter(R)(Slice!T r, auto ref R el)
        if (isImplicitlyConvertible!(R, T))
    in
    {
        assert(r.vector is &this);
        assert(r.begin >= this.data);
        assert(r.end <= this.data + length);
    }
    body
    {
        immutable oldLen = length;
        immutable offset = r.end - this.data;

        static if (__traits(isRef, el))
        {
            insertBack(el);
        }
        else
        {
            moveBack(el);
        }
        bringToFront(this.data[offset .. oldLen], this.data[oldLen .. length]);

        return 1;
    }

    /// Ditto.
    size_t insertBefore(R)(Slice!T r, R el)
        if (!isInfinite!R
         && isInputRange!R
         && isImplicitlyConvertible!(ElementType!R, T))
    in
    {
        assert(r.vector is &this);
        assert(r.begin >= this.data);
        assert(r.end <= this.data + length);
    }
    body
    {
        return insertAfter(Slice!T(this, this.data, r.begin), el);
    }

    /// Ditto.
    size_t insertBefore(size_t R)(Slice!T r, T[R] el)
    in
    {
        assert(r.vector is &this);
        assert(r.begin >= this.data);
        assert(r.end <= this.data + length);
    }
    body
    {
        return insertBefore!(T[])(r, el[]);
    }

    /// Ditto.
    size_t insertBefore(R)(Slice!T r, auto ref R el)
        if (isImplicitlyConvertible!(R, T))
    in
    {
        assert(r.vector is &this);
        assert(r.begin >= this.data);
        assert(r.end <= this.data + length);
    }
    body
    {
        immutable oldLen = length;
        immutable offset = r.begin - this.data;

        static if (__traits(isRef, el))
        {
            insertBack(el);
        }
        else
        {
            moveBack(el);
        }
        bringToFront(this.data[offset .. oldLen], this.data[oldLen .. length]);

        return 1;
    }

    ///
    unittest
    {
        Vector!int v1;
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
    unittest
    {
        Vector!int v1;
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
     *  value = Value.
     *  pos   = Position.
     *
     * Returns: Assigned value.
     *
     * Precondition: $(D_INLINECODE length > pos).
     */
    ref T opIndexAssign(ref T value, const size_t pos)
    {
        return opIndex(pos) = value;
    }

    @safe unittest
    {
        Vector!int a = Vector!int(1);
        a[0] = 5;
        assert(a[0] == 5);
    }

    /// Ditto.
    T opIndexAssign(T value, const size_t pos)
    {
        return opIndexAssign(value, pos);
    }

    /// Ditto.
    Slice!T opIndexAssign(T value)
    {
        return opSliceAssign(value, 0, length);
    }

    /// Ditto.
    Slice!T opIndexAssign(ref T value)
    {
        return opSliceAssign(value, 0, length);
    }

    /**
     * Assigns a range or a static array.
     *
     * Params:
     *  R     = Range type or static array length.
     *  value = Value.
     *
     * Returns: Assigned value.
     *
     * Precondition: $(D_INLINECODE length == value.length).
     */
    Slice!T opIndexAssign(R)(R value)
        if (!isInfinite!R && isInputRange!R
         && isImplicitlyConvertible!(ElementType!R, T))
    {
        return opSliceAssign!R(value, 0, length);
    }

    /// Ditto.
    Slice!T opIndexAssign(size_t R)(T[R] value)
    {
        return opSliceAssign!R(value, 0, length);
    }

    ///
    @nogc unittest
    {
        auto v1 = Vector!int([12, 1, 7]);

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
    ref inout(T) opIndex(const size_t pos) inout @trusted
    in
    {
        assert(length > pos);
    }
    body
    {
        return *(this.data + pos);
    }

    /**
     * Returns: Random access range that iterates over elements of the vector, in
     *          forward order.
     */
    Slice!T opIndex() @trusted
    {
        return typeof(return)(this, this.data, this.data + length);
    }

    /// Ditto.
    Slice!(const T) opIndex() const @trusted
    {
        return typeof(return)(this, this.data, this.data + length);
    }

    ///
    unittest
    {
        const v1 = Vector!int([6, 123, 34, 5]);

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
     *  that = The vector to compare with.
     *
     * Returns: $(D_KEYWORD true) if the vectors are equal, $(D_KEYWORD false)
     *          otherwise.
     */
    bool opEquals()(auto ref typeof(this) that) @trusted
    {
        return equal(this.data[0 .. length], that.data[0 .. that.length]);
    }

    /// Ditto.
    bool opEquals()(const auto ref typeof(this) that) const @trusted
    {
        return equal(this.data[0 .. length], that.data[0 .. that.length]);
    }

    /// Ditto.
    bool opEquals(Slice!T that)
    {
        return equal(opIndex(), that);
    }

    /**
     * Comparison for equality.
     *
     * Params:
     *  R    = Right hand side type.
     *  that = Right hand side vector range.
     *
     * Returns: $(D_KEYWORD true) if the vector and the range are equal,
     *          $(D_KEYWORD false) otherwise.
     */
    bool opEquals(R)(Slice!R that) const
        if (is(Unqual!R == T))
    {
        return equal(opIndex(), that);
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
     * Returns: The first element.
     *
     * Precondition: $(D_INLINECODE !empty).
     */
    @property ref inout(T) front() inout
    in
    {
        assert(!empty);
    }
    body
    {
        return *this.data;
    }

    ///
    @safe unittest
    {
        auto v = Vector!int([5]);

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
    in
    {
        assert(!empty);
    }
    body
    {
        return *(this.data + length - 1);
    }

    ///
    unittest
    {
        auto v = Vector!int([5]);

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
    Slice!T opSlice(const size_t i, const size_t j) @trusted
    in
    {
        assert(i <= j);
        assert(j <= length);
    }
    body
    {
        return typeof(return)(this, this.data + i, this.data + j);
    }

    /// Ditto.
    Slice!(const T) opSlice(const size_t i, const size_t j) const @trusted
    in
    {
        assert(i <= j);
        assert(j <= length);
    }
    body
    {
        return typeof(return)(this, this.data + i, this.data + j);
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
        auto v = Vector!int([1, 2, 3]);
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
        auto v = Vector!int([1, 2, 3, 4]);
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
     *  R     = Type of the assigned slice or length of the static array should be
     *          assigned.
     *  value = New value (single value, input range or static array).
     *  i     = Slice start.
     *  j     = Slice end.
     *
     * Returns: Slice with the assigned part of the vector.
     *
     * Precondition: $(D_INLINECODE i <= j && j <= length
     *                           && value.length == j - i)
     */
    Slice!T opSliceAssign(R)(R value, const size_t i, const size_t j) @trusted
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
        copy(value, this.data[i .. j]);
        return opSlice(i, j);
    }

    /// Ditto.
    Slice!T opSliceAssign(size_t R)(T[R] value, const size_t i, const size_t j)
    {
        return opSliceAssign!(T[])(value[], i, j);
    }

    /// Ditto.
    Slice!T opSliceAssign(ref T value, const size_t i, const size_t j) @trusted
    in
    {
        assert(i <= j);
        assert(j <= length);
    }
    body
    {
        fill(this.data[i .. j], value);
        return opSlice(i, j);
    }

    /// Ditto.
    Slice!T opSliceAssign(T value, const size_t i, const size_t j)
    {
        return opSliceAssign(value, i, j);
    }

    ///
    @nogc @safe unittest
    {
        auto v1 = Vector!int([3, 3, 3]);
        auto v2 = Vector!int([1, 2]);

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
     * Returns an array used internally by the vector to store its owned elements.
     * The length of the returned array may differ from the size of the allocated
     * memory for the vector: the array contains only initialized elements, but
     * not the reserved memory.
     *
     * Returns: The array with elements of this vector.
     */
    inout(T[]) get() inout @trusted
    {
        return this.data[0 .. length];
    }

    ///
    unittest
    {
        auto v = Vector!int([1, 2, 4]);
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
     * Assigns another vector.
     *
     * If $(D_PARAM that) is passed by value, it won't be copied, but moved.
     * This vector will take the ownership over $(D_PARAM that)'s storage and
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
    ref typeof(this) opAssign(R)(const ref R that)
        if (is(Unqual!R == Vector))
    {
        return this = that[];
    }

    /// Ditto.
    ref typeof(this) opAssign(R)(R that) @trusted
        if (is(R == Vector))
    {
        swap(this.data, that.data);
        swap(this.length_, that.length_);
        swap(this.capacity_, that.capacity_);
        swap(this.allocator_, that.allocator_);
        return this;
    }

    /**
     * Assigns a range to the vector.
     *
     * Params:
     *  R    = Content type.
     *  that = The value should be assigned.
     *
     * Returns: $(D_KEYWORD this).
     */
    ref typeof(this) opAssign(R)(R that)
        if (!isInfinite!R
         && isInputRange!R
         && isImplicitlyConvertible!(ElementType!R, T))
    {
        length = 0;
        insertBack(that);
        return this;
    }

    ///
    @safe @nogc unittest
    {
        auto v1 = const Vector!int([5, 15, 8]);
        Vector!int v2;
        v2 = v1;
        assert(v1 == v2);
    }

    ///
    @safe @nogc unittest
    {
        auto v1 = const Vector!int([5, 15, 8]);
        Vector!int v2;
        v2 = v1[0 .. 2];
        assert(equal(v1[0 .. 2], v2[]));
    }

    // Move assignment.
    private @safe @nogc unittest
    {
        Vector!int v1;
        v1 = Vector!int([5, 15, 8]);
    }

    /**
     * Assigns a static array.
     *
     * Params:
     *  R    = Static array size.
     *  that = Values to initialize the vector with.
     *
     * Returns: $(D_KEYWORD this).
     */
    ref typeof(this) opAssign(size_t R)(T[R] that)
    {
        return opAssign!(T[])(that[]);
    }

    ///
    @safe @nogc unittest
    {
        auto v1 = Vector!int([5, 15, 8]);
        Vector!int v2;

        v2 = [5, 15, 8];
        assert(v1 == v2);
    }

    mixin DefaultAllocator;
}

///
unittest
{
    auto v = Vector!int([5, 15, 8]);

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
    const v3 = Vector!int([1, 5, 8]);
    static assert(is(PointerTarget!(typeof(v3.data)) == const(int)));
}

@nogc unittest
{
    // Test that const vectors return usable ranges.
    auto v = const Vector!int([1, 2, 4]);
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

    v1.insertBack([1, 2, 4]);
    assert(v1[] == v1);
    assert(v2[] == v2);
    assert(v2[] != v1);
    assert(v1[] != v2);
    assert(v1[].equal(v1[]));
    assert(v2[].equal(v2[]));
    assert(!v1[].equal(v2[]));
}

@nogc unittest
{
    struct MutableEqualsStruct
    {
        int opEquals(typeof(this) that) @nogc
        {
            return true;
        }
    }
    struct ConstEqualsStruct
    {
        int opEquals(const typeof(this) that) const @nogc
        {
            return true;
        }
    }
    auto v1 = Vector!ConstEqualsStruct();
    auto v2 = Vector!ConstEqualsStruct();
    assert(v1 == v2);
    assert(v1[] == v2);
    assert(v1 == v2[]);
    assert(v1[].equal(v2[]));

    auto v3 = const Vector!ConstEqualsStruct();
    auto v4 = const Vector!ConstEqualsStruct();
    assert(v3 == v4);
    assert(v3[] == v4);
    assert(v3 == v4[]);
    assert(v3[].equal(v4[]));

    auto v7 = Vector!MutableEqualsStruct(1, MutableEqualsStruct());
    auto v8 = Vector!MutableEqualsStruct(1, MutableEqualsStruct());
    assert(v7 == v8);
    assert(v7[] == v8);
    assert(v7 == v8[]);
    assert(v7[].equal(v8[]));
}

@nogc unittest
{
    struct SWithDtor
    {
        ~this() @nogc
        {
        }
    }
    auto v = Vector!SWithDtor(); // Destructor can destroy empty vectors.
}

private unittest
{
    class A
    {
    }
    A a1, a2;
    auto v1 = Vector!A([a1, a2]);
}

private @safe @nogc unittest
{
    auto v = Vector!int([5, 15, 8]);
    {
        size_t i;

        foreach (e; v)
        {
            assert(i != 0 || e == 5);
            assert(i != 1 || e == 15);
            assert(i != 2 || e == 8);
            ++i;
        }
        assert(i == 3);
    }
    {
        size_t i = 3;

        foreach_reverse (e; v)
        {
            --i;
            assert(i != 2 || e == 8);
            assert(i != 1 || e == 15);
            assert(i != 0 || e == 5);
        }
        assert(i == 0);
    }
}

private ref const(wchar) front(const wchar[] str)
pure nothrow @safe @nogc
in
{
    assert(str.length > 0);
}
body
{
    return str[0];
}

private void popFront(ref const(wchar)[] str, const size_t s = 1)
pure nothrow @safe @nogc
in
{
    assert(str.length >= s);
}
body
{
    str = str[s .. $];
}

/**
 * Thrown on encoding errors.
 */
class UTFException : Exception
{
    /**
     * Params:
     *  msg  = The message for the exception.
     *  file = The file where the exception occurred.
     *  line = The line number where the exception occurred.
     *  next = The previous exception in the chain of exceptions, if any.
     */
    this(string msg,
         string file = __FILE__,
         size_t line = __LINE__,
         Throwable next = null) @nogc @safe pure nothrow
    {
        super(msg, file, line, next);
    }
}

/**
 * Iterates $(D_PSYMBOL String) by UTF-8 code unit.
 *
 * Params:
 *  E = Element type ($(D_KEYWORD char) or $(D_INLINECODE const(char))).
 */
struct ByCodeUnit(E)
    if (is(Unqual!E == char))
{
    private E* begin, end;
    private alias ContainerType = CopyConstness!(E, Slice!char);
    private ContainerType* container;

    invariant
    {
        assert(this.begin <= this.end);
        assert(this.container !is null);
        assert(this.begin >= this.container.data);
        assert(this.end <= this.container.data + this.container.length);
    }

    private this(ref ContainerType container, E* begin, E* end) @trusted
    in
    {
        assert(begin <= end);
        assert(begin >= container.data);
        assert(end <= container.data + container.length);
    }
    body
    {
        this.container = &container;
        this.begin = begin;
        this.end = end;
    }

    @disable this();

    @property ByCodeUnit save()
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
    in
    {
        assert(!empty);
    }
    body
    {
        return *this.begin;
    }

    @property ref inout(E) back() inout @trusted
    in
    {
        assert(!empty);
    }
    body
    {
        return *(this.end - 1);
    }

    void popFront() @trusted
    in
    {
        assert(!empty);
    }
    body
    {
        ++this.begin;
    }

    void popBack() @trusted
    in
    {
        assert(!empty);
    }
    body
    {
        --this.end;
    }

    ref inout(E) opIndex(const size_t i) inout @trusted
    in
    {
        assert(i < length);
    }
    body
    {
        return *(this.begin + i);
    }

    ByCodeUnit opIndex()
    {
        return typeof(return)(*this.container, this.begin, this.end);
    }

    ByCodeUnit!(const E) opIndex() const
    {
        return typeof(return)(*this.container, this.begin, this.end);
    }

    ByCodeUnit opSlice(const size_t i, const size_t j) @trusted
    in
    {
        assert(i <= j);
        assert(j <= length);
    }
    body
    {
        return typeof(return)(*this.container, this.begin + i, this.begin + j);
    }

    ByCodeUnit!(const E) opSlice(const size_t i, const size_t j) const @trusted
    in
    {
        assert(i <= j);
        assert(j <= length);
    }
    body
    {
        return typeof(return)(*this.container, this.begin + i, this.begin + j);
    }

    inout(E[]) get() inout @trusted
    {
        return this.begin[0 .. length];
    }
}

/// UTF-8 string.
alias String = Slice!char;

/**
 * UTF-8 string.
 *
 * Params:
 *  T = $(D_KEYWORD char).
 */
struct Slice(T)
    if (is(T == char))
{
    private size_t length_;
    private char* data;
    private size_t capacity_;

    pure nothrow @safe @nogc invariant
    {
        assert(this.length_ <= this.capacity_);
    }

    /**
     * Constructs the string from a stringish range.
     *
     * Params:
     *  R         = String type.
     *  str       = Initial string.
     *  allocator = Allocator.
     *
     * Throws: $(D_PSYMBOL UTFException).
     *
     * Precondition: $(D_INLINECODE allocator is null).
     */
    this(R)(const R str, shared Allocator allocator = defaultAllocator)
        if (!isInfinite!R
         && isInputRange!R
         && isSomeChar!(ElementEncodingType!R))
    {
        this(allocator);
        insertBack(str);
    }

    ///
    @safe @nogc unittest
    {
        auto s = String("\u10437"w);
        assert("\u10437" == s.get());
    }

    ///
    @safe @nogc unittest
    {
        auto s = String("Отказаться от вина - в этом страшная вина."d);
        assert("Отказаться от вина - в этом страшная вина." == s.get());
    }

    /**
     * Initializes this string from another one.
     *
     * If $(D_PARAM init) is passed by value, it won't be copied, but moved.
     * If the allocator of ($D_PARAM init) matches $(D_PARAM allocator),
     * $(D_KEYWORD this) will just take the ownership over $(D_PARAM init)'s
     * storage, otherwise, the storage will be allocated with
     * $(D_PARAM allocator). $(D_PARAM init) will be destroyed at the end.
     *
     * If $(D_PARAM init) is passed by reference, it will be copied.
     *
     * Params:
     *  init      = Source string.
     *  allocator = Allocator.
     *
     * Precondition: $(D_INLINECODE allocator is null).
     */
    this(Slice!char init, shared Allocator allocator = defaultAllocator)
    nothrow @trusted @nogc
    {
        this(allocator);
        if (allocator !is init.allocator)
        {
            // Just steal all references and the allocator.
            this.data = init.data;
            this.length_ = init.length_;
            this.capacity_ = init.capacity_;

            // Reset the source string, so it can't destroy the moved storage.
            init.length_ = init.capacity_ = 0;
            init.data = null;
        }
        else
        {
            reserve(init.length);
            init.data[0 .. init.length].copy(this.data[0 .. init.length]);
            this.length_ = init.length;
        }
    }

    /// Ditto.
    this(ref const Slice!char init, shared Allocator allocator = defaultAllocator)
    nothrow @trusted @nogc
    {
        this(allocator);
        reserve(init.length);
        init.data[0 .. init.length].copy(this.data[0 .. init.length]);
        this.length_ = init.length;
    }

    /// Ditto.
    this(shared Allocator allocator) pure nothrow @safe @nogc
    in
    {
        assert(allocator !is null);
    }
    body
    {
        this.allocator_ = allocator;
    }

    /**
     * Fills the string with $(D_PARAM n) consecutive copies of character $(D_PARAM chr).
     *
     * Params:
     *  C   = Type of the character to fill the string with.
     *  n   = Number of characters to copy.
     *  chr = Character to fill the string with.
     */
    this(C)(const size_t n, const C chr,
            shared Allocator allocator = defaultAllocator) @trusted
        if (isSomeChar!C)
    {
        this(allocator);
        if (n == 0)
        {
            return;
        }
        insertBack(chr);

        // insertBack should validate the character, so we can just copy it
        // n - 1 times.
        auto remaining = length * n;

        reserve(remaining);

        // Use a quick copy.
        for (auto i = this.length_ * 2; i <= remaining; i *= 2)
        {
            this.data[0 .. this.length_].copy(this.data[this.length_ .. i]);
            this.length_ = i;
        }
        remaining -= length;
        copy(this.data[this.length_ - remaining .. this.length_],
             this.data[this.length_ .. this.length_ + remaining]);
        this.length_ += remaining;
    }

    private unittest
    {
        {
            auto s = String(1, 'О');
            assert(s.length == 2);
        }
        {
            auto s = String(3, 'О');
            assert(s.length == 6);
        }
        {
            auto s = String(8, 'О');
            assert(s.length == 16);
        }
    }

    /**
     * Destroys the string.
     */
    ~this() nothrow @trusted @nogc
    {
        allocator.deallocate(this.data[0 .. this.capacity_]);
    }

    private void write4Bytes(ref const dchar src)
    pure nothrow @trusted @nogc
    in
    {
        assert(capacity - length >= 4);
        assert(src - 0x10000 < 0x100000);
    }
    body
    {
        auto dst = this.data + length;

        *dst++ = 0xf0 | (src >> 18);
        *dst++ = 0x80 | ((src >> 12) & 0x3f);
        *dst++ = 0x80 | ((src >> 6) & 0x3f);
        *dst = 0x80 | (src & 0x3f);

        this.length_ += 4;
    }

    private size_t insertWideChar(C)(auto ref const C chr) @trusted
        if (is(C == wchar) || is(C == dchar))
    in
    {
        assert(capacity - length >= C.sizeof);
    }
    body
    {
        auto dst = this.data + length;
        if (chr < 0x80)
        {
            *dst = chr & 0x7f;
            this.length_ += 1;
            return 1;
        }
        else if (chr < 0x800)
        {
            *dst++ = 0xc0 | (chr >> 6) & 0xff;
            *dst = 0x80 | (chr & 0x3f);
            this.length_ += 2;
            return 2;
        }
        else if (chr < 0xd800 || chr - 0xe000 < 0x2000)
        {
            *dst++ = 0xe0 | (chr >> 12) & 0xff;
            *dst++ = 0x80 | ((chr >> 6) & 0x3f);
            *dst = 0x80 | (chr & 0x3f);
            this.length_ += 3;
            return 3;
        }
        return 0;
    }

    /**
     * Inserts a single character at the end of the string.
     *
     * Params:
     *  chr = The character should be inserted.
     *
     * Returns: The number of bytes inserted.
     *
     * Throws: $(D_PSYMBOL UTFException).
     */
    size_t insertBack(const char chr) @trusted @nogc
    {
        if ((chr & 0x80) != 0)
        {
            throw defaultAllocator.make!UTFException("Invalid UTF-8 character");
        }
        reserve(length + 1);

        *(data + length) = chr;
        ++this.length_;

        return 1;
    }

    /// Ditto.
    size_t insertBack(const wchar chr) @trusted @nogc
    {
        reserve(length + wchar.sizeof);

        auto ret = insertWideChar(chr);
        if (ret == 0)
        {
            throw defaultAllocator.make!UTFException("Invalid UTF-16 sequeunce");
        }
        return ret;
    }

    /// Ditto.
    size_t insertBack(const dchar chr) @trusted @nogc
    {
        reserve(length + dchar.sizeof);

        auto ret = insertWideChar(chr);
        if (ret > 0)
        {
            return ret;
        }
        else if (chr - 0x10000 < 0x100000)
        {
            write4Bytes(chr);
            return 4;
        }
        else
        {
            throw defaultAllocator.make!UTFException("Invalid UTF-32 sequeunce");
        }
    }

    /**
     * Inserts a stringish range at the end of the string.
     *
     * Params:
     *  R   = Type of the inserted string.
     *  str = String should be inserted.
     *
     * Returns: The number of bytes inserted.
     *
     * Throws: $(D_PSYMBOL UTFException).
     */
    size_t insertBack(R)(R str) @trusted
        if (!isInfinite!R
         && isInputRange!R
         && is(Unqual!(ElementEncodingType!R) == char))
    {
        size_t size;
        static if (hasLength!R || isNarrowString!R)
        {
            size = str.length + length;
            reserve(size);
        }

        static if (isNarrowString!R)
        {
            str.copy(this.data[length .. size]);
            this.length_ = size;
            return str.length;
        }
        else
        {
            size_t insertedLength;
            while (!str.empty)
            {
                ubyte expectedLength;
                if ((str.front & 0x80) == 0x00)
                {
                    expectedLength = 1;
                }
                else if ((str.front & 0xe0) == 0xc0)
                {
                    expectedLength = 2;
                }
                else if ((str.front & 0xf0) == 0xe0)
                {
                    expectedLength = 3;
                }
                else if ((str.front & 0xf8) == 0xf0)
                {
                    expectedLength = 4;
                }
                else
                {
                    throw defaultAllocator.make!UTFException("Invalid UTF-8 sequeunce");
                }
                size = length + expectedLength;
                reserve(size);

                for (; expectedLength > 0; --expectedLength)
                {
                    if (str.empty)
                    {
                        throw defaultAllocator.make!UTFException("Invalid UTF-8 sequeunce");
                    }
                    *(data + length) = str.front;
                    str.popFront();
                }
                insertedLength += expectedLength;
                this.length_ = size;
            }
            return insertedLength;
        }
    }

    /// Ditto.
    size_t insertBack(R)(R str) @trusted
        if (!isInfinite!R
         && isInputRange!R
         && is(Unqual!(ElementEncodingType!R) == wchar))
    {
        static if (hasLength!R || isNarrowString!R)
        {
            reserve(length + str.length * wchar.sizeof);
        }

        static if (isNarrowString!R)
        {
            const(wchar)[] range = str;
        }
        else
        {
            alias range = str;
        }

        auto oldLength = length;

        while (!range.empty)
        {
            reserve(length + 4);

            auto ret = insertWideChar(range.front);
            if (ret > 0)
            {
                range.popFront();
            }
            else if (range.front - 0xd800 < 2048)
            { // Surrogate pair.
                static if (isNarrowString!R)
                {
                    if (range.length < 2 || range[1] - 0xdc00 >= 0x400)
                    {
                        throw defaultAllocator.make!UTFException("Invalid UTF-16 sequeunce");
                    }
                    dchar d = (range[0] - 0xd800) | ((range[1] - 0xdc00) >> 10);

                    range.popFront(2);
                }
                else
                {
                    dchar d = range.front - 0xd800;
                    range.popFront();

                    if (range.empty || range.front - 0xdc00 >= 0x400)
                    {
                        throw defaultAllocator.make!UTFException("Invalid UTF-16 sequeunce");
                    }
                    d |= (range.front - 0xdc00) >> 10;

                    range.popFront();
                }
                write4Bytes(d);
            }
            else
            {
                throw defaultAllocator.make!UTFException("Invalid UTF-16 sequeunce");
            }
        }
        return this.length_ - oldLength;
    }

    /// Ditto.
    size_t insertBack(R)(R str) @trusted
        if (!isInfinite!R
         && isInputRange!R
         && is(Unqual!(ElementEncodingType!R) == dchar))
    {
        static if (hasLength!R || isSomeString!R)
        {
            reserve(length + str.length * 4);
        }

        size_t insertedLength;
        foreach (const dchar c; str)
        {
            insertedLength += insertBack(c);
        }
        return insertedLength;
    }

    /// Ditto.
    alias insert = insertBack;

    /**
     * Reserves $(D_PARAM size) bytes for the string.
     *
     * If $(D_PARAM size) is less than or equal to the $(D_PSYMBOL capacity), the
     * function call does not cause a reallocation and the string capacity is not
     * affected.
     *
     * Params:
     *  size = Desired size in bytes.
     */
    void reserve(const size_t size) nothrow @trusted @nogc
    {
        if (this.capacity_ >= size)
        {
            return;
        }

        this.data = allocator.resize(this.data[0 .. this.capacity_], size).ptr;
        this.capacity_ = size;
    }

    ///
    @nogc @safe unittest
    {
        String s;
        assert(s.capacity == 0);

        s.reserve(3);
        assert(s.capacity == 3);

        s.reserve(3);
        assert(s.capacity == 3);

        s.reserve(1);
        assert(s.capacity == 3);
    }

    /**
     * Requests the string to reduce its capacity to fit the $(D_PARAM size).
     *
     * The request is non-binding. The string won't become smaller than the
     * string byte length.
     *
     * Params:
     *  size = Desired size.
     */
    void shrink(const size_t size) nothrow @trusted @nogc
    {
        if (this.capacity_ <= size)
        {
            return;
        }

        const n = max(this.length_, size);
        void[] buf = this.data[0 .. this.capacity_];
        if (allocator.reallocate(buf, n))
        {
            this.capacity_ = n;
            this.data = cast(char*) buf;
        }
    }

    ///
    @nogc @safe unittest
    {
        auto s = String("Die Alten lasen laut.");
        assert(s.capacity == 21);

        s.reserve(30);
        s.shrink(25);
        assert(s.capacity == 25);

        s.shrink(18);
        assert(s.capacity == 21);
    }

    /**
     * Returns: String capacity in bytes.
     */
    @property size_t capacity() const pure nothrow @safe @nogc
    {
        return this.capacity_;
    }

    ///
    unittest
    {
        auto s = String("In allem Schreiben ist Schamlosigkeit.");
        assert(s.capacity == 38);
    }

    /**
     * Returns an array used internally by the string.
     * The length of the returned array may be smaller than the size of the
     * reserved memory for the string.
     *
     * Returns: The array representing the string.
     */
    inout(char[]) get() inout pure nothrow @trusted @nogc
    {
        return this.data[0 .. this.length_];
    }

    /**
     * Returns: The number of code units that are required to encode the string.
     */
    @property size_t length() const pure nothrow @safe @nogc
    {
        return this.length_;
    }

    ///
    alias opDollar = length;

    ///
    unittest
    {
        auto s = String("Piscis primuin a capite foetat.");
        assert(s.length == 31);
        assert(s[$ - 1] == '.');
    }

    /**
     * Params:
     *  pos = Position.
     *
     * Returns: Byte at $(D_PARAM pos).
     *
     * Precondition: $(D_INLINECODE length > pos).
     */
    ref inout(char) opIndex(const size_t pos) inout pure nothrow @trusted @nogc
    in
    {
        assert(length > pos);
    }
    body
    {
        return *(this.data + pos);
    }

    ///
    unittest
    {
        auto s = String("Alea iacta est.");
        assert(s[0] == 'A');
        assert(s[4] == ' ');
    }

    /**
     * Returns: Random access range that iterates over the string by bytes, in
     *          forward order.
     */
    ByCodeUnit!char opIndex() pure nothrow @trusted @nogc
    {
        return typeof(return)(this, this.data, this.data + length);
    }

    /// Ditto.
    ByCodeUnit!(const char) opIndex() const pure nothrow @trusted @nogc
    {
        return typeof(return)(this, this.data, this.data + length);
    }

    ///
    unittest
    {
        auto s = String("Plutarchus");
        auto r = s[];
        assert(r.front == 'P');
        assert(r.back == 's');

        r.popFront();
        assert(r.front == 'l');
        assert(r.back == 's');

        r.popBack();
        assert(r.front == 'l');
        assert(r.back == 'u');

        assert(r.length == 8);
    }

    /**
     * Returns: $(D_KEYWORD true) if the vector is empty.
     */
    @property bool empty() const pure nothrow @safe @nogc
    {
        return length == 0;
    }

    /**
     * Params:
     *  i = Slice start.
     *  j = Slice end.
     *
     * Returns: A range that iterates over the string by bytes from
     *          index $(D_PARAM i) up to (excluding) index $(D_PARAM j).
     *
     * Precondition: $(D_INLINECODE i <= j && j <= length).
     */
    ByCodeUnit!char opSlice(const size_t i, const size_t j)
    pure nothrow @trusted @nogc
    in
    {
        assert(i <= j);
        assert(j <= length);
    }
    body
    {
        return typeof(return)(this, this.data + i, this.data + j);
    }

    /// Ditto.
    ByCodeUnit!(const char) opSlice(const size_t i, const size_t j)
    const pure nothrow @trusted @nogc
    in
    {
        assert(i <= j);
        assert(j <= length);
    }
    body
    {
        return typeof(return)(this, this.data + i, this.data + j);
    }

    ///
    unittest
    {
        auto s = String("Vladimir Soloviev");
        auto r = s[9 .. $];

        assert(r.front == 'S');
        assert(r.back == 'v');

        r.popFront();
        r.popBack();
        assert(r.front == 'o');
        assert(r.back == 'e');

        r.popFront();
        r.popBack();
        assert(r.front == 'l');
        assert(r.back == 'i');

        r.popFront();
        r.popBack();
        assert(r.front == 'o');
        assert(r.back == 'v');

        r.popFront();
        r.popBack();
        assert(r.empty);
    }

    mixin DefaultAllocator;
}
