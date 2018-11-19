/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Algorithms that modify its arguments.
 *
 * Copyright: Eugene Wissner 2017-2018.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/algorithm/mutation.d,
 *                 tanya/algorithm/mutation.d)
 */
module tanya.algorithm.mutation;

import tanya.conv;
static import tanya.memory.op;
import tanya.meta.trait;
import tanya.meta.transform;
import tanya.range;
version (unittest) import tanya.test.stub;

private void deinitialize(bool zero, T)(ref T value)
{
    static if (is(T == U[S], U, size_t S))
    {
        foreach (ref e; value)
        {
            deinitialize!zero(e);
        }
    }
    else
    {
        static if (isNested!T)
        {
            // Don't override the context pointer.
            enum size_t size = T.sizeof - (void*).sizeof;
        }
        else
        {
            enum size_t size = T.sizeof;
        }
        static if (zero)
        {
            tanya.memory.op.fill!0((cast(void*) &value)[0 .. size]);
        }
        else
        {
            tanya.memory.op.copy(typeid(T).initializer()[0 .. size],
                                 (&value)[0 .. 1]);
        }
    }
}

/**
 * Moves $(D_PARAM source) into $(D_PARAM target) assuming that
 * $(D_PARAM target) isn't initialized.
 *
 * Moving the $(D_PARAM source) copies it into the $(D_PARAM target) and places
 * the $(D_PARAM source) into a valid but unspecified state, which means that
 * after moving $(D_PARAM source) can be destroyed or assigned a new value, but
 * accessing it yields an unspecified value. No postblits or destructors are
 * called. If the $(D_PARAM target) should be destroyed before, use
 * $(D_PSYMBOL move).
 *
 * $(D_PARAM source) and $(D_PARAM target) must be different objects.
 *
 * Params:
 *  T      = Object type.
 *  source = Source object.
 *  target = Target object.
 *
 * See_Also: $(D_PSYMBOL move),
 *           $(D_PSYMBOL hasElaborateCopyConstructor),
 *           $(D_PSYMBOL hasElaborateDestructor).
 *
 * Precondition: `&source !is &target`.
 */
void moveEmplace(T)(ref T source, ref T target) @system
in
{
    assert(&source !is &target, "Source and target must be different");
}
do
{
    static if (is(T == struct) || isStaticArray!T)
    {
        tanya.memory.op.copy((&source)[0 .. 1], (&target)[0 .. 1]);

        static if (hasElaborateCopyConstructor!T || hasElaborateDestructor!T)
        {
            static if (__VERSION__ >= 2083) // __traits(isZeroInit) available.
            {
                deinitialize!(__traits(isZeroInit, T))(source);
            }
            else
            {
                if (typeid(T).initializer().ptr is null)
                {
                    deinitialize!true(source);
                }
                else
                {
                    deinitialize!false(source);
                }
            }
        }
    }
    else
    {
        target = source;
    }
}

///
@nogc nothrow pure @system unittest
{
    static struct S
    {
        int member = 5;

        this(this) @nogc nothrow pure @safe
        {
            assert(false);
        }
    }
    S source, target = void;
    moveEmplace(source, target);
    assert(target.member == 5);

    int x1 = 5, x2;
    moveEmplace(x1, x2);
    assert(x2 == 5);
}

// Is pure.
@nogc nothrow pure @system unittest
{
    struct S
    {
        this(this)
        {
        }
    }
    S source, target = void;
    static assert(is(typeof({ moveEmplace(source, target); })));
}

// Moves nested.
@nogc nothrow pure @system unittest
{
    struct Nested
    {
        void method() @nogc nothrow pure @safe
        {
        }
    }
    Nested source, target = void;
    moveEmplace(source, target);
    assert(source == target);
}

// Emplaces static arrays.
@nogc nothrow pure @system unittest
{
    static struct S
    {
        size_t member;
        this(size_t i) @nogc nothrow pure @safe
        {
            this.member = i;
        }
        ~this() @nogc nothrow pure @safe
        {
        }
    }
    S[2] source = [ S(5), S(5) ], target = void;
    moveEmplace(source, target);
    assert(source[0].member == 0);
    assert(target[0].member == 5);
    assert(source[1].member == 0);
    assert(target[1].member == 5);
}

