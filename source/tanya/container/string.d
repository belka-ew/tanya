/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * UTF-8 string.
 *
 * Copyright: Eugene Wissner 2017.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 */
module tanya.container.string;

import core.checkedint;
import core.exception;
import std.algorithm.comparison;
import std.algorithm.mutation;
import std.traits;
import tanya.memory;

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
 * Byte range.
 *
 * Params:
 *  E = Element type ($(D_KEYWORD char) or $(D_INLINECODE const(char))).
 */
struct ByteRange(E)
    if (is(Unqual!E == char))
{
    private E* begin, end;
    private alias ContainerType = CopyConstness!(E, String);
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

    @property ByteRange save()
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

    ByteRange opIndex()
    {
        return typeof(return)(*this.container, this.begin, this.end);
    }

    ByteRange!(const E) opIndex() const
    {
        return typeof(return)(*this.container, this.begin, this.end);
    }

    ByteRange opSlice(const size_t i, const size_t j) @trusted
    in
    {
        assert(i <= j);
        assert(j <= length);
    }
    body
    {
        return typeof(return)(*this.container, this.begin + i, this.begin + j);
    }

    ByteRange!(const E) opSlice(const size_t i, const size_t j) const @trusted
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

/**
 * UTF-8 string.
 */
struct String
{
    private size_t length_;
    private char* data;
    private size_t capacity_;

    invariant
    {
        assert(this.length_ <= this.capacity_);
    }

    /**
     * Params:
     *  str       = Initial string.
     *  allocator = Allocator.
     *
     * Throws: $(D_PSYMBOL UTFException).
     *
     * Precondition: $(D_INLINECODE allocator is null).
     */
    this(const char[] str, shared Allocator allocator = defaultAllocator)
    @trusted @nogc
    {
        this(allocator);
        reserve(str.length);
        this.length_ = str.length;
        str.copy(this.data[0 .. this.length_]);
    }

    /// Ditto.
    this(const wchar[] str, shared Allocator allocator = defaultAllocator)
    @trusted @nogc
    {
        this(allocator);
        reserve(str.length * 2);

        size_t s;
        auto sourceLength = str.length;
        for (auto c = str.ptr; sourceLength != 0; ++c, --sourceLength)
        {
            if (length - s < 5) // More space required.
            {
                bool overflow;
                auto size = addu(length, str.length, overflow);
                assert(!overflow);
                reserve(size);
            }
            if (*c < 0x80)
            {
                this.data[s++] = *c & 0x7f;
                this.length_ += 1;
            }
            else if (*c < 0x800)
            {
                this.data[s++] = 0xc0 | (*c >> 6) & 0xff;
                this.data[s++] = 0x80 | (*c & 0x3f);
                this.length_ += 2;
            }
            else if (*c < 0xd800 || *c - 0xe000 < 0x2000)
            {
                this.data[s++] = 0xe0 | (*c >> 12) & 0xff;
                this.data[s++] = 0x80 | ((*c >> 6) & 0x3f);
                this.data[s++] = 0x80 | (*c & 0x3f);
                this.length_ += 3;
            }
            else if ((*c - 0xd800) < 2048 && sourceLength > 0 && *(c + 1) - 0xdc00 < 0x400)
            { // Surrogate pair
                dchar d = (*c - 0xd800) | ((*c++ - 0xdc00) >> 10);

                this.data[s++] = 0xf0 | (d >> 18);
                this.data[s++] = 0x80 | ((d >> 12) & 0x3f);
                this.data[s++] = 0x80 | ((d >> 6) & 0x3f);
                this.data[s++] = 0x80 | (d & 0x3f);
                --sourceLength;
                this.length_ += 4;
            }
            else
            {
                throw defaultAllocator.make!UTFException("Wrong UTF-16 sequeunce");
            }
        }
    }

    ///
    unittest
    {
        auto s = String("\u10437"w);
        assert("\u10437" == s.get());
    }

    /// Ditto.
    this(const dchar[] str, shared Allocator allocator = defaultAllocator)
    @trusted @nogc
    {
        this(allocator);

        reserve(str.length * 4);

        auto s = data;
        foreach (c; str)
        {
            if (c < 0x80)
            {
                *s++ = c & 0x7f;
                this.length_ += 1;
            }
            else if (c < 0x800)
            {
                *s++ = 0xc0 | (c >> 6) & 0xff;
                *s++ = 0x80 | (c & 0x3f);
                this.length_ += 2;
            }
            else if (c < 0xd800 || c - 0xe000 < 0x2000)
            {
                *s++ = 0xe0 | (c >> 12) & 0xff;
                *s++ = 0x80 | ((c >> 6) & 0x3f);
                *s++ = 0x80 | (c & 0x3f);
                this.length_ += 3;
            }
            else if (c - 0x10000 < 0x100000)
            {
                *s++ = 0xf0 | (c >> 18);
                *s++ = 0x80 | ((c >> 12) & 0x3f);
                *s++ = 0x80 | ((c >> 6) & 0x3f);
                *s++ = 0x80 | (c & 0x3f);
                this.length_ += 4;
            }
            else
            {
                throw defaultAllocator.make!UTFException("Wrong UTF-32 sequeunce");
            }
        }
    }

    ///
    unittest
    {
        auto s = String("Отказаться от вина - в этом страшная вина."d);
        assert("Отказаться от вина - в этом страшная вина." == s.get());
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
     * Destroys the string.
     */
    ~this() nothrow @trusted @nogc
    {
        allocator.deallocate(this.data[0 .. this.capacity_]);
    }

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
     * Returns: Byte length.
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
    ByteRange!char opIndex() pure nothrow @trusted @nogc
    {
        return typeof(return)(this, this.data, this.data + length);
    }

    /// Ditto.
    ByteRange!(const char) opIndex() const pure nothrow @trusted @nogc
    {
        return typeof(return)(this, this.data, this.data + length);
    }

    /**
     * Returns: $(D_KEYWORD true) if the vector is empty.
     */
    @property bool empty() const pure nothrow @safe @nogc
    {
        return length == 0;
    }

    /**
     * Returns: The first byte.
     *
     * Precondition: $(D_INLINECODE !empty).
     */
    @property ref inout(char) front() inout pure nothrow @safe @nogc
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
        auto s = String("Vladimir Soloviev");
        assert(s.front == 'V');
    }

    /**
     * Returns: The last byte.
     *
     * Precondition: $(D_INLINECODE !empty).
     */
    @property ref inout(char) back() inout pure nothrow @trusted @nogc
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
        auto s = String("Caesar");
        assert(s.back == 'r');
    }

    mixin DefaultAllocator;
}
