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

import core.exception;
import std.algorithm.comparison;
import std.algorithm.mutation;
import std.algorithm.searching;
import std.range;
import std.traits;
import tanya.memory;

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

/**
 * Iterates $(D_PSYMBOL String) by UTF-8 code point.
 *
 * Params:
 *  E = Element type ($(D_KEYWORD char) or $(D_INLINECODE const(char))).
 */
struct ByCodePoint(E)
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

    @property ByCodePoint save()
    {
        return this;
    }

    @property bool empty() const
    {
        return this.begin == this.end;
    }

    @property dchar front() const @trusted
    in
    {
        assert(!empty);
    }
    out (chr)
    {
        assert(chr < 0xd800 || chr > 0xdfff);
    }
    body
    {
        dchar chr;
        ubyte units, mask;
        const(char)* it = this.begin;

        if (*it & 0x80)
        {
            mask = 0xe0;
            for (units = 2; ((*it << units) & 0x80) != 0; ++units)
            {
                mask = (mask >> 1) | 0x80;
            }
        }
        if (this.begin + units > end || units > 4)
        {
            throw defaultAllocator.make!UTFException("Invalid UTF-8 character");
        }
        chr = *it++ & ~mask;

        for (; units > 1; --units)
        {
            chr = (chr << 6) | (*it++ & 0x3f);
        }

        return chr;
    }

    void popFront() @trusted
    in
    {
        assert(!empty);
    }
    body
    {
        ubyte units;
        if ((*begin & 0x80) == 0)
        {
            units = 1;
        }
        else if ((*begin & 0xc0) == 0xc0)
        {
            units = 2;
        }
        else if ((*begin & 0xe0) == 0xe0)
        {
            units = 3;
        }
        else if ((*begin & 0xf0) == 0xf0)
        {
            units = 4;
        }
        if (units == 0 || this.begin + units > this.end)
        {
            throw defaultAllocator.make!UTFException("Invalid UTF-8 character");
        }
        this.begin += units;
    }

    ByCodePoint opIndex()
    {
        return typeof(return)(*this.container, this.begin, this.end);
    }

    ByCodePoint!(const E) opIndex() const
    {
        return typeof(return)(*this.container, this.begin, this.end);
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

    pure nothrow @safe @nogc invariant
    {
        assert(this.length_ <= this.capacity_);
    }

    /**
     * Constructs the string from a stringish range.
     *
     * Params:
     *  S         = String type.
     *  str       = Initial string.
     *  allocator = Allocator.
     *
     * Throws: $(D_PSYMBOL UTFException).
     *
     * Precondition: $(D_INLINECODE allocator is null).
     */
    this(S)(const S str, shared Allocator allocator = defaultAllocator)
        if (!isInfinite!S
         && isInputRange!S
         && isSomeChar!(ElementEncodingType!S))
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
     *  S         = Source string type.
     *  init      = Source string.
     *  allocator = Allocator.
     *
     * Precondition: $(D_INLINECODE allocator is null).
     */
    this(S)(S init, shared Allocator allocator = defaultAllocator)
    nothrow @trusted @nogc
        if (is(S == String))
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
    this(S)(ref S init, shared Allocator allocator = defaultAllocator)
    nothrow @trusted @nogc
        if (is(Unqual!S == String))
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
    this(C)(const size_t n,
            const C chr,
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

    ///
    @safe @nogc unittest
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
        allocator.resize(this.data[0 .. this.capacity_], 0);
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
            reserve(length + wchar.sizeof * 2);

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
    @safe @nogc unittest
    {
        auto s = String("In allem Schreiben ist Schamlosigkeit.");
        assert(s.capacity == 38);
    }

    /**
     * Slicing assignment.
     *
     * Params:
     *  R     = Type of the assigned slice.
     *  value = New value (single value, range or string).
     *  i     = Slice start.
     *  j     = Slice end.
     *
     * Returns: Slice with the assigned part of the string.
     *
     * Precondition: $(D_INLINECODE i <= j && j <= length
     *                           && value.length == j - i)
     */
    ByCodeUnit!char opSliceAssign(R)(ByCodeUnit!R value,
                                     const size_t i,
                                     const size_t j) @trusted
        if (is(Unqual!R == char))
    in
    {
        assert(i <= j);
        assert(j <= length);
        assert(j - i == value.length);
    }
    body
    {
        copy(value, this.data[i .. j]);
        return opSlice(i, j);
    }

    /// Ditto.
    ByCodeUnit!char opSliceAssign(const char[] value,
                                  const size_t i,
                                  const size_t j)
    pure nothrow @trusted @nogc
    in
    {
        assert(i <= j);
        assert(j <= length);
    }
    body
    {
        copy(value[], this.data[i .. j]);
        return opSlice(i, j);
    }

    /// Ditto.
    ByCodeUnit!char opSliceAssign(const char value,
                                  const size_t i,
                                  const size_t j)
    pure nothrow @trusted @nogc
    in
    {
        assert(i <= j);
        assert(j <= length);
    }
    body
    {
        for (auto p = this.data + i; p < this.data + j; ++p)
        {
            *p = value;
        }
        return opSlice(i, j);
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
    @safe @nogc unittest
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
    @safe @nogc unittest
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
    @safe @nogc unittest
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
     * Returns: Forward range that iterates over the string by code points.
     */
    ByCodePoint!char byCodePoint() pure nothrow @trusted @nogc
    {
        return typeof(return)(this, this.data, this.data + length);
    }

    /// Ditto.
    ByCodePoint!(const char) byCodePoint() const pure nothrow @trusted @nogc
    {
        return typeof(return)(this, this.data, this.data + length);
    }

    ///
    @safe @nogc unittest
    {
        auto s = String("Высоцкий");
        auto cp = s.byCodePoint();
        assert(cp.front == 'В');
        cp.popFront();
        assert(cp.front == 'ы');
        cp.popFront();
        assert(cp.front == 'с');

        s = String("€");
        cp = s.byCodePoint();
        assert(cp.front == '€');
        assert(s.length == 3);

        s = String("\U00024B62");
        cp = s.byCodePoint();
        assert(cp.front == '\U00024B62');
        assert(s.length == 4);
    }

    /**
     * Returns: $(D_KEYWORD true) if the string is empty.
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
    @safe @nogc unittest
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

    /**
     * Assigns another string.
     *
     * If $(D_PARAM that) is passed by value, it won't be copied, but moved.
     * This string will take the ownership over $(D_PARAM that)'s storage and
     * the allocator.
     *
     * If $(D_PARAM that) is passed by reference, it will be copied.
     *
     * Params:
     *  S    = Content type.
     *  that = The value should be assigned.
     *
     * Returns: $(D_KEYWORD this).
     */
    ref String opAssign(S)(S that)
        if (is(S == String))
    {
        swap(this.data, that.data);
        swap(this.length_, that.length_);
        swap(this.capacity_, that.capacity_);
        swap(this.allocator_, that.allocator_);
        return this;
    }

    /// Ditto.
    ref String opAssign(S)(ref S that) @trusted
        if (is(Unqual!S == String))
    {
        reserve(that.length);
        that.data[0 .. that.length].copy(this.data[0 .. that.length]);
        this.length_ = that.length;
        return this;
    }

    ///
    @safe @nogc unittest
    {
        auto s = String("Черная, потом пропахшая выть!");
        s = String("Как мне тебя не ласкать, не любить?");
    }

    /**
     * Assigns a stringish range.
     *
     * Params:
     *  S    = String type.
     *  that = Initial string.
     *
     * Returns: $(D_KEYWORD this).
     *
     * Throws: $(D_PSYMBOL UTFException).
     */
    ref String opAssign(S)(S that) nothrow
        if (!isInfinite!S
         && isInputRange!S
         && isSomeChar!(ElementEncodingType!S))
    {
        this.length_ = 0;
        insertBack(that);
        return this;
    }

    ///
    @safe @nogc unittest
    {
        auto s = String("Оловом светится лужная голь...");
        s = "Грустная песня, ты - русская боль.";
    }

    /**
     * Comparison for equality.
     *
     * Params:
     *  S    = Right hand side type.
     *  that = The string to compare with.
     *
     * Returns: A positive number if $(D_KEYWORD this) is lexicographically
     *          greater than $(D_PARAM that), if equal `0`, else `-1`.
     */
    int opCmp(S)(auto ref S that) const @trusted
        if (is(Unqual!S == String))
    {
        return cmp(this.data[0 .. length], that.data[0 .. that.length]);
    }

    /// Ditto.
    int opCmp(S)(ByCodeUnit!S that) const @trusted
        if (is(Unqual!S == char))
    {
        return cmp(this.data[0 .. length],
                   that.begin[0 .. that.end - that.begin]);
    }

    /// Ditto.
    int opCmp(S)(ByCodePoint!S that) const @trusted
        if (is(Unqual!S == char))
    {
        return cmp(this.data[0 .. length],
                   that.begin[0 .. that.end - that.begin]);
    }

    /// Ditto.
    int opCmp()(const char[] that) const @trusted
    {
        return cmp(this.data[0 .. length], that);
    }

    ///
    @safe @nogc unittest
    {
        assert(String("Голубая кофта.") < String("Синие глаза."));
        assert(String("Никакой я правды") < String("милой не сказал")[]);
    }

    /**
     * Comparison for equality.
     *
     * Params:
     *  S    = Right hand side type.
     *  that = The string to compare with.
     *
     * Returns: $(D_KEYWORD true) if the strings are equal, $(D_KEYWORD false)
     *          otherwise.
     */
    bool opEquals(S)(auto ref S that) const @trusted
        if (is(Unqual!S == String))
    {
        return equal(this.data[0 .. length], that.data[0 .. that.length]);
    }

    /**
     * Comparison for equality.
     *
     * Params:
     *  that = Right hand side string range.
     *
     * Returns: $(D_KEYWORD true) if the string and the range are equal,
     *          $(D_KEYWORD false) otherwise.
     */
    bool opEquals(S)(ByCodeUnit!S that) const @trusted
        if (is(Unqual!S == char))
    {
        return equal(this.data[0 .. length],
                     that.begin[0 .. that.end - that.begin]);
    }

    /// Ditto.
    bool opEquals(S)(ByCodePoint!S that) const @trusted
        if (is(Unqual!S == char))
    {
        return equal(this.data[0 .. length],
                     that.begin[0 .. that.end - that.begin]);
    }

    /// Ditto.
    bool opEquals()(const char[] that) const @trusted
    {
        return equal(this.data[0 .. length], that);
    }

    ///
    @safe @nogc unittest
    {
        assert(String("Милая спросила:") != String("Крутит ли метель?"));
        assert(String("Затопить бы печку,") != String("постелить постель.")[]);
        assert(const String("Я ответил милой:") != String("Нынче с высоты"));
        assert(String("Кто-то осыпает") != "белые цветы");
        assert(const String("Затопи ты печку,") != String("постели постель,")[]);

        auto s = const String("У меня на сердце");
        assert(s[] != String("без тебя метель."));
        assert(s == s);
        assert(s == s[]);
        assert(s == "У меня на сердце");
    }

    /**
     * Assigns a value to the character with the index $(D_PARAM pos).
     *
     * Params:
     *  value = Value.
     *  pos   = Position.
     *
     * Returns: Assigned value.
     *
     * Precondition: $(D_INLINECODE length > pos).
     */
    ref char opIndexAssign(const char value, const size_t pos)
    pure nothrow @safe @nogc
    {
        return opIndex(pos) = value;
    }

    /**
     * Assigns a range or a string.
     *
     * Params:
     *  R     = Value type.
     *  value = Value.
     *
     * Returns: Assigned value.
     *
     * Precondition: $(D_INLINECODE length == value.length).
     */
    ByCodeUnit!char opIndexAssign(R)(ByCodeUnit!R value)
        if (is(Unqual!R == char))
    {
        return opSliceAssign(value, 0, length);
    }

    /// Ditto.
    ByCodeUnit!char opIndexAssign(const char value) pure nothrow @safe @nogc
    {
        return opSliceAssign(value, 0, length);
    }

    /// Ditto.
    ByCodeUnit!char opIndexAssign(const char[] value) pure nothrow @safe @nogc
    {
        return opSliceAssign(value, 0, length);
    }

    mixin DefaultAllocator;
}