/**
 * Moves $(D_PARAM source) into $(D_PARAM target) assuming that
 * $(D_PARAM target) isn't initialized.
 *
 * Moving the $(D_PARAM source) copies it into the $(D_PARAM target) and places
 * the $(D_PARAM source) into a valid but unspecified state, which means that
 * after moving $(D_PARAM source) can be destroyed or assigned a new value, but
 * accessing it yields an unspecified value. $(D_PARAM target) is destroyed before
 * the new value is assigned. If $(D_PARAM target) isn't initialized and
 * therefore shouldn't be destroyed, $(D_PSYMBOL moveEmplace) can be used.
 *
 * If $(D_PARAM target) isn't specified, $(D_PSYMBOL move) returns the source
 * as rvalue without calling its copy constructor or destructor.
 *
 * $(D_PARAM source) and $(D_PARAM target) are the same object,
 * $(D_PSYMBOL move) does nothing.
 *
 * Params:
 *  T      = Object type.
 *  source = Source object.
 *  target = Target object.
 *
 * See_Also: $(D_PSYMBOL moveEmplace).
 */
void move(T)(ref T source, ref T target)
{
    if ((() @trusted => &source is &target)())
    {
        return;
    }
    static if (hasElaborateDestructor!T)
    {
        target.__xdtor();
    }
    (() @trusted => moveEmplace(source, target))();
}

/// ditto
T move(T)(ref T source) @trusted
{
    T target = void;
    moveEmplace(source, target);
    return target;
}

///
@nogc nothrow pure @safe unittest
{
    static struct S
    {
        int member = 5;

        this(this) @nogc nothrow pure @safe
        {
            assert(false);
        }
    }
    S source, target = void;
    move(source, target);
    assert(target.member == 5);
    assert(move(target).member == 5);

    int x1 = 5, x2;
    move(x1, x2);
    assert(x2 == 5);
    assert(move(x2) == 5);
}

// Moves if source is target.
@nogc nothrow pure @safe unittest
{
    int x = 5;
    move(x, x);
    assert(x == 5);
}

/**
 * Exchanges the values of $(D_PARAM a) and $(D_PARAM b).
 *
 * $(D_PSYMBOL swap) moves the contents of $(D_PARAM a) and $(D_PARAM b)
 * without calling its postblits or destructors.
 *
 * Params:
 *  a = The first object.
 *  b = The second object.
 */
void swap(T)(ref T a, ref T b) @trusted
{
    T tmp = void;
    moveEmplace(a, tmp);
    moveEmplace(b, a);
    moveEmplace(tmp, b);
}

///
@nogc nothrow pure @safe unittest
{
    int a = 3, b = 5;
    swap(a, b);
    assert(a == 5);
    assert(b == 3);
}

/**
 * Copies the $(D_PARAM source) range into the $(D_PARAM target) range.
 *
 * Params:
 *  Source = Input range type.
 *  Target = Output range type.
 *  source = Source input range.
 *  target = Target output range.
 *
 * Returns: $(D_PARAM target) range, whose front element is the one past the
 *          last element copied.
 *
 * Precondition: $(D_PARAM target) should be large enough to accept all
 *               $(D_PARAM source) elements.
 */
Target copy(Source, Target)(Source source, Target target)
if (isInputRange!Source && isOutputRange!(Target, Source))
in
{
    static if (hasLength!Source && hasLength!Target)
    {
        assert(target.length >= source.length);
    }
}
do
{
    alias E = ElementType!Source;
    static if (isDynamicArray!Source
            && is(Unqual!E == ElementType!Target)
            && !hasElaborateCopyConstructor!E
            && !hasElaborateAssign!E
            && !hasElaborateDestructor!E)
    {
        if (source.ptr < target.ptr
         && (() @trusted => (target.ptr - source.ptr) < source.length)())
        {
            tanya.memory.op.copyBackward(source, target);
        }
        else if (source.ptr !is target.ptr)
        {
            tanya.memory.op.copy(source, target);
        }
        return target[source.length .. $];
    }
    else
    {
        for (; !source.empty; source.popFront())
        {
            put(target, source.front);
        }
        return target;
    }
}

