/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Algorithms that modify its arguments.
 *
 * Copyright: Eugene Wissner 2017-2020.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/algorithm/mutation.d,
 *                 tanya/algorithm/mutation.d)
 */
module tanya.algorithm.mutation;

static import tanya.memory.lifetime;
static import tanya.memory.op;
import tanya.meta.trait;
import tanya.meta.transform;
import tanya.range;

deprecated("Use tanya.memory.lifetime.swap instead")
alias swap = tanya.memory.lifetime.swap;

deprecated("Use tanya.memory.lifetime.moveEmplace instead")
alias moveEmplace = tanya.memory.lifetime.moveEmplace;

deprecated("Use tanya.memory.lifetime.move instead")
alias move = tanya.memory.lifetime.move;

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
if (isInputRange!Source && isOutputRange!(Target, ElementType!Source))
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
            tanya.memory.lifetime.emplace!(ElementType!Range)(cast(void[]) (p[0 .. 1]), value);
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
    tanya.memory.lifetime.destroyAllImpl!(Range, ElementType!Range)(range);
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
        tanya.memory.lifetime.swap(front.front, next.front);
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
