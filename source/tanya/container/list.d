/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Linked list.
 *
 * Copyright: Eugene Wissner 2016-2017.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 */
module tanya.container.list;

import std.algorithm.comparison;
import std.algorithm.mutation;
import std.algorithm.searching;
import std.range.primitives;
import std.traits;
import tanya.container.entry;
import tanya.memory;

/**
 * Forward range for the $(D_PSYMBOL SList).
 *
 * Params:
 *  L = List type.
 */
struct SRange(L)
{
    private alias EntryPointer = typeof(L.head);
    private alias E = typeof(EntryPointer.content);

    private EntryPointer* head;

    invariant
    {
        assert(this.head !is null);
    }

    private this(ref EntryPointer head) @trusted
    {
        this.head = &head;
    }

    @disable this();

    @property SRange save()
    {
        return this;
    }

    @property bool empty() const
    {
        return *this.head is null;
    }

    @property ref inout(E) front() inout
    in
    {
        assert(!empty);
    }
    body
    {
        return (*this.head).content;
    }

    void popFront() @trusted
    in
    {
        assert(!empty);
    }
    body
    {
        this.head = &(*this.head).next;
    }

    SRange opIndex()
    {
        return typeof(return)(*this.head);
    }

    L.ConstRange opIndex() const
    {
        return typeof(return)(*this.head);
    }
}

/**
 * Singly-linked list.
 *
 * Params:
 *  T = Content type.
 */
struct SList(T)
{
    /// The range types for $(D_PSYMBOL SList).
    alias Range = SRange!SList;

    /// Ditto.
    alias ConstRange = SRange!(const SList);

    private alias Entry = SEntry!T;

    // 0th element of the list.
    private Entry* head;

    /**
     * Creates a new $(D_PSYMBOL SList) with the elements from a static array.
     *
     * Params:
     *  R         = Static array size.
     *  init      = Values to initialize the list with.
     *  allocator = Allocator.
     */
    this(size_t R)(T[R] init, shared Allocator allocator = defaultAllocator)
    {
        this(allocator);
        insertFront(init[]);
    }

    ///
    @safe @nogc unittest
    {
        auto l = SList!int([5, 8, 15]);
        assert(l.front == 5);
    }

    /**
     * Creates a new $(D_PSYMBOL SList) with the elements from an input range.
     *
     * Params:
     *  R         = Type of the initial range.
     *  init      = Values to initialize the list with.
     *  allocator = Allocator.
     */
    this(R)(R init, shared Allocator allocator = defaultAllocator)
    if (!isInfinite!R
     && isInputRange!R
     && isImplicitlyConvertible!(ElementType!R, T))
    {
        this(allocator);
        insertFront(init);
    }

    /**
     * Creates a new $(D_PSYMBOL SList).
     *
     * Params:
     *  len       = Initial length of the list.
     *  init      = Initial value to fill the list with.
     *  allocator = Allocator.
     */
    this(const size_t len, T init, shared Allocator allocator = defaultAllocator) @trusted
    {
        this(allocator);
        if (len == 0)
        {
            return;
        }

        Entry* next = this.head = allocator.make!Entry(init);
        foreach (i; 1 .. len)
        {
            next.next = allocator.make!Entry(init);
            next = next.next;
        }
    }

    ///
    @safe @nogc unittest
    {
        auto l = SList!int(2, 3);
        assert(l.length == 2);
        assert(l.front == 3);
    }

    private @safe @nogc unittest
    {
        auto l = SList!int(0, 0);
        assert(l.empty);
    }

    /// Ditto.
    this(const size_t len, shared Allocator allocator = defaultAllocator)
    {
        this(len, T.init, allocator);
    }