///
@nogc nothrow pure @safe unittest
{
    import tanya.algorithm.comparison : equal;

    const int[2] source = [1, 2];
    int[2] target = [3, 4];

    copy(source[], target[]);
    assert(equal(source[], target[]));
}

// Returns advanced target
@nogc nothrow pure @safe unittest
{
    int[5] input = [1, 2, 3, 4, 5];
    assert(copy(input[3 .. 5], input[]).front == 3);
}

// Copies overlapping arrays
@nogc nothrow pure @safe unittest
{
    import tanya.algorithm.comparison : equal;

    int[6] actual = [1, 2, 3, 4, 5, 6];
    const int[6] expected = [1, 2, 1, 2, 3, 4];

    copy(actual[0 .. 4], actual[2 .. 6]);
    assert(equal(actual[], expected[]));
}

@nogc nothrow pure @safe unittest
{
    static assert(is(typeof(copy((ubyte[]).init, (ushort[]).init))));
    static assert(!is(typeof(copy((ushort[]).init, (ubyte[]).init))));
}

@nogc nothrow pure @safe unittest
{
    static struct OutPutRange
    {
        int value;
        void put(int value) @nogc nothrow pure @safe
        in
        {
            assert(this.value == 0);
        }
        do
        {
            this.value = value;
        }
    }
    int[1] source = [5];
    OutPutRange target;

    assert(copy(source[], target).value == 5);
}

/**
 * Fills $(D_PARAM range) with $(D_PARAM value).
 *
 * Params:
 *  Range = Input range type.
 *  Value = Filler type.
 *  range = Input range.
 *  value = Filler.
 */
void fill(Range, Value)(Range range, auto ref Value value)
if (isInputRange!Range && isAssignable!(ElementType!Range, Value))
{
    static if (!isDynamicArray!Range && is(typeof(range[] = value)))
    {
        range[] = value;
    }
    else
    {
        for (; !range.empty; range.popFront())
        {
            range.front = value;
        }
    }
}

///
@nogc nothrow pure @safe unittest
{
    import tanya.algorithm.comparison : equal;

    int[6] actual;
    const int[6] expected = [1, 1, 1, 1, 1, 1];

    fill(actual[], 1);
    assert(equal(actual[], expected[]));
}

// [] is called where possible
@nogc nothrow pure @system unittest
{
    static struct Slice
    {
        bool* slicingCalled;

        int front() @nogc nothrow pure @safe
        {
            return 0;
        }

        void front(int) @nogc nothrow pure @safe
        {
        }

        void popFront() @nogc nothrow pure @safe
        {
        }

        bool empty() @nogc nothrow pure @safe
        {
            return true;
        }

        void opIndexAssign(int) @nogc nothrow pure @safe
        {
            *this.slicingCalled = true;
        }
    }
    bool slicingCalled;
    auto range = Slice(&slicingCalled);
    fill(range, 0);
    assert(slicingCalled);
}

/**
 * Fills $(D_PARAM range) with $(D_PARAM value) assuming the elements of the
 * $(D_PARAM range) aren't initialized.
 *
 * Params:
 *  Range = Input range type.
 *  Value = Initializer type.
 *  range = Input range.
 *  value = Initializer.
 */
void uninitializedFill(Range, Value)(Range range, auto ref Value value)
if (isInputRange!Range && hasLvalueElements!Range
 && isAssignable!(ElementType!Range, Value))
{
    static if (hasElaborateDestructor!(ElementType!Range))
    {
        for (; !range.empty; range.popFront())
        {
            ElementType!Range* p = &range.front;
            emplace!(ElementType!Range)(cast(void[]) (p[0 .. 1]), value);
        }
    }
    else
    {
        fill(range, value);
    }
}

///
@nogc nothrow pure @safe unittest
{
    import tanya.algorithm.comparison : equal;

    int[6] actual = void;
    const int[6] expected = [1, 1, 1, 1, 1, 1];

    uninitializedFill(actual[], 1);
    assert(equal(actual[], expected[]));
}

/**
 * Initializes all elements of the $(D_PARAM range) assuming that they are
 * uninitialized.
 *
 * Params:
 *  Range = Input range type
 *  range = Input range.
 */
void initializeAll(Range)(Range range) @trusted
if (isInputRange!Range && hasLvalueElements!Range)
{
    import tanya.memory.op : copy, fill;
    alias T = ElementType!Range;

    static if (__VERSION__ >= 2083
            && isDynamicArray!Range
            && __traits(isZeroInit, T))
    {
        fill!0(range);
    }
    else
    {
        static immutable init = T.init;
        for (; !range.empty; range.popFront())
        {
            copy((&init)[0 .. 1], (&range.front)[0 .. 1]);
        }
    }
}

///
@nogc nothrow pure @safe unittest
{
    import tanya.algorithm.comparison : equal;

    int[2] actual = void;
    const int[2] expected = [0, 0];

    initializeAll(actual[]);
    assert(equal(actual[], expected[]));
}

@nogc nothrow pure @safe unittest
{
    NonCopyable[] nonCopyable;
    initializeAll(nonCopyable);
}

/**
 * Destroys all elements in the $(D_PARAM range).
 *
 * This function has effect only if the element type of $(D_PARAM Range) has
 * an elaborate destructor, i.e. it is a $(D_PSYMBOL struct) with an explicit
 * or generated by the compiler destructor.
 *
 * Params:
 *  Range = Input range type.
 *  range = Input range.
 */
void destroyAll(Range)(Range range)
if (isInputRange!Range && hasLvalueElements!Range)
{
    static if (hasElaborateDestructor!(ElementType!Range))
    {
        foreach (ref e; range)
        {
            destroy(e);
        }
    }
}

///
@nogc nothrow pure @trusted unittest
{
    static struct WithDtor
    {
        private size_t* counter;
        ~this() @nogc nothrow pure
        {
            if (this.counter !is null)
            {
                ++(*this.counter);
            }
        }
    }

    size_t counter;
    WithDtor[2] withDtor = [WithDtor(&counter), WithDtor(&counter)];

    destroyAll(withDtor[]);

    assert(counter == 2);
}

/**
 * Rotates the elements of a union of two ranges.
 *
 * Performs a left rotation on the given ranges, as if it would be a signle
 * range, so that [`front.front`, `back.front`$(RPAREN) is a valid range, that
 * is $(D_PARAM back) would continue $(D_PARAM front).
 *
 * The elements are moved so, that the first element of $(D_PARAM back) becomes
 * the first element of $(D_PARAM front) without changing the relative order of
 * their elements.
 *
 * Params:
 *  Range = Range type.
 *  front = Left half.
 *  back  = Right half.
 */
void rotate(Range)(Range front, Range back)
if (isForwardRange!Range && hasSwappableElements!Range)
{
    auto next = back.save();

    while (!front.empty && !next.empty && !sameHead(front, next))
    {
        swap(front.front, next.front);
        front.popFront();
        next.popFront();

        if (next.empty)
        {
            next = back.save();
        }
        else if (front.empty)
        {
            front = back.save();
            back = next.save();
        }
    }
}

///
@nogc nothrow pure @safe unittest
{
    import tanya.algorithm.comparison : equal;

    const int[7] expected = [1, 2, 3, 4, 5, 6, 7];
    int[7] actual = [5, 6, 3, 4, 1, 2, 7];

    rotate(actual[0 .. 2], actual[4 .. 6]);
    assert(equal(actual[], expected[]));
}

@nogc nothrow pure @safe unittest
{
    import tanya.algorithm.comparison : equal;

    const int[5] expected = [1, 2, 3, 4, 5];
    int[5] actual = [4, 5, 1, 2, 3];

    rotate(actual[0 .. 2], actual[2 .. $]);
    assert(equal(actual[], expected[]));
}

// Doesn't cause an infinite loop if back is shorter than the front
@nogc nothrow pure @safe unittest
{
    import tanya.algorithm.comparison : equal;

    const int[5] expected = [1, 2, 3, 4, 5];
    int[5] actual = [3, 4, 5, 1, 2];

    rotate(actual[0 .. 3], actual[3 .. $]);
    assert(equal(actual[], expected[]));
}

// Doesn't call .front on an empty front
@nogc nothrow pure @safe unittest
{
    import tanya.algorithm.comparison : equal;

    const int[2] expected = [2, 8];
    int[2] actual = expected;

    rotate(actual[0 .. 0], actual[]);
    assert(equal(actual[], expected[]));
}