    ///
    @safe @nogc unittest
    {
        auto l = SList!int(2);
        assert(l.length == 2);
        assert(l.front == 0);
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
     * Initializes this list from another one.
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
     *  R         = Source list type.
     *  init      = Source list.
     *  allocator = Allocator.
     */
    this(R)(ref R init, shared Allocator allocator = defaultAllocator)
    if (is(Unqual!R == SList))
    {
        this(init[], allocator);
    }

    /// Ditto.
    this(R)(R init, shared Allocator allocator = defaultAllocator) @trusted
    if (is(R == SList))
    {
        this(allocator);
        if (allocator is init.allocator)
        {
            this.head = init.head;
            init.head = null;
        }
        else
        {
            Entry* next;
            for (auto current = init.head; current !is null; current = current.next)
            {
                if (this.head is null)
                {
                    this.head = allocator.make!Entry(move(current.content));
                    next = this.head;
                }
                else
                {
                    next.next = allocator.make!Entry(move(current.content));
                    next = next.next;
                }
            }
        }
    }

    ///
    @safe @nogc unittest
    {
        auto l1 = SList!int([5, 1, 234]);
        auto l2 = SList!int(l1);
        assert(l1 == l2);
    }

    /**
     * Removes all elements from the list.
     */
    ~this()
    {
        clear();
    }

    /**
     * Copies the list.
     */
    this(this)
    {
        auto list = typeof(this)(this[], this.allocator);
        this.head = list.head;
        list.head = null;
    }

    ///
    @safe @nogc unittest
    {
        auto l1 = SList!int([5, 1, 234]);
        auto l2 = l1;
        assert(l1 == l2);
    }

    /**
     * Removes all contents from the list.
     */
    void clear()
    {
        while (!empty)
        {
            removeFront();
        }
    }

    ///
    @safe @nogc unittest
    {
        SList!int l = SList!int([8, 5]);

        assert(!l.empty);
        l.clear();
        assert(l.empty);
    }

    /**
     * Returns: First element.
     */
    @property ref inout(T) front() inout
    in
    {
        assert(!empty);
    }
    body
    {
        return this.head.content;
    }

    private size_t moveEntry(R)(ref Entry* head, ref R el) @trusted
    if (isImplicitlyConvertible!(R, T))
    {
        auto temp = cast(Entry*) allocator.allocate(Entry.sizeof);

        el.moveEmplace(temp.content);
        temp.next = head;

        head = temp;
        return 1;
    }

    /**
     * Inserts a new element at the beginning.
     *
     * Params:
     *  R  = Type of the inserted value(s).
     *  el = New element(s).
     *
     * Returns: The number of elements inserted.
     */
    size_t insertFront(R)(R el)
    if (isImplicitlyConvertible!(R, T))
    {
        return moveEntry(this.head, el);
    }

    /// Ditto.
    size_t insertFront(R)(ref R el) @trusted
    if (isImplicitlyConvertible!(R, T))
    {
        this.head = allocator.make!Entry(el, this.head);
        return 1;
    }

    ///
    unittest
    {
        SList!int l;
        int value = 5;

        l.insertFront(value);
        assert(l.front == value);

        value = 8;
        l.insertFront(value);
        assert(l.front == 8);
    }

    /// Ditto.
    size_t insertFront(R)(R el) @trusted
    if (!isInfinite!R
     && isInputRange!R
     && isImplicitlyConvertible!(ElementType!R, T))
    {
        size_t retLength;
        Entry* next, newHead;

        if (!el.empty)
        {
            next = allocator.make!Entry(el.front);
            newHead = next;
            el.popFront();
            retLength = 1;
        }
        foreach (ref e; el)
        {
            next.next = allocator.make!Entry(e);
            next = next.next;
            ++retLength;
        }
        if (newHead !is null)
        {
            next.next = this.head;
            this.head = newHead;
        }
        return retLength;
    }

    /// Ditto.
    size_t insertFront(size_t R)(T[R] el)
    {
        return insertFront!(T[])(el[]);
    }

    /// Ditto.
    alias insert = insertFront;

    ///
    @safe @nogc unittest
    {
        SList!int l1;

        assert(l1.insertFront(8) == 1);
        assert(l1.front == 8);
        assert(l1.insertFront(9) == 1);
        assert(l1.front == 9);

        SList!int l2;
        assert(l2.insertFront([25, 30, 15]) == 3);
        assert(l2.front == 25);

        l2.insertFront(l1[]);
        assert(l2.length == 5);
        assert(l2.front == 9);
    }

    version (assert)
    {
        private bool checkRangeBelonging(ref Range r) const
        {
            const(Entry*)* pos = &this.head;
            for (; pos != r.head && *pos !is null; pos = &(*pos).next)
            {
            }
            return pos == r.head;
        }
    }

    /**
     * Inserts new elements before $(D_PARAM r).
     *
     * Params:
     *  R  = Type of the inserted value(s).
     *  r  = Range extracted from this list.
     *  el = New element(s).
     *
     * Returns: The number of elements inserted.
     *
     * Precondition: $(D_PARAM r) is extracted from this list.
     */
    size_t insertBefore(R)(Range r, R el)
    if (isImplicitlyConvertible!(R, T))
    in
    {
        assert(checkRangeBelonging(r));
    }
    body
    {
        return moveEntry(*r.head, el);
    }

    ///
    @safe @nogc unittest
    {
        auto l1 = SList!int([234, 5, 1]);
        auto l2 = SList!int([5, 1]);
        l2.insertBefore(l2[], 234);
        assert(l1 == l2);
    }

    /// Ditto.
    size_t insertBefore(R)(Range r, R el)
    if (!isInfinite!R
     && isInputRange!R
     && isImplicitlyConvertible!(ElementType!R, T))
    in
    {
        assert(checkRangeBelonging(r));
    }
    body
    {
        size_t inserted;
        foreach (e; el)
        {
            inserted += insertBefore(r, e);
            r.popFront();
        }
        return inserted;
    }

    ///
    @safe @nogc unittest
    {
        auto l1 = SList!int([5, 234, 30, 1]);
        auto l2 = SList!int([5, 1]);
        auto l3 = SList!int([234, 30]);
        auto r = l2[];
        r.popFront();
        l2.insertBefore(r, l3[]);
        assert(l1 == l2);
    }

    /// Ditto.
    size_t insertBefore(Range r, ref T el) @trusted
    in
    {
        assert(checkRangeBelonging(r));
    }
    body
    {
        *r.head = allocator.make!Entry(el, *r.head);
        return 1;
    }

    ///
    @safe @nogc unittest
    {
        auto l1 = SList!int([234, 5, 1]);
        auto l2 = SList!int([5, 1]);
        int var = 234;
        l2.insertBefore(l2[], var);
        assert(l1 == l2);
    }

    /**
     * Inserts elements from a static array before $(D_PARAM r).
     *
     * Params:
     *  R  = Static array size.
     *  r  = Range extracted from this list.
     *  el = New elements.
     *
     * Returns: The number of elements inserted.
     *
     * Precondition: $(D_PARAM r) is extracted from this list.
     */
    size_t insertBefore(size_t R)(Range r, T[R] el)
    {
        return insertBefore!(T[])(r, el[]);
    }

    ///
    @safe @nogc unittest
    {
        auto l1 = SList!int([5, 234, 30, 1]);
        auto l2 = SList!int([5, 1]);
        auto r = l2[];
        r.popFront();
        l2.insertBefore(r, [234, 30]);
        assert(l1 == l2);
    }

    /**
     * Returns: How many elements are in the list.
     */
    @property size_t length() const
    {
        return count(this[]);
    }

    ///
    @safe @nogc unittest
    {
        SList!int l;

        l.insertFront(8);
        l.insertFront(9);
        assert(l.length == 2);
        l.removeFront();
        assert(l.length == 1);
        l.removeFront();
        assert(l.length == 0);
    }

    /**
     * Comparison for equality.
     *
     * Params:
     *  that = The list to compare with.
     *
     * Returns: $(D_KEYWORD true) if the lists are equal, $(D_KEYWORD false)
     *          otherwise.
     */
    bool opEquals()(auto ref typeof(this) that) inout
    {
        return equal(this[], that[]);
    }

    ///
    @safe @nogc unittest
    {
        SList!int l1, l2;

        l1.insertFront(8);
        l1.insertFront(9);
        l2.insertFront(8);
        l2.insertFront(10);
        assert(l1 != l2);

        l1.removeFront();
        assert(l1 != l2);

        l2.removeFront();
        assert(l1 == l2);

        l1.removeFront();
        assert(l1 != l2);

        l2.removeFront();
        assert(l1 == l2);
    }

    /**
     * Returns: $(D_KEYWORD true) if the list is empty.
     */
    @property bool empty() const
    {
        return this.head is null;
    }

    /**
     * Removes the front element.
     *
     * Precondition: $(D_INLINECODE !empty)
     */
    void removeFront()
    in
    {
        assert(!empty);
    }
    body
    {
        auto n = this.head.next;

        this.allocator.dispose(this.head);
        this.head = n;
    }

    ///
    @safe @nogc unittest
    {
        SList!int l;

        l.insertFront(8);
        l.insertFront(9);
        assert(l.front == 9);
        l.removeFront();
        assert(l.front == 8);
        l.removeFront();
        assert(l.empty);
    }

    /**
     * Removes $(D_PARAM howMany) elements from the list.
     *
     * Unlike $(D_PSYMBOL removeFront()), this method doesn't fail, if it could not
     * remove $(D_PARAM howMany) elements. Instead, if $(D_PARAM howMany) is
     * greater than the list length, all elements are removed.
     *
     * Params:
     *  howMany = How many elements should be removed.
     *
     * Returns: The number of elements removed.
     */
    size_t removeFront(const size_t howMany)
    out (removed)
    {
        assert(removed <= howMany);
    }
    body
    {
        size_t i;
        for (; i < howMany && !empty; ++i)
        {
            removeFront();
        }
        return i;
    }

    ///
    @safe @nogc unittest
    {
        SList!int l = SList!int([8, 5, 4]);

        assert(l.removeFront(0) == 0);
        assert(l.removeFront(2) == 2);
        assert(l.removeFront(3) == 1);
        assert(l.removeFront(3) == 0);
    }

    /**
     * Removes $(D_PARAM r) from the list.
     *
     * Params:
     *  r = The range to remove.
     *
     * Returns: An empty range.
     *
     * Precondition: $(D_PARAM r) is extracted from this list.
     */
    Range remove(Range r)
    in
    {
        assert(checkRangeBelonging(r));
    }
    body
    {
        auto outOfScopeList = typeof(this)(allocator);
        outOfScopeList.head = *r.head;
        *r.head = null;
    
        return r;
    }

    ///
    @safe @nogc unittest
    {
        auto l1 = SList!int([5, 234, 30, 1]);
        auto l2 = SList!int([5]);
        auto r = l1[];

        r.popFront();

        assert(l1.remove(r).empty);
        assert(l1 == l2);
    }

    /**
     * Returns: Range that iterates over all elements of the container, in
     *          forward order.
     */
    Range opIndex()
    {
        return typeof(return)(this.head);
    }

    /// Ditto.
    ConstRange opIndex() const
    {
        return typeof(return)(this.head);
    }

    /**
     * Assigns another list.
     *
     * If $(D_PARAM that) is passed by value, it won't be copied, but moved.
     * This list will take the ownership over $(D_PARAM that)'s storage and
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
    if (is(Unqual!R == SList))
    {
        return this = that[];
    }

    /// Ditto.
    ref typeof(this) opAssign(R)(R that)
    if (is(R == SList))
    {
        swap(this.head, that.head);
        swap(this.allocator_, that.allocator_);
        return this;
    }

    ///
    @safe @nogc unittest
    {
        {
            auto l1 = SList!int([5, 4, 9]);
            auto l2 = SList!int([9, 4]);
            l1 = l2;
            assert(l1 == l2);
        }
        {
            auto l1 = SList!int([5, 4, 9]);
            auto l2 = SList!int([9, 4]);
            l1 = SList!int([9, 4]);
            assert(l1 == l2);
        }
    }

    /**
     * Assigns an input range.
     *
     * Params:
     *  R    = Type of the initial range.
     *  that = Values to initialize the list with.
     *
     * Returns: $(D_KEYWORD this).
     */
    ref typeof(this) opAssign(R)(R that) @trusted
    if (!isInfinite!R
     && isInputRange!R
     && isImplicitlyConvertible!(ElementType!R, T))
    {
        Entry** next = &this.head;

        foreach (ref e; that)
        {
            if (*next is null)
            {
                *next = allocator.make!Entry(e);
            }
            else
            {
                (*next).content = e;
            }
            next = &(*next).next;
        }
        remove(Range(*next));

        return this;
    }

    ///
    @safe @nogc unittest
    {
        auto l1 = SList!int([5, 4, 9]);
        auto l2 = SList!int([9, 4]);
        l1 = l2[];
        assert(l1 == l2);
    }

    private @safe @nogc unittest
    {
        auto l1 = SList!int();
        auto l2 = SList!int([9, 4]);
        l1 = l2[];
        assert(l1 == l2);
    }

    /**
     * Assigns a static array.
     *
     * Params:
     *  R    = Static array size.
     *  that = Values to initialize the list with.
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
        auto l1 = SList!int([5, 4, 9]);
        auto l2 = SList!int([9, 4]);
        l1 = [9, 4];
        assert(l1 == l2);
    }

    mixin DefaultAllocator;
}

///
@nogc unittest
{
    SList!int l;
    size_t i;

    l.insertFront(5);
    l.insertFront(4);
    l.insertFront(9);
    foreach (e; l)
    {
        assert(i != 0 || e == 9);
        assert(i != 1 || e == 4);
        assert(i != 2 || e == 5);
        ++i;
    }
    assert(i == 3);
}

@safe @nogc private unittest
{
    interface Stuff
    {
    }
    static assert(is(SList!Stuff));
}

// foreach called using opIndex().
private @nogc @safe unittest
{
    SList!int l;
    size_t i;

    l.insertFront(5);
    l.insertFront(4);
    l.insertFront(9);
    foreach (e; l)
    {
        assert(i != 0 || e == 9);
        assert(i != 1 || e == 4);
        assert(i != 2 || e == 5);
        ++i;
    }
}

/**
 * Forward range for the $(D_PSYMBOL DList).
 *
 * Params:
 *  L = List type.
 */
struct DRange(L)
{
    private alias E = typeof(L.head.content);
    private alias EntryPointer = typeof(L.head);

    private EntryPointer* head;
    private EntryPointer* tail;

    invariant
    {
        assert(this.head !is null);
    }

    private this(ref EntryPointer head, ref EntryPointer tail) @trusted
    {
        this.head = &head;
        this.tail = &tail;
    }

    @disable this();

    @property DRange save()
    {
        return this;
    }

    @property bool empty() const
    {
        return *this.head is null || *this.head is (*this.tail).next;
    }

    @property ref inout(E) front() inout
    in
    {
        assert(!empty);
    }
    body
    {
        return (*this.head).content;
    }

    @property ref inout(E) back() inout
    in
    {
        assert(!empty);
    }
    body
    {
        return (*this.tail).content;
    }

    void popFront() @trusted
    in
    {
        assert(!empty);
    }
    body
    {
        this.head = &(*this.head).next;
    }

    void popBack() @trusted
    in
    {
        assert(!empty);
    }
    body
    {
        this.tail = &(*this.tail).prev;
    }

    DRange opIndex()
    {
        return typeof(return)(*this.head, *this.tail);
    }

    L.ConstRange opIndex() const
    {
        return typeof(return)(*this.head, *this.tail);
    }
}

/**
 * Doubly-linked list.
 *
 * Params:
 *  T = Content type.
 */
struct DList(T)
{
    /// The range types for $(D_PSYMBOL DList).
    alias Range = DRange!DList;

    /// Ditto.
    alias ConstRange = DRange!(const DList);

    private alias Entry = DEntry!T;

    // 0th and the last elements of the list.
    private Entry* head, tail;

    invariant
    {
        assert((this.tail is null && this.head is null)
            || (this.tail !is null && this.head !is null));
        assert(this.tail is null || this.tail.next is null);
        assert(this.head is null || this.head.prev is null);
    }

    /**
     * Creates a new $(D_PSYMBOL DList) with the elements from a static array.
     *
     * Params:
     *  R         = Static array size.
     *  init      = Values to initialize the list with.
     *  allocator = Allocator.
     */
    this(size_t R)(T[R] init, shared Allocator allocator = defaultAllocator)
    {
        this(allocator);
        insertFront(init[]);
    }

    ///
    @safe @nogc unittest
    {
        auto l = DList!int([5, 8, 15]);
        assert(l.front == 5);
    }

    /**
     * Creates a new $(D_PSYMBOL DList) with the elements from an input range.
     *
     * Params:
     *  R         = Type of the initial range.
     *  init      = Values to initialize the list with.
     *  allocator = Allocator.
     */
    this(R)(R init, shared Allocator allocator = defaultAllocator)
    if (!isInfinite!R
     && isInputRange!R
     && isImplicitlyConvertible!(ElementType!R, T))
    {
        this(allocator);
        insertFront(init);
    }

    /**
     * Creates a new $(D_PSYMBOL DList).
     *
     * Params:
     *  len       = Initial length of the list.
     *  init      = Initial value to fill the list with.
     *  allocator = Allocator.
     */
    this(const size_t len, T init, shared Allocator allocator = defaultAllocator) @trusted
    {
        this(allocator);
        if (len == 0)
        {
            return;
        }

        Entry* next = this.head = allocator.make!Entry(init);
        foreach (i; 1 .. len)
        {
            next.next = allocator.make!Entry(init);
            next.next.prev = next;
            next = next.next;
        }
        this.tail = next;
    }

    ///
    @safe @nogc unittest
    {
        auto l = DList!int(2, 3);
        assert(l.length == 2);
        assert(l.front == 3);
        assert(l.back == 3);
    }

    private @safe @nogc unittest
    {
        auto l = DList!int(0, 0);
        assert(l.empty);
    }

    /// Ditto.
    this(const size_t len, shared Allocator allocator = defaultAllocator)
    {
        this(len, T.init, allocator);
    }

    ///
    @safe @nogc unittest
    {
        auto l = DList!int(2);
        assert(l.length == 2);
        assert(l.front == 0);
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
     * Initializes this list from another one.
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
     *  R         = Source list type.
     *  init      = Source list.
     *  allocator = Allocator.
     */
    this(R)(ref R init, shared Allocator allocator = defaultAllocator)
    if (is(Unqual!R == DList))
    {
        this(init[], allocator);
    }

    /// Ditto.
    this(R)(R init, shared Allocator allocator = defaultAllocator) @trusted
    if (is(R == DList))
    {
        this(allocator);
        if (allocator is init.allocator)
        {
            this.head = init.head;
            this.tail = init.tail;
            init.head = this.tail = null;
        }
        else
        {
            Entry* next;
            for (auto current = init.head; current !is null; current = current.next)
            {
                if (this.head is null)
                {
                    this.head = allocator.make!Entry(move(current.content));
                    next = this.head;
                }
                else
                {
                    next.next = allocator.make!Entry(move(current.content));
                    next.next.prev = next;
                    next = next.next;
                }
            }
            this.tail = next;
        }
    }

    ///
    @safe @nogc unittest
    {
        auto l1 = DList!int([5, 1, 234]);
        auto l2 = DList!int(l1);
        assert(l1 == l2);
    }

    /**
     * Removes all elements from the list.
     */
    ~this()
    {
        clear();
    }

    /**
     * Copies the list.
     */
    this(this)
    {
        auto list = typeof(this)(this[], this.allocator);
        this.head = list.head;
        this.tail = list.tail;
        list.head = list .tail = null;
    }

    ///
    @safe @nogc unittest
    {
        auto l1 = DList!int([5, 1, 234]);
        auto l2 = l1;
        assert(l1 == l2);
    }

    /**
     * Removes all contents from the list.
     */
    void clear()
    {
        while (!empty)
        {
            removeFront();
        }
    }

    ///
    @safe @nogc unittest
    {
        DList!int l = DList!int([8, 5]);

        assert(!l.empty);
        l.clear();
        assert(l.empty);
    }

    /**
     * Returns: First element.
     */
    @property ref inout(T) front() inout
    in
    {
        assert(!empty);
    }
    body
    {
        return this.head.content;
    }

    /**
     * Returns: Last element.
     */
    @property ref inout(T) back() inout
    in
    {
        assert(!empty);
    }
    body
    {
        return this.tail.content;
    }

    ///
    @safe @nogc unittest
    {
        auto l = DList!int([25]);
        assert(l.front == 25);
        assert(l.back == 25);

        l.insertFront(30);
        assert(l.front == 30);
        assert(l.back == 25);
    }

    private size_t moveFront(R)(ref Entry* head, ref R el) @trusted
    if (isImplicitlyConvertible!(R, T))
    {
        auto temp = cast(Entry*) allocator.allocate(Entry.sizeof);

        el.moveEmplace(temp.content);
        temp.next = head;
        if (this.tail is null)
        {
            temp.prev = null;
            this.tail = temp;
        }
        else
        {
            temp.prev = head.prev;
            head.prev = temp;
        }

        head = temp;
        return 1;
    }

	// Creates a lsit of linked entries from a range.
	// Returns count of the elements in the list.
	private size_t makeList(R)(ref R el, out Entry* head, out Entry* tail) @trusted
	out (retLength)
	{
		assert(retLength == 0 && head is null && tail is null
		    || retLength > 0 && head !is null && tail !is null);
	}
	body
	{
		size_t retLength;

        if (!el.empty)
        {
            head = tail = allocator.make!Entry(el.front);
            el.popFront();
            retLength = 1;
        }
        foreach (ref e; el)
        {
            tail.next = allocator.make!Entry(e);
            tail.next.prev = tail;
            tail = tail.next;
            ++retLength;
        }
		return retLength;
	}

    /**
     * Inserts a new element at the beginning.
     *
     * Params:
     *  R  = Type of the inserted value(s).
     *  el = New element(s).
     *
     * Returns: The number of elements inserted.
     */
    size_t insertFront(R)(R el)
    if (isImplicitlyConvertible!(R, T))
    {
        return moveFront(this.head, el);
    }

    /// Ditto.
    size_t insertFront(R)(ref R el) @trusted
    if (isImplicitlyConvertible!(R, T))
    {
        if (this.tail is null)
        {
            this.head = this.tail = allocator.make!Entry(el);
        }
        else
        {
            this.head.prev = allocator.make!Entry(el, this.head);
            this.head = this.head.prev;
        }
        return 1;
    }

    ///
    unittest
    {
        DList!int l;
        int value = 5;

        l.insertFront(value);
        assert(l.front == value);
        assert(l.back == value);

        value = 8;
        l.insertFront(value);
        assert(l.front == 8);
        assert(l.back == 5);
    }

    /// Ditto.
    size_t insertFront(R)(R el)
    if (!isInfinite!R
     && isInputRange!R
     && isImplicitlyConvertible!(ElementType!R, T))
    {
        Entry* begin, end;
        const inserted = makeList(el, begin, end);

        if (this.head is null)
        {
            this.tail = end;
        }
        if (begin !is null)
        {
            end.next = this.head;
            this.head = begin;
        }

        return inserted;
    }

    private @safe @nogc unittest
    {
        auto l1 = DList!int([5, 234]);
        assert(l1.head is l1.head.next.prev);
    }

    /// Ditto.
    size_t insertFront(size_t R)(T[R] el)
    {
        return insertFront!(T[])(el[]);
    }

    ///
    @safe @nogc unittest
    {
        DList!int l1;

        assert(l1.insertFront(8) == 1);
        assert(l1.front == 8);
        assert(l1.back == 8);
        assert(l1.insertFront(9) == 1);
        assert(l1.front == 9);
        assert(l1.back == 8);

        DList!int l2;
        assert(l2.insertFront([25, 30, 15]) == 3);
        assert(l2.front == 25);
        assert(l2.back == 15);

        l2.insertFront(l1[]);
        assert(l2.length == 5);
        assert(l2.front == 9);
        assert(l2.back == 15);
    }

    private size_t moveBack(R)(ref Entry* tail, ref R el) @trusted
    if (isImplicitlyConvertible!(R, T))
    {
        auto temp = cast(Entry*) allocator.allocate(Entry.sizeof);

        el.moveEmplace(temp.content);
        temp.prev = tail;
        if (this.head is null)
        {
            temp.next = null;
            this.head = this.tail = temp;
        }
        else
        {
            temp.next = tail.next;
            tail.next = temp;
        }

        tail = temp;
        return 1;
    }

    /**
     * Inserts a new element at the end.
     *
     * Params:
     *  R  = Type of the inserted value(s).
     *  el = New element(s).
     *
     * Returns: The number of elements inserted.
     */
    size_t insertBack(R)(R el) @trusted
    if (isImplicitlyConvertible!(R, T))
    {
        return moveBack(this.tail, el);
    }

    /// Ditto.
    size_t insertBack(R)(ref R el) @trusted
    if (isImplicitlyConvertible!(R, T))
    {
        if (this.tail is null)
        {
            this.head = this.tail = allocator.make!Entry(el);
        }
        else
        {
            this.tail.next = allocator.make!Entry(el, null, this.tail);
            this.tail = this.tail.next;
        }
        return 1;
    }

    ///
    unittest
    {
        DList!int l;
        int value = 5;

        l.insertBack(value);
        assert(l.front == value);
        assert(l.back == value);

        value = 8;
        l.insertBack(value);
        assert(l.front == 5);
        assert(l.back == value);
    }

    /// Ditto.
    size_t insertBack(R)(R el) @trusted
    if (!isInfinite!R
     && isInputRange!R
     && isImplicitlyConvertible!(ElementType!R, T))
    {
        Entry* begin, end;
        const inserted = makeList(el, begin, end);

        if (this.tail is null)
        {
            this.head = begin;
        }
		else
		{
            this.tail.next = begin;
		}
        if (begin !is null)
        {
            this.tail = end;
        }

        return inserted;
    }

    /// Ditto.
    size_t insertBack(size_t R)(T[R] el)
    {
        return insertBack!(T[])(el[]);
    }

    ///
    @safe @nogc unittest
    {
        DList!int l1;

        assert(l1.insertBack(8) == 1);
        assert(l1.back == 8);
        assert(l1.insertBack(9) == 1);
        assert(l1.back == 9);

        DList!int l2;
        assert(l2.insertBack([25, 30, 15]) == 3);
        assert(l2.back == 15);

        l2.insertBack(l1[]);
        assert(l2.length == 5);
        assert(l2.back == 9);
    }

    /// Ditto.
    alias insert = insertBack;

    version (assert)
    {
        private bool checkRangeBelonging(ref Range r) const
        {
            const(Entry*)* pos = &this.head;
            for (; pos != r.head && *pos !is null; pos = &(*pos).next)
            {
            }
            return pos == r.head;
        }
    }

    /**
     * Inserts new elements before $(D_PARAM r).
     *
     * Params:
     *  R  = Type of the inserted value(s).
     *  r  = Range extracted from this list.
     *  el = New element(s).
     *
     * Returns: The number of elements inserted.
     *
     * Precondition: $(D_PARAM r) is extracted from this list.
     */
    size_t insertBefore(R)(Range r, R el)
    if (isImplicitlyConvertible!(R, T))
    in
    {
        assert(checkRangeBelonging(r));
    }
    body
    {
        return moveFront(*r.head, el);
    }

    ///
    @safe @nogc unittest
    {
        auto l1 = DList!int([234, 5, 1]);
        auto l2 = DList!int([5, 1]);
        l2.insertBefore(l2[], 234);
        assert(l1 == l2);
    }

    /// Ditto.
    size_t insertBefore(Range r, ref T el) @trusted
    in
    {
        assert(checkRangeBelonging(r));
    }
    body
    {
        auto temp = allocator.make!Entry(el, *r.head);

        if (this.tail is null)
        {
            this.tail = temp;
        }
        else
        {
            temp.prev = (*r.head).prev;
            (*r.head).prev = temp;
        }

        *r.head = temp;
        return 1;
    }

    ///
    @safe @nogc unittest
    {
        auto l1 = DList!int([234, 5, 1]);
        auto l2 = DList!int([5, 1]);
        int var = 234;

        l2.insertBefore(l2[], var);
        assert(l1 == l2);
    }

    /// Ditto.
    size_t insertBefore(R)(Range r, R el)
    if (!isInfinite!R
     && isInputRange!R
     && isImplicitlyConvertible!(ElementType!R, T))
    in
    {
        assert(checkRangeBelonging(r));
    }
    body
    {
        size_t inserted;
        foreach (e; el)
        {
            inserted += insertBefore(r, e);
            r.popFront();
        }
        return inserted;
    }

    ///
    @safe @nogc unittest
    {
        auto l1 = DList!int([5, 234, 30, 1]);
        auto l2 = DList!int([5, 1]);
        auto r = l2[];
        r.popFront();
        l2.insertBefore(r, [234, 30]);
        assert(l1 == l2);
    }

    /**
     * Inserts elements from a static array before $(D_PARAM r).
     *
     * Params:
     *  R  = Static array size.
     *  r  = Range extracted from this list.
     *  el = New elements.
     *
     * Returns: The number of elements inserted.
     *
     * Precondition: $(D_PARAM r) is extracted from this list.
     */
    size_t insertBefore(size_t R)(Range r, T[R] el)
    {
        return insertBefore!(T[])(r, el[]);
    }

    /**
     * Inserts new elements after $(D_PARAM r).
     *
     * Params:
     *  R  = Type of the inserted value(s).
     *  r  = Range extracted from this list.
     *  el = New element(s).
     *
     * Returns: The number of elements inserted.
     *
     * Precondition: $(D_PARAM r) is extracted from this list.
     */
    size_t insertAfter(R)(Range r, R el) @trusted
    if (isImplicitlyConvertible!(R, T))
    in
    {
        assert(checkRangeBelonging(r));
    }
    body
    {
        return moveBack(*r.tail, el);
    }

    ///
    @safe @nogc unittest
    {
        auto l1 = DList!int([5, 234, 1]);
        auto l2 = DList!int([5, 1]);
        auto r = l2[];
        r.popBack();
        l2.insertAfter(r, 234);
        assert(l1 == l2);
    }

    private @safe @nogc unittest
    {
        DList!int l;
        l.insertAfter(l[], 234);
        assert(l.front == 234);
        assert(l.back == 234);
        assert(l.length == 1);
    }

    /// Ditto.
    size_t insertAfter(Range r, ref T el) @trusted
    in
    {
        assert(checkRangeBelonging(r));
    }
    body
    {
        auto temp = allocator.make!Entry(el, null, *r.tail);

        if (this.head is null)
        {
            this.head = temp;
        }
        else
        {
            temp.next = (*r.tail).next;
            (*r.tail).next = temp;
        }

        *r.tail = temp;
        return 1;
    }

    ///
    @safe @nogc unittest
    {
        auto l1 = DList!int([5, 1, 234]);
        auto l2 = DList!int([5, 1]);
        int var = 234;

        l2.insertAfter(l2[], var);
        assert(l1 == l2);
    }

    /// Ditto.
    size_t insertAfter(R)(Range r, R el)
    if (!isInfinite!R
     && isInputRange!R
     && isImplicitlyConvertible!(ElementType!R, T))
    in
    {
        assert(checkRangeBelonging(r));
    }
    body
    {
        size_t inserted;
        foreach (e; el)
        {
            inserted += insertAfter(r, e);
        }
        return inserted;
    }

    ///
    @safe @nogc unittest
    {
        auto l1 = DList!int([5, 234, 30, 1]);
        auto l2 = DList!int([5, 1]);
        auto r = l2[];

        r.popBack();
        l2.insertAfter(r, [234, 30]);
        assert(l1 == l2);
    }

    /**
     * Inserts elements from a static array after $(D_PARAM r).
     *
     * Params:
     *  R  = Static array size.
     *  r  = Range extracted from this list.
     *  el = New elements.
     *
     * Returns: The number of elements inserted.
     *
     * Precondition: $(D_PARAM r) is extracted from this list.
     */
    size_t insertAfter(size_t R)(Range r, T[R] el)
    {
        return insertAfter!(T[])(r, el[]);
    }

    /**
     * Returns: How many elements are in the list.
     */
    @property size_t length() const
    {
        return count(this[]);
    }

    ///
    @safe @nogc unittest
    {
        DList!int l;

        l.insertFront(8);
        l.insertFront(9);
        assert(l.length == 2);
        l.removeFront();
        assert(l.length == 1);
        l.removeFront();
        assert(l.length == 0);
    }

    /**
     * Comparison for equality.
     *
     * Params:
     *  that = The list to compare with.
     *
     * Returns: $(D_KEYWORD true) if the lists are equal, $(D_KEYWORD false)
     *          otherwise.
     */
    bool opEquals()(auto ref typeof(this) that) inout
    {
        return equal(this[], that[]);
    }

    ///
    @safe @nogc unittest
    {
        DList!int l1, l2;

        l1.insertFront(8);
        l1.insertFront(9);
        l2.insertFront(8);
        l2.insertFront(10);
        assert(l1 != l2);

        l1.removeFront();
        assert(l1 != l2);

        l2.removeFront();
        assert(l1 == l2);

        l1.removeFront();
        assert(l1 != l2);

        l2.removeFront();
        assert(l1 == l2);
    }

    /**
     * Returns: $(D_KEYWORD true) if the list is empty.
     */
    @property bool empty() const
    {
        return this.head is null;
    }

    /**
     * Removes the front or back element.
     *
     * Precondition: $(D_INLINECODE !empty)
     */
    void removeFront()
    in
    {
        assert(!empty);
    }
    body
    {
        auto n = this.head.next;

        allocator.dispose(this.head);
        this.head = n;
        if (this.head is null)
        {
            this.tail = null;
        }
        else
        {
            this.head.prev = null;
        }
    }

    ///
    @safe @nogc unittest
    {
        DList!int l;

        l.insertFront(8);
        l.insertFront(9);
        assert(l.front == 9);
        l.removeFront();
        assert(l.front == 8);
        l.removeFront();
        assert(l.empty);
    }

    /// Ditto.
    void removeBack()
    in
    {
        assert(!empty);
    }
    body
    {
        auto n = this.tail.prev;

        allocator.dispose(this.tail);
        this.tail = n;
        if (this.tail is null)
        {
            this.head = null;
        }
        else
        {
            this.tail.next = null;
        }
    }

    ///
    @safe @nogc unittest
    {
        auto l = DList!int([9, 8]);

        assert(l.back == 8);
        l.removeBack();
        assert(l.back == 9);
        l.removeFront();
        assert(l.empty);
    }

    /**
     * Removes $(D_PARAM howMany) elements from the list.
     *
     * Unlike $(D_PSYMBOL removeFront()) and $(D_PSYMBOL removeBack()), this
     * method doesn't fail, if it could not remove $(D_PARAM howMany) elements.
     * Instead, if $(D_PARAM howMany) is greater than the list length, all
     * elements are removed.
     *
     * Params:
     *  howMany = How many elements should be removed.
     *
     * Returns: The number of elements removed.
     */
    size_t removeFront(const size_t howMany)
    out (removed)
    {
        assert(removed <= howMany);
    }
    body
    {
        size_t i;
        for (; i < howMany && !empty; ++i)
        {
            removeFront();
        }
        return i;
    }

    ///
    @safe @nogc unittest
    {
        DList!int l = DList!int([8, 5, 4]);

        assert(l.removeFront(0) == 0);
        assert(l.removeFront(2) == 2);
        assert(l.removeFront(3) == 1);
        assert(l.removeFront(3) == 0);
    }

    /// Ditto.
    size_t removeBack(const size_t howMany)
    out (removed)
    {
        assert(removed <= howMany);
    }
    body
    {
        size_t i;
        for (; i < howMany && !empty; ++i)
        {
            removeBack();
        }
        return i;
    }

    ///
    @safe @nogc unittest
    {
        DList!int l = DList!int([8, 5, 4]);

        assert(l.removeBack(0) == 0);
        assert(l.removeBack(2) == 2);
        assert(l.removeBack(3) == 1);
        assert(l.removeBack(3) == 0);
    }

    /**
     * Removes $(D_PARAM r) from the list.
     *
     * Params:
     *  r = The range to remove.
     *
     * Returns: Range spanning the elements just after $(D_PARAM r).
     *
     * Precondition: $(D_PARAM r) is extracted from this list.
     */
    Range remove(Range r)
    in
    {
        assert(checkRangeBelonging(r));
    }
    body
    {
        // Save references to the elements before and after the range.
        Entry* tailNext, headPrev;
        if (*r.tail !is null && (*r.tail).next !is null)
        {
            tailNext = (*r.tail).next;
        }
        if (*r.head !is null)
        {
            headPrev = (*r.head).prev;
        }

        // Remove the elements.
        Entry* e = *r.head;
        while (e !is tailNext)
        {
            auto next = e.next;
            allocator.dispose(e);
            e = next;
        }

        // Connect the elements before and after the removed range.
        if (tailNext !is null)
        {
            tailNext.prev = headPrev;
        }
        *r.head = tailNext;
        *r.tail = tail;

        return r;
    }

    ///
    @safe @nogc unittest
    {
        auto l1 = DList!int([5, 234, 30, 1]);
        auto l2 = DList!int([5]);
        auto r = l1[];

        r.popFront();

        assert(l1.remove(r).empty);
        assert(l1 == l2);
    }

    // Issue 260: https://issues.caraus.io/issues/260.
    private @safe @nogc unittest
    {
        auto l1 = DList!int([5, 234, 30, 1]);
        auto l2 = DList!int([5, 1]);
        auto r = l1[];

        r.popFront();
        r.popBack();
        assert(r.front == 234);
        assert(r.back == 30);

        assert(!l1.remove(r).empty);
        assert(l1 == l2);
    }

    /**
     * Returns: Range that iterates over all elements of the container, in
     *          forward order.
     */
    Range opIndex()
    {
        return typeof(return)(this.head, this.tail);
    }

    /// Ditto.
    ConstRange opIndex() const
    {
        return typeof(return)(this.head, this.tail);
    }

    /**
     * Assigns another list.
     *
     * If $(D_PARAM that) is passed by value, it won't be copied, but moved.
     * This list will take the ownership over $(D_PARAM that)'s storage and
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
    if (is(Unqual!R == DList))
    {
        return this = that[];
    }

    /// Ditto.
    ref typeof(this) opAssign(R)(R that)
    if (is(R == DList))
    {
        swap(this.head, that.head);
        swap(this.tail, that.tail);
        swap(this.allocator_, that.allocator_);
        return this;
    }

    /**
     * Assigns an input range.
     *
     * Params:
     *  R    = Type of the initial range.
     *  that = Values to initialize the list with.
     *
     * Returns: $(D_KEYWORD this).
     */
    ref typeof(this) opAssign(R)(R that) @trusted
    if (!isInfinite!R
     && isInputRange!R
     && isImplicitlyConvertible!(ElementType!R, T))
    {
        Entry** next = &this.head;

        while (!that.empty && *next !is null)
        {
            (*next).content = that.front;
            next = &(*next).next;
            that.popFront();
        }
        if (that.empty)
        {
            remove(Range(*next, this.tail));
        }
        else
        {
            insertBack(that);
        }
        return this;
    }

    ///
    @safe @nogc unittest
    {
        auto l1 = DList!int([5, 4, 9]);
        auto l2 = DList!int([9, 4]);
        l1 = l2[];
        assert(l1 == l2);
    }

    private @safe @nogc unittest
    {
        auto l1 = DList!int();
        auto l2 = DList!int([9, 4]);
        l1 = l2[];
        assert(l1 == l2);
    }

    /**
     * Assigns a static array.
     *
     * Params:
     *  R    = Static array size.
     *  that = Values to initialize the list with.
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
        auto l1 = DList!int([5, 4, 9]);
        auto l2 = DList!int([9, 4]);
        l1 = [9, 4];
        assert(l1 == l2);
    }

    mixin DefaultAllocator;
}

///
@nogc unittest
{
    DList!int l;
    size_t i;

    l.insertFront(5);
    l.insertFront(4);
    l.insertFront(9);
    foreach (e; l)
    {
        assert(i != 0 || e == 9);
        assert(i != 1 || e == 4);
        assert(i != 2 || e == 5);
        ++i;
    }
    assert(i == 3);
}

// Issue 232: https://issues.caraus.io/issues/232.
private @nogc unittest
{
    class A
    {
    }
    static assert(is(SList!(A*)));
    static assert(is(DList!(A*)));
}
