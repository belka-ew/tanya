/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * This module is suited for computations on template arguments, both types and
 * values at compile time.
 *
 * It contains different algorithms for iterating, searching and modifying
 * template arguments.
 *
 * Copyright: Eugene Wissner 2017-2019.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/meta/tanya/meta/metafunction.d,
 *                 tanya/meta/metafunction.d)
 */
module tanya.meta.metafunction;

import tanya.meta.trait;
import tanya.meta.transform;

/**
 * Finds the minimum value in $(D_PARAM Args) according to $(D_PARAM pred).
 *
 * $(D_PARAM Args) should contain at least one element.
 *
 * $(D_PARAM pred) can evaluate to:
 * $(UL
 *  $(LI $(D_KEYWORD bool): $(D_KEYWORD true) means
 *       $(D_INLINECODE Args[0] < Args[1]).)
 *  $(LI $(D_KEYWORD int): a negative number means that
 *       $(D_INLINECODE Args[0] < Args[1]), a positive number that
 *       $(D_INLINECODE Args[0] > Args[1]), `0` if they equal.)
 * )
 * 
 * Params:
 *  pred = Template predicate.
 *  Args = Elements for which you want to find the minimum value.
 *
 * Returns: The minimum.
 *
 * See_Also: $(D_PSYMBOL isLess).
 */
template Min(alias pred, Args...)
if (Args.length > 0 && __traits(isTemplate, pred))
{
    static if (Args.length == 1)
    {
        alias Min = Alias!(Args[0]);
    }
    else static if (isLess!(pred, Args[1], Args[0]))
    {
        alias Min = Min!(pred, Args[1], Args[2 .. $]);
    }
    else
    {
        alias Min = Min!(pred, Args[0], Args[2 .. $]);
    }
}

///
@nogc nothrow pure @safe unittest
{
    enum bool cmp(alias T, alias U) = T < U;
    static assert(Min!(cmp, 8, 4, 5, 3, 13) == 3);
    static assert(Min!(cmp, 8) == 8);
}

/**
 * Finds the maximum value in $(D_PARAM Args) according to $(D_PARAM pred).
 *
 * $(D_PARAM Args) should contain at least one element.
 *
 * $(D_PARAM pred) can evaluate to:
 * $(UL
 *  $(LI $(D_KEYWORD bool): $(D_KEYWORD true) means
 *       $(D_INLINECODE Args[0] < Args[1]).)
 *  $(LI $(D_KEYWORD int): a negative number means that
 *       $(D_INLINECODE Args[0] < Args[1]), a positive number that
 *       $(D_INLINECODE Args[0] > Args[1]), `0` if they equal.)
 * )
 * 
 * Params:
 *  pred = Template predicate.
 *  Args = Elements for which you want to find the maximum value.
 *
 * Returns: The maximum.
 *
 * See_Also: $(D_PSYMBOL isLess).
 */
template Max(alias pred, Args...)
if (Args.length > 0 && __traits(isTemplate, pred))
{
    static if (Args.length == 1)
    {
        alias Max = Alias!(Args[0]);
    }
    else static if (isGreater!(pred, Args[1], Args[0]))
    {
        alias Max = Max!(pred, Args[1], Args[2 .. $]);
    }
    else
    {
        alias Max = Max!(pred, Args[0], Args[2 .. $]);
    }
}

///
@nogc nothrow pure @safe unittest
{
    enum bool cmp(alias T, alias U) = T < U;
    static assert(Max!(cmp, 8, 4, 5, 3, 13) == 13);
    static assert(Max!(cmp, 8) == 8);
}

/**
 * Zips one or more $(D_PSYMBOL Pack)s with $(D_PARAM f).
 *
 * Given $(D_PARAM f) and tuples t1, t2, ..., tk, where tk[i] denotes the
 * $(I i)-th element of the tuple $(I k)-th tuple, $(D_PSYMBOL ZipWith)
 * produces a sequence:
 *
 * ---
 * f(t1[0], t2[0], ... tk[0]),
 * f(t1[1], t2[1], ... tk[1]),
 * ...
 * f(tk[0], tk[1], ... tk[i]),
 * ---
 *
 * $(D_PSYMBOL ZipWith) begins with the first elements from $(D_PARAM Packs)
 * and applies $(D_PARAM f) to them, then it takes the second
 * ones and does the same, and so on.
 *
 * If not all argument tuples have the same length, $(D_PSYMBOL ZipWith) will
 * zip only `n` elements from each tuple, where `n` is the length of the
 * shortest tuple in the argument list. Remaining elements in the longer tuples
 * are just ignored.
 *
 * Params:
 *  f      = Some template that can be applied to the elements of
 *           $(D_PARAM Packs).
 *  Packs  = $(D_PSYMBOL Pack) instances.
 *
 * Returns: A sequence, whose $(I i)-th element contains the $(I i)-th element
 *          from each of the $(D_PARAM Packs).
 */
template ZipWith(alias f, Packs...)
if (Packs.length > 0
 && __traits(isTemplate, f)
 && (allSatisfy!(ApplyLeft!(isInstanceOf, Pack), Packs)
 || allSatisfy!(ApplyLeft!(isInstanceOf, Tuple), Packs)))
{
    private template GetIth(size_t i, Args...)
    {
        static if ((Args.length == 0) || (Args[0].Seq.length <= i))
        {
            alias GetIth = AliasSeq!();
        }
        else
        {
            alias GetIth = AliasSeq!(Args[0].Seq[i], GetIth!(i, Args[1 .. $]));
        }
    }
    private template Iterate(size_t i, Args...)
    {
        alias Pack = GetIth!(i, Args);

        static if (Pack.length < Packs.length)
        {
            alias Iterate = AliasSeq!();
        }
        else
        {
            alias Iterate = AliasSeq!(f!Pack, Iterate!(i + 1, Args));
        }
    }
    alias ZipWith = Iterate!(0, Packs);
}

///
@nogc nothrow pure @safe unittest
{
    alias Result1 = ZipWith!(AliasSeq, Pack!(1, 2), Pack!(5, 6), Pack!(9, 10));
    static assert(Result1 == AliasSeq!(1, 5, 9, 2, 6, 10));

    alias Result2 = ZipWith!(AliasSeq, Pack!(1, 2, 3), Pack!(4, 5));
    static assert(Result2 == AliasSeq!(1, 4, 2, 5));

    alias Result3 = ZipWith!(AliasSeq, Pack!(), Pack!(4, 5));
    static assert(Result3.length == 0);
}

/**
 * Holds a typed sequence of template parameters.
 *
 * Different than $(D_PSYMBOL AliasSeq), $(D_PSYMBOL Pack) doesn't unpack
 * its template parameters automatically. Consider:
 *
 * ---
 * template A(Args...)
 * {
 *  static assert(Args.length == 4);
 * }
 *
 * alias AInstance = A!(AliasSeq!(int, uint), AliasSeq!(float, double));
 * ---
 *
 * Using $(D_PSYMBOL AliasSeq) template `A` gets 4 parameters instead of 2,
 * because $(D_PSYMBOL AliasSeq) is just an alias for its template parameters.
 *
 * With $(D_PSYMBOL Pack) it is possible to pass distinguishable
 * sequences of parameters to a template. So:
 *
 * ---
 * template B(Args...)
 * {
 *  static assert(Args.length == 2);
 * }
 *
 * alias BInstance = B!(Pack!(int, uint), Pack!(float, double));
 * ---
 *
 * Params:
 *  Args = Elements of this $(D_PSYMBOL Pack).
 *
 * See_Also: $(D_PSYMBOL AliasSeq).
 */
struct Pack(Args...)
{
    /// Elements in this tuple as $(D_PSYMBOL AliasSeq).
    alias Seq = Args;

    /// The length of the tuple.
    enum size_t length = Args.length;

    alias Seq this;
}

///
@nogc nothrow pure @safe unittest
{
    alias A = Pack!short;
    alias B = Pack!(3, 8, 9);
    alias C = Pack!(A, B);

    static assert(C.length == 2);

    static assert(A.length == 1);
    static assert(is(A.Seq == AliasSeq!short));
    static assert(B.length == 3);
    static assert(B.Seq == AliasSeq!(3, 8, 9));

    alias D = Pack!();
    static assert(D.length == 0);
    static assert(is(D.Seq == AliasSeq!()));
}

/**
 * Unordered sequence of unique aliases.
 *
 * $(D_PARAM Args) can contain duplicates, but they will be filtered out, so
 * $(D_PSYMBOL Set) contains only unique items. $(D_PSYMBOL isEqual) is used
 * for determining if two items are equal.
 *
 * Params:
 *  Args = Elements of this $(D_PSYMBOL Set).
 */
struct Set(Args...)
{
    /// Elements in this set as $(D_PSYMBOL AliasSeq).
    alias Seq = NoDuplicates!Args;

    /// The length of the set.
    enum size_t length = Seq.length;

    alias Seq this;
}

///
@nogc nothrow pure @safe unittest
{
    alias S1 = Set!(int, 5, 5, int, 4);
    static assert(S1.length == 3);
}

/**
 * Produces a $(D_PSYMBOL Set) containing all elements of the given
 * $(D_PARAM Sets).
 *
 * Params:
 *  Sets = List of $(D_PSYMBOL Set) instances.
 *
 * Returns: Set-theoretic union of all $(D_PARAM Sets).
 *
 * See_Also: $(D_PSYMBOL Set).
 */
template Union(Sets...)
if (allSatisfy!(ApplyLeft!(isInstanceOf, Set), Sets))
{
    private template Impl(Sets...)
    {
        static if (Sets.length == 0)
        {
            alias Impl = AliasSeq!();
        }
        else
        {
            alias Impl = AliasSeq!(Sets[0].Seq, Impl!(Sets[1 .. $]));
        }
    }
    alias Union = Set!(Impl!Sets);
}

///
@nogc nothrow pure @safe unittest
{
    alias S1 = Set!(2, 5, 8, 4);
    alias S2 = Set!(3, 8, 4, 1);
    static assert(Union!(S1, S2).Seq == AliasSeq!(2, 5, 8, 4, 3, 1));
}

/**
 * Produces a $(D_PSYMBOL Set) that containing elements of
 * $(D_INLINECODE Sets[0]) that are also elements of all other sets in
 * $(D_PARAM Sets).
 *
 * Params:
 *  Sets = List of $(D_PSYMBOL Set) instances.
 *
 * Returns: Set-theoretic intersection of all $(D_PARAM Sets).
 *
 * See_Also: $(D_PSYMBOL Set).
 */
template Intersection(Sets...)
if (allSatisfy!(ApplyLeft!(isInstanceOf, Set), Sets))
{
    private template Impl(Args...)
    if (Args.length > 0)
    {
        alias Equal = ApplyLeft!(isEqual, Args[0]);
        static if (Args.length == 1)
        {
            enum bool Impl = true;
        }
        else static if (!anySatisfy!(Equal, Args[1].Seq))
        {
            enum bool Impl = false;
        }
        else
        {
            enum bool Impl = Impl!(Args[0], Args[2 .. $]);
        }
    }

    private enum bool FilterImpl(Args...) = Impl!(Args[0], Sets[1 .. $]);

    static if (Sets.length == 0)
    {
        alias Intersection = Set!();
    }
    else
    {
        alias Intersection = Set!(Filter!(FilterImpl, Sets[0].Seq));
    }
}

///
@nogc nothrow pure @safe unittest
{
    alias S1 = Set!(2, 5, 8, 4);
    alias S2 = Set!(3, 8, 4, 1);
    static assert(Intersection!(S1, S2).Seq == AliasSeq!(8, 4));

    static assert(Intersection!(S1).Seq == AliasSeq!(2, 5, 8, 4));
    static assert(Intersection!().length == 0);
}

/**
 * Produces a $(D_PSYMBOL Set) that contains all elements of
 * $(D_PARAM S1) that are not members of $(D_PARAM S2).
 *
 * Params:
 *  S1 = A $(D_PSYMBOL Set).
 *  S2 = A $(D_PSYMBOL Set).
 *
 * Returns: Set-theoretic difference of two sets $(D_PARAM S1) and
 *          $(D_PARAM S2).
 *
 * See_Also: $(D_PSYMBOL Set).
 */
template Difference(alias S1, alias S2)
if (isInstanceOf!(Set, S1) && isInstanceOf!(Set, S2))
{
    private template Impl(Args...)
    {
        alias Equal = ApplyLeft!(isEqual, Args[0]);
        enum bool Impl = !anySatisfy!(Equal, S2.Seq);
    }

    static if (S1.length == 0)
    {
        alias Difference = Set!();
    }
    else static if (S2.length == 1)
    {
        alias Difference = S1;
    }
    else
    {
        alias Difference = Set!(Filter!(Impl, S1.Seq));
    }
}

///
@nogc nothrow pure @safe unittest
{
    alias S1 = Set!(2, 5, 8, 4);
    alias S2 = Set!(3, 8, 4, 1);
    static assert(Difference!(S1, S2).Seq == AliasSeq!(2, 5));
    static assert(Difference!(S2, S1).Seq == AliasSeq!(3, 1));
    static assert(Difference!(S1, Set!()).Seq == AliasSeq!(2, 5, 8, 4));
}

/**
 * Tests whether $(D_INLINECODE Args[0]) is less than or equal to
 * $(D_INLINECODE Args[1]) according to $(D_PARAM cmp).
 *
 * $(D_PARAM cmp) can evaluate to:
 * $(UL
 *  $(LI $(D_KEYWORD bool): $(D_KEYWORD true) means
 *       $(D_INLINECODE Args[0] < Args[1]).)
 *  $(LI $(D_KEYWORD int): a negative number means that
 *       $(D_INLINECODE Args[0] < Args[1]), a positive number that
 *       $(D_INLINECODE Args[0] > Args[1]), `0` if they equal.)
 * )
 *
 * Params:
 *  Args = Two aliases to compare for equality.
 *
 * Returns: $(D_KEYWORD true) if $(D_INLINECODE Args[0]) is less than or equal
 *          to $(D_INLINECODE Args[1]), $(D_KEYWORD false) otherwise.
 */
template isLessEqual(alias cmp, Args...)
if (Args.length == 2 && __traits(isTemplate, cmp))
{
    private enum result = cmp!(Args[1], Args[0]);
    static if (is(typeof(result) == bool))
    {
        enum bool isLessEqual = !result;
    }
    else
    {
        enum bool isLessEqual = result >= 0;
    }
}

///
@nogc nothrow pure @safe unittest
{
    enum bool boolCmp(T, U) = T.sizeof < U.sizeof;
    static assert(isLessEqual!(boolCmp, byte, int));
    static assert(isLessEqual!(boolCmp, uint, int));
    static assert(!isLessEqual!(boolCmp, long, int));

    enum ptrdiff_t intCmp(T, U) = T.sizeof - U.sizeof;
    static assert(isLessEqual!(intCmp, byte, int));
    static assert(isLessEqual!(intCmp, uint, int));
    static assert(!isLessEqual!(intCmp, long, int));
}

/**
 * Tests whether $(D_INLINECODE Args[0]) is greater than or equal to
 * $(D_INLINECODE Args[1]) according to $(D_PARAM cmp).
 *
 * $(D_PARAM cmp) can evaluate to:
 * $(UL
 *  $(LI $(D_KEYWORD bool): $(D_KEYWORD true) means
 *       $(D_INLINECODE Args[0] < Args[1]).)
 *  $(LI $(D_KEYWORD int): a negative number means that
 *       $(D_INLINECODE Args[0] < Args[1]), a positive number that
 *       $(D_INLINECODE Args[0] > Args[1]), `0` if they equal.)
 * )
 *
 * Params:
 *  Args = Two aliases to compare for equality.
 *
 * Returns: $(D_KEYWORD true) if $(D_INLINECODE Args[0]) is greater than or
 *          equal to $(D_INLINECODE Args[1]), $(D_KEYWORD false) otherwise.
 */
template isGreaterEqual(alias cmp, Args...)
if (Args.length == 2 && __traits(isTemplate, cmp))
{
    private enum result = cmp!Args;
    static if (is(typeof(result) == bool))
    {
        enum bool isGreaterEqual = !result;
    }
    else
    {
        enum bool isGreaterEqual = result >= 0;
    }
}

///
@nogc nothrow pure @safe unittest
{
    enum bool boolCmp(T, U) = T.sizeof < U.sizeof;
    static assert(!isGreaterEqual!(boolCmp, byte, int));
    static assert(isGreaterEqual!(boolCmp, uint, int));
    static assert(isGreaterEqual!(boolCmp, long, int));

    enum ptrdiff_t intCmp(T, U) = T.sizeof - U.sizeof;
    static assert(!isGreaterEqual!(intCmp, byte, int));
    static assert(isGreaterEqual!(intCmp, uint, int));
    static assert(isGreaterEqual!(intCmp, long, int));
}

/**
 * Tests whether $(D_INLINECODE Args[0]) is less than
 * $(D_INLINECODE Args[1]) according to $(D_PARAM cmp).
 *
 * $(D_PARAM cmp) can evaluate to:
 * $(UL
 *  $(LI $(D_KEYWORD bool): $(D_KEYWORD true) means
 *       $(D_INLINECODE Args[0] < Args[1]).)
 *  $(LI $(D_KEYWORD int): a negative number means that
 *       $(D_INLINECODE Args[0] < Args[1]), a positive number that
 *       $(D_INLINECODE Args[0] > Args[1]), `0` if they equal.)
 * )
 *
 * Params:
 *  Args = Two aliases to compare for equality.
 *
 * Returns: $(D_KEYWORD true) if $(D_INLINECODE Args[0]) is less than
 *          $(D_INLINECODE Args[1]), $(D_KEYWORD false) otherwise.
 */
template isLess(alias cmp, Args...)
if (Args.length == 2 && __traits(isTemplate, cmp))
{
    private enum result = cmp!Args;
    static if (is(typeof(result) == bool))
    {
        enum bool isLess = result;
    }
    else
    {
        enum bool isLess = result < 0;
    }
}

///
@nogc nothrow pure @safe unittest
{
    enum bool boolCmp(T, U) = T.sizeof < U.sizeof;
    static assert(isLess!(boolCmp, byte, int));
    static assert(!isLess!(boolCmp, uint, int));
    static assert(!isLess!(boolCmp, long, int));

    enum ptrdiff_t intCmp(T, U) = T.sizeof - U.sizeof;
    static assert(isLess!(intCmp, byte, int));
    static assert(!isLess!(intCmp, uint, int));
    static assert(!isLess!(intCmp, long, int));
}

/**
 * Tests whether $(D_INLINECODE Args[0]) is greater than
 * $(D_INLINECODE Args[1]) according to $(D_PARAM cmp).
 *
 * $(D_PARAM cmp) can evaluate to:
 * $(UL
 *  $(LI $(D_KEYWORD bool): $(D_KEYWORD true) means
 *       $(D_INLINECODE Args[0] < Args[1]).)
 *  $(LI $(D_KEYWORD int): a negative number means that
 *       $(D_INLINECODE Args[0] < Args[1]), a positive number that
 *       $(D_INLINECODE Args[0] > Args[1]), `0` if they equal.)
 * )
 *
 * Params:
 *  Args = Two aliases to compare for equality.
 *
 * Returns: $(D_KEYWORD true) if $(D_INLINECODE Args[0]) is greater than
 *          $(D_INLINECODE Args[1]), $(D_KEYWORD false) otherwise.
 */
template isGreater(alias cmp, Args...)
if (Args.length == 2 && __traits(isTemplate, cmp))
{
    private enum result = cmp!Args;
    static if (is(typeof(result) == bool))
    {
        enum bool isGreater = !result && cmp!(Args[1], Args[0]);
    }
    else
    {
        enum bool isGreater = result > 0;
    }
}

///
@nogc nothrow pure @safe unittest
{
    enum bool boolCmp(T, U) = T.sizeof < U.sizeof;
    static assert(!isGreater!(boolCmp, byte, int));
    static assert(!isGreater!(boolCmp, uint, int));
    static assert(isGreater!(boolCmp, long, int));

    enum ptrdiff_t intCmp(T, U) = T.sizeof - U.sizeof;
    static assert(!isGreater!(intCmp, byte, int));
    static assert(!isGreater!(intCmp, uint, int));
    static assert(isGreater!(intCmp, long, int));
}

/**
 * Tests whether $(D_INLINECODE Args[0]) is equal to $(D_INLINECODE Args[1]).
 *
 * $(D_PSYMBOL isEqual) checks first if $(D_PARAM Args) can be compared directly. If not, they are compared as types:
 * $(D_INLINECODE is(Args[0] == Args[1])). It it fails, the arguments are
 * considered to be not equal.
 *
 * If two items cannot be compared (for example comparing a type with a
 * number), they are considered not equal.
 *
 * Params:
 *  Args = Two aliases to compare for equality.
 *
 * Returns: $(D_KEYWORD true) if $(D_INLINECODE Args[0]) is equal to
 *          $(D_INLINECODE Args[1]), $(D_KEYWORD false) otherwise.
 */
template isEqual(Args...)
if (Args.length == 2)
{
    static if ((is(typeof(Args[0] == Args[1])) && (Args[0] == Args[1]))
            || (isTypeTuple!Args && is(Args[0] == Args[1]))
            || __traits(isSame, Args[0], Args[1]))
    {
        enum bool isEqual = true;
    }
    else
    {
        enum bool isEqual = false;
    }
}

///
@nogc nothrow pure @safe unittest
{
    static assert(isEqual!(int, int));
    static assert(isEqual!(8, 8));
    static assert(!isEqual!(int, const(int)));
    static assert(!isEqual!(5, int));
    static assert(!isEqual!(5, 8));
}

/**
 * Tests whether $(D_INLINECODE Args[0]) isn't equal to
 * $(D_INLINECODE Args[1]).
 *
 * $(D_PSYMBOL isNotEqual) checks first if $(D_PARAM Args) can be compared directly. If not, they are compared as types:
 * $(D_INLINECODE is(Args[0] == Args[1])). It it fails, the arguments are
 * considered to be not equal.
 *
 * Params:
 *  Args = Two aliases to compare for equality.
 *
 * Returns: $(D_KEYWORD true) if $(D_INLINECODE Args[0]) isn't equal to
 *          $(D_INLINECODE Args[1]), $(D_KEYWORD false) otherwise.
 */
template isNotEqual(Args...)
if (Args.length == 2)
{
    enum bool isNotEqual = !isEqual!Args;
}

///
@nogc nothrow pure @safe unittest
{
    static assert(!isNotEqual!(int, int));
    static assert(isNotEqual!(5, int));
    static assert(isNotEqual!(5, 8));
}

/**
 * Instantiates the template $(D_PARAM T) with $(D_PARAM Args).
 *
 * Params:
 *  T    = Template.
 *  Args = Template parameters.
 *
 * Returns: Instantiated template.
 */
alias Instantiate(alias T, Args...) = T!Args;

///
@nogc nothrow pure @safe unittest
{
    template Template(T)
    {
        alias Template = T;
    }
    alias Seq = AliasSeq!(Template, Template);

    alias Instance1 = Instantiate!(Seq[0], int);
    static assert(is(Instance1 == int));

    alias Instance2 = Instantiate!(Seq[1], float);
    static assert(is(Instance2 == float));
}

/**
 * Creates an alias for $(D_PARAM T).
 *
 * In contrast to the $(D_KEYWORD alias)-keyword $(D_PSYMBOL Alias) can alias
 * any kind of D symbol that can be used as argument to template alias
 * parameters.
 *
 * $(UL
 *  $(LI Types)
 *  $(LI Local and global names)
 *  $(LI Module names)
 *  $(LI Template names)
 *  $(LI Template instance names)
 *  $(LI Literals)
 * )
 *
 * Params:
 *  T = A symbol.
 *
 * Returns: An alias for $(D_PARAM T).
 *
 * See_Also: $(LINK2 https://dlang.org/spec/template.html#aliasparameters,
 *                   Template Alias Parameters).
 */
alias Alias(alias T) = T;

/// ditto
alias Alias(T) = T;

///
@nogc nothrow pure @safe unittest
{
    static assert(is(Alias!int));

    static assert(is(typeof(Alias!5)));
    static assert(is(typeof(Alias!(() {}))));

    int i;
    static assert(is(typeof(Alias!i)));
}

/**
 * Holds a sequence of aliases.
 *
 * $(D_PSYMBOL AliasSeq) can be used to pass multiple parameters to a template
 * at once. $(D_PSYMBOL AliasSeq) behaves as it were just $(D_PARAM Args). Note
 * that because of this property, if multiple instances of
 * $(D_PSYMBOL AliasSeq) are passed to a template, they are not distinguishable
 * from each other and act as a single sequence. There is also no way to make
 * $(D_PSYMBOL AliasSeq) nested, it always unpacks its elements.
 *
 * Params:
 *  Args = Symbol sequence.
 *
 * Returns: An alias for sequence $(D_PARAM Args).
 *
 * See_Also: $(D_PSYMBOL Alias).
 */
alias AliasSeq(Args...) = Args;

///
@nogc nothrow pure @safe unittest
{
    static assert(is(typeof({ alias T = AliasSeq!(short, 5); })));
    static assert(is(typeof({ alias T = AliasSeq!(int, short, 5); })));
    static assert(is(typeof({ alias T = AliasSeq!(() {}, short, 5); })));
    static assert(is(typeof({ alias T = AliasSeq!(); })));

    static assert(AliasSeq!().length == 0);
    static assert(AliasSeq!(int, short, 5).length == 3);

    alias A = AliasSeq!(short, float);
    alias B = AliasSeq!(ushort, double);
    alias C = AliasSeq!(A, B);
    static assert(C.length == 4);
}

/**
 * Tests whether all the items of $(D_PARAM L) satisfy the condition
 * $(D_PARAM F).
 *
 * $(D_PARAM F) is a template that accepts one parameter and returns a boolean,
 * so $(D_INLINECODE F!([0]) && F!([1])) and so on, can be called.
 *
 * Params:
 *  F = Template predicate. 
 *  L = List of items to test.
 *
 * Returns: $(D_KEYWORD true) if all the items of $(D_PARAM L) satisfy
 *          $(D_PARAM F), $(D_KEYWORD false) otherwise.
 */
enum bool allSatisfy(alias F, L...) = Filter!(templateNot!F, L).length == 0;

///
@nogc nothrow pure @safe unittest
{
    static assert(allSatisfy!(isSigned, int, short, byte, long));
    static assert(!allSatisfy!(isUnsigned, uint, ushort, float, ulong));
}

/**
 * Tests whether any of the items of $(D_PARAM L) satisfy the condition
 * $(D_PARAM F).
 *
 * $(D_PARAM F) is a template that accepts one parameter and returns a boolean,
 * so $(D_INLINECODE F!([0]) && F!([1])) and so on, can be called.
 *
 * Params:
 *  F = Template predicate. 
 *  L = List of items to test.
 *
 * Returns: $(D_KEYWORD true) if any of the items of $(D_PARAM L) satisfy
 *          $(D_PARAM F), $(D_KEYWORD false) otherwise.
 */
enum bool anySatisfy(alias F, L...) = Filter!(F, L).length != 0;

///
@nogc nothrow pure @safe unittest
{
    static assert(anySatisfy!(isSigned, int, short, byte, long));
    static assert(anySatisfy!(isUnsigned, uint, ushort, float, ulong));
    static assert(!anySatisfy!(isSigned, uint, ushort, ulong));
}

private template indexOf(Args...)
{
    static foreach (i, Arg; Args[1 .. $])
    {
        static if (!is(typeof(indexOf) == ptrdiff_t) && isEqual!(Args[0], Arg))
        {
            enum ptrdiff_t indexOf = i;
        }
    }
    static if (!is(typeof(indexOf) == ptrdiff_t))
    {
        enum ptrdiff_t indexOf = -1;
    }
}

/**
 * Returns the index of the first occurrence of $(D_PARAM T) in $(D_PARAM L).
 * `-1` is returned if $(D_PARAM T) is not found.
 *
 * Params:
 *  T = The item to search for.
 *  L = Symbol sequence.
 *
 * Returns: The index of the first occurrence of $(D_PARAM T) in $(D_PARAM L).
 */
template staticIndexOf(T, L...)
{
    enum ptrdiff_t staticIndexOf = indexOf!(T, L);
}

/// ditto
template staticIndexOf(alias T, L...)
{
    enum ptrdiff_t staticIndexOf = indexOf!(T, L);
}

///
@nogc nothrow pure @safe unittest
{
    static assert(staticIndexOf!(int) == -1);
    static assert(staticIndexOf!(int, int) == 0);
    static assert(staticIndexOf!(int, float, double, int, real) == 2);
    static assert(staticIndexOf!(3, () {}, uint, 5, 3) == 3);
}

/**
 * Looks for $(D_PARAM T) in $(D_PARAM L) and returns $(D_KEYWORD true) if it
 * could be found and $(D_KEYWORD false) otherwise.
 *
 * Params:
 *  T = The item to search for.
 *  L = Symbol sequence.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM T) can be found in $(D_PARAM L),
 *          $(D_KEYWORD false) otherwise.
 */
enum bool canFind(T, L...) = staticIndexOf!(T, L) != -1;

/// ditto
enum bool canFind(alias T, L...) = staticIndexOf!(T, L) != -1;

///
@nogc nothrow pure @safe unittest
{
    static assert(!canFind!(int));
    static assert(canFind!(int, int));
    static assert(canFind!(int, float, double, int, real));
    static assert(canFind!(3, () {}, uint, 5, 3));
}

/*
 * Tests whether $(D_PARAM T) is a template.
 *
 * $(D_PSYMBOL isTemplate) isn't $(D_KEYWORD true) for template instances,
 * since the latter already represent some type. Only not instantiated
 * templates, i.e. that accept some template parameters, are considered
 * templates.
 *
 * Params:
 *  T = A symbol.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM T) is a template,
 *          $(D_KEYWORD false) otherwise.
 */
private enum bool isTemplate(alias T) = __traits(isTemplate, T);

///
@nogc nothrow pure @safe unittest
{
    static struct S(T)
    {
    }
    static assert(isTemplate!S);
    static assert(!isTemplate!(S!int));
}

/**
 * Combines multiple templates with logical AND. So $(D_PSYMBOL templateAnd)
 * evaluates to $(D_INLINECODE Preds[0] && Preds[1] && Preds[2]) and so on.
 *
 * Empty $(D_PARAM Preds) evaluates to $(D_KEYWORD true).
 *
 * Params:
 *  Preds = Template predicates.
 *
 * Returns: The constructed template.
 */
template templateAnd(Preds...)
if (allSatisfy!(isTemplate, Preds))
{
    template templateAnd(T...)
    {
        static if (Preds.length == 0)
        {
            enum bool templateAnd = true;
        }
        else static if (Instantiate!(Preds[0], T))
        {
            alias templateAnd = Instantiate!(.templateAnd!(Preds[1 .. $]), T);
        }
        else
        {
            enum bool templateAnd = false;
        }
    }
}

///
@nogc nothrow pure @safe unittest
{
    alias isMutableInt = templateAnd!(isIntegral, isMutable);
    static assert(isMutableInt!int);
    static assert(!isMutableInt!(const int));
    static assert(!isMutableInt!float);

    alias alwaysTrue = templateAnd!();
    static assert(alwaysTrue!int);

    alias isIntegral = templateAnd!(.isIntegral);
    static assert(isIntegral!int);
    static assert(isIntegral!(const int));
    static assert(!isIntegral!float);
}

/**
 * Combines multiple templates with logical OR. So $(D_PSYMBOL templateOr)
 * evaluates to $(D_INLINECODE Preds[0] || Preds[1] || Preds[2]) and so on.
 *
 * Empty $(D_PARAM Preds) evaluates to $(D_KEYWORD false).
 *
 * Params:
 *  Preds = Template predicates.
 *
 * Returns: The constructed template.
 */
template templateOr(Preds...)
if (allSatisfy!(isTemplate, Preds))
{
    template templateOr(T...)
    {
        static if (Preds.length == 0)
        {
            enum bool templateOr = false;
        }
        else static if (Instantiate!(Preds[0], T))
        {
            enum bool templateOr = true;
        }
        else
        {
            alias templateOr = Instantiate!(.templateOr!(Preds[1 .. $]), T);
        }
    }
}

///
@nogc nothrow pure @safe unittest
{
    alias isMutableOrInt = templateOr!(isIntegral, isMutable);
    static assert(isMutableOrInt!int);
    static assert(isMutableOrInt!(const int));
    static assert(isMutableOrInt!float);
    static assert(!isMutableOrInt!(const float));

    alias alwaysFalse = templateOr!();
    static assert(!alwaysFalse!int);

    alias isIntegral = templateOr!(.isIntegral);
    static assert(isIntegral!int);
    static assert(isIntegral!(const int));
    static assert(!isIntegral!float);
}

/**
 * Params:
 *  pred = Template predicate.
 *
 * Returns: Negated $(D_PARAM pred).
 */
template templateNot(alias pred)
if (__traits(isTemplate, pred))
{
    enum bool templateNot(T...) = !pred!T;
}

///
@nogc nothrow pure @safe unittest
{
    alias isNotIntegral = templateNot!isIntegral;
    static assert(!isNotIntegral!int);
    static assert(isNotIntegral!(char[]));
}

/**
 * Tests whether $(D_PARAM L) is sorted in ascending order according to
 * $(D_PARAM cmp).
 *
 * $(D_PARAM cmp) can evaluate to:
 * $(UL
 *  $(LI $(D_KEYWORD bool): $(D_KEYWORD true) means
 *       $(D_INLINECODE a[i] < a[i + 1]).)
 *  $(LI $(D_KEYWORD int): a negative number means that
 *       $(D_INLINECODE a[i] < a[i + 1]), a positive number that
 *       $(D_INLINECODE a[i] > a[i + 1]), `0` if they equal.)
 * )
 *
 * Params:
 *  cmp = Sorting template predicate.
 *  L   = Elements to be tested.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM L) is sorted, $(D_KEYWORD false)
 *          if not.
 */
template isSorted(alias cmp, L...)
if (__traits(isTemplate, cmp))
{
    static if (L.length <= 1)
    {
        enum bool isSorted = true;
    }
    else
    {
        // `L` is sorted if the both halves and the boundary values are sorted.
        enum bool isSorted = isLessEqual!(cmp, L[$ / 2 - 1], L[$ / 2])
                          && isSorted!(cmp, L[0 .. $ / 2])
                          && isSorted!(cmp, L[$ / 2 .. $]);
    }
}

///
@nogc nothrow pure @safe unittest
{
    enum cmp(T, U) = T.sizeof < U.sizeof;
    static assert(isSorted!(cmp));
    static assert(isSorted!(cmp, byte));
    static assert(isSorted!(cmp, byte, ubyte, short, uint));
    static assert(!isSorted!(cmp, long, byte, ubyte, short, uint));
}

/**
 * Params:
 *  T    = A template.
 *  Args = The first arguments for $(D_PARAM T).
 *
 * Returns: $(D_PARAM T) with $(D_PARAM Args) applied to it as its first
 *          arguments.
 */
template ApplyLeft(alias T, Args...)
{
    alias ApplyLeft(U...) = T!(Args, U);
}

///
@nogc nothrow pure @safe unittest
{
    alias allAreIntegral = ApplyLeft!(allSatisfy, isIntegral);
    static assert(allAreIntegral!(int, uint));
    static assert(!allAreIntegral!(int, float, uint));
}

/**
 * Params:
 *  T    = A template.
 *  Args = The last arguments for $(D_PARAM T).
 *
 * Returns: $(D_PARAM T) with $(D_PARAM Args) applied to it as itslast
 *          arguments.
 */
template ApplyRight(alias T, Args...)
{
    alias ApplyRight(U...) = T!(U, Args);
}

///
@nogc nothrow pure @safe unittest
{
    alias intIs = ApplyRight!(allSatisfy, int);
    static assert(intIs!(isIntegral));
    static assert(!intIs!(isUnsigned));
}

/**
 * Params:
 *  n = The number of times to repeat $(D_PARAM L).
 *  L = The sequence to be repeated.
 *
 * Returns: $(D_PARAM L) repeated $(D_PARAM n) times.
 */
template Repeat(size_t n, L...)
if (n > 0)
{
    static if (n == 1)
    {
        alias Repeat = L;
    }
    else
    {
        alias Repeat = AliasSeq!(L, Repeat!(n - 1, L));
    }
}

///
@nogc nothrow pure @safe unittest
{
    static assert(is(Repeat!(1, uint, int) == AliasSeq!(uint, int)));
    static assert(is(Repeat!(2, uint, int) == AliasSeq!(uint, int, uint, int)));
    static assert(is(Repeat!(3) == AliasSeq!()));
}

private template ReplaceOne(L...)
{
    static if (L.length == 2)
    {
        alias ReplaceOne = AliasSeq!();
    }
    else static if (isEqual!(L[0], L[2]))
    {
        alias ReplaceOne = AliasSeq!(L[1], L[3 .. $]);
    }
    else
    {
        alias ReplaceOne = AliasSeq!(L[2], ReplaceOne!(L[0], L[1], L[3 .. $]));
    }
}

/**
 * Replaces the first occurrence of $(D_PARAM T) in $(D_PARAM L) with
 * $(D_PARAM U).
 *
 * Params:
 *  T = The symbol to be replaced.
 *  U = Replacement.
 *  L = List of symbols.
 *
 * Returns: $(D_PARAM L) with the first occurrence of $(D_PARAM T) replaced.
 */
template Replace(T, U, L...)
{
    alias Replace = ReplaceOne!(T, U, L);
}

/// ditto
template Replace(alias T, U, L...)
{
    alias Replace = ReplaceOne!(T, U, L);
}

/// ditto
template Replace(T, alias U, L...)
{
    alias Replace = ReplaceOne!(T, U, L);
}

/// ditto
template Replace(alias T, alias U, L...)
{
    alias Replace = ReplaceOne!(T, U, L);
}

///
@nogc nothrow pure @safe unittest
{
    static assert(is(Replace!(int, uint, int) == AliasSeq!(uint)));
    static assert(is(Replace!(int, uint, short, int, int, ushort)
               == AliasSeq!(short, uint, int, ushort)));

    static assert(Replace!(5, 8, 1, 2, 5, 5) == AliasSeq!(1, 2, 8, 5));
}

private template ReplaceAllImpl(L...)
{
    static if (L.length == 2)
    {
        alias ReplaceAllImpl = AliasSeq!();
    }
    else
    {
        private alias Rest = ReplaceAllImpl!(L[0], L[1], L[3 .. $]);
        static if (isEqual!(L[0], L[2]))
        {
            alias ReplaceAllImpl = AliasSeq!(L[1], Rest);
        }
        else
        {
            alias ReplaceAllImpl = AliasSeq!(L[2], Rest);
        }
    }
}

/**
 * Replaces all occurrences of $(D_PARAM T) in $(D_PARAM L) with $(D_PARAM U).
 *
 * Params:
 *  T = The symbol to be replaced.
 *  U = Replacement.
 *  L = List of symbols.
 *
 * Returns: $(D_PARAM L) with all occurrences of $(D_PARAM T) replaced.
 */
template ReplaceAll(T, U, L...)
{
    alias ReplaceAll = ReplaceAllImpl!(T, U, L);
}

/// ditto
template ReplaceAll(alias T, U, L...)
{
    alias ReplaceAll = ReplaceAllImpl!(T, U, L);
}

/// ditto
template ReplaceAll(T, alias U, L...)
{
    alias ReplaceAll = ReplaceAllImpl!(T, U, L);
}

/// ditto
template ReplaceAll(alias T, alias U, L...)
{
    alias ReplaceAll = ReplaceAllImpl!(T, U, L);
}

///
@nogc nothrow pure @safe unittest
{
    static assert(is(ReplaceAll!(int, uint, int) == AliasSeq!(uint)));
    static assert(is(ReplaceAll!(int, uint, short, int, int, ushort)
               == AliasSeq!(short, uint, uint, ushort)));

    static assert(ReplaceAll!(5, 8, 1, 2, 5, 5) == AliasSeq!(1, 2, 8, 8));
}

/**
 * Params:
 *  L = List of symbols.
 *
 * Returns: $(D_PARAM L) with elements in reversed order.
 */
template Reverse(L...)
{
    static if (L.length == 0)
    {
        alias Reverse = AliasSeq!();
    }
    else
    {
        alias Reverse = AliasSeq!(L[$ - 1], Reverse!(L[0 .. $ - 1]));
    }
}

///
@nogc nothrow pure @safe unittest
{
    static assert(is(Reverse!(byte, short, int) == AliasSeq!(int, short, byte)));
}

/**
 * Applies $(D_PARAM F) to all elements of $(D_PARAM T).
 *
 * Params:
 *  F = Template predicate.
 *  T = List of symbols.
 *
 * Returns: Elements $(D_PARAM T) after applying $(D_PARAM F) to them.
 */
template Map(alias F, T...)
if (__traits(isTemplate, F))
{
    static if (T.length == 0)
    {
        alias Map = AliasSeq!();
    }
    else
    {
        alias Map = AliasSeq!(F!(T[0]), Map!(F, T[1 .. $]));
    }
}

///
@nogc nothrow pure @safe unittest
{
    static assert(is(Map!(Unqual, const int, immutable short)
               == AliasSeq!(int, short)));
}

/**
 * Sorts $(D_PARAM L) in ascending order according to $(D_PARAM cmp).
 *
 * $(D_PARAM cmp) can evaluate to:
 * $(UL
 *  $(LI $(D_KEYWORD bool): $(D_KEYWORD true) means
 *       $(D_INLINECODE a[i] < a[i + 1]).)
 *  $(LI $(D_KEYWORD int): a negative number means that
 *       $(D_INLINECODE a[i] < a[i + 1]), a positive number that
 *       $(D_INLINECODE a[i] > a[i + 1]), `0` if they equal.)
 * )
 *
 * Merge sort is used to sort the arguments.
 *
 * Params:
 *  cmp = Sorting template predicate.
 *  L   = Elements to be sorted.
 *
 * Returns: Elements of $(D_PARAM L) in ascending order.
 *
 * See_Also: $(LINK2 https://en.wikipedia.org/wiki/Merge_sort, Merge sort).
 */
template Sort(alias cmp, L...)
if (__traits(isTemplate, cmp))
{
    private template merge(size_t A, size_t B)
    {
        static if (A + B == L.length)
        {
            alias merge = AliasSeq!();
        }
        else static if (B >= Right.length
                     || (A < Left.length && isLessEqual!(cmp, Left[A], Right[B])))
        {
            alias merge = AliasSeq!(Left[A], merge!(A + 1, B));
        }
        else
        {
            alias merge = AliasSeq!(Right[B], merge!(A, B + 1));
        }
    }

    static if (L.length <= 1)
    {
        alias Sort = L;
    }
    else
    {
        private alias Left = Sort!(cmp, L[0 .. $ / 2]);
        private alias Right = Sort!(cmp, L[$ / 2 .. $]);
        alias Sort = merge!(0, 0);
    }
}

///
@nogc nothrow pure @safe unittest
{
    enum cmp(T, U) = T.sizeof < U.sizeof;
    static assert(is(Sort!(cmp, long, short, byte, int)
               == AliasSeq!(byte, short, int, long)));
}

@nogc nothrow pure @safe unittest
{
    enum cmp(int T, int U) = T - U;
    static assert(Sort!(cmp, 5, 17, 9, 12, 2, 10, 14)
               == AliasSeq!(2, 5, 9, 10, 12, 14, 17));
}

private enum bool DerivedToFrontCmp(A, B) = is(A : B);

/**
 * Returns $(D_PARAM L) sorted in such a way that the most derived types come
 * first.
 *
 * Params:
 *  L = Type tuple.
 *
 * Returns: Sorted $(D_PARAM L).
 */
template DerivedToFront(L...)
{
    alias DerivedToFront = Sort!(DerivedToFrontCmp, L);
}

///
@nogc nothrow pure @safe unittest
{
    class A
    {
    }
    class B : A
    {
    }
    class C : B
    {
    }
    static assert(is(DerivedToFront!(B, A, C) == AliasSeq!(C, B, A)));
}

/**
 * Returns the type from the type tuple $(D_PARAM L) that is most derived from
 * $(D_PARAM T).
 *
 * Params:
 *  T = The type to compare to.
 *  L = Type tuple.
 *
 * Returns: The type most derived from $(D_PARAM T).
 */
template MostDerived(T, L...)
{
    static if (L.length == 0)
    {
        alias MostDerived = T;
    }
    else static if (is(T : L[0]))
    {
        alias MostDerived = MostDerived!(T, L[1 .. $]);
    }
    else
    {
        alias MostDerived = MostDerived!(L[0], L[1 .. $]);
    }
}

///
@nogc nothrow pure @safe unittest
{
    class A
    {
    }
    class B : A
    {
    }
    class C : B
    {
    }
    static assert(is(MostDerived!(A, C, B) == C));
}

private template EraseOne(L...)
if (L.length > 0)
{
    static if (L.length == 1)
    {
        alias EraseOne = AliasSeq!();
    }
    else static if (isEqual!(L[0 .. 2]))
    {
        alias EraseOne = AliasSeq!(L[2 .. $]);
    }
    else
    {
        alias EraseOne = AliasSeq!(L[1], EraseOne!(L[0], L[2 .. $]));
    }
}

/**
 * Removes the first occurrence of $(D_PARAM T) from the alias sequence
 * $(D_PARAL L).
 *
 * Params:
 *  T = The item to be removed.
 *  L = Alias sequence.
 *
 * Returns: $(D_PARAM L) with the first occurrence of $(D_PARAM T) removed.
 */
template Erase(T, L...)
{
    alias Erase = EraseOne!(T, L);
}

/// ditto
template Erase(alias T, L...)
{
    alias Erase = EraseOne!(T, L);
}

///
@nogc nothrow pure @safe unittest
{
    static assert(is(Erase!(int, short, int, int, uint) == AliasSeq!(short, int, uint)));
    static assert(is(Erase!(int, short, uint) == AliasSeq!(short, uint)));
}

private template EraseAllImpl(L...)
{
    static if (L.length == 1)
    {
        alias EraseAllImpl = AliasSeq!();
    }
    else static if (isEqual!(L[0 .. 2]))
    {
        alias EraseAllImpl = EraseAllImpl!(L[0], L[2 .. $]);
    }
    else
    {
        alias EraseAllImpl = AliasSeq!(L[1], EraseAllImpl!(L[0], L[2 .. $]));
    }
}

/**
 * Removes all occurrences of $(D_PARAM T) from the alias sequence $(D_PARAL L).
 *
 * Params:
 *  T = The item to be removed.
 *  L = Alias sequence.
 *
 * Returns: $(D_PARAM L) with all occurrences of $(D_PARAM T) removed.
 */
template EraseAll(T, L...)
{
    alias EraseAll = EraseAllImpl!(T, L);
}

/// ditto
template EraseAll(alias T, L...)
{
    alias EraseAll = EraseAllImpl!(T, L);
}

///
@nogc nothrow pure @safe unittest
{
    static assert(is(EraseAll!(int, short, int, int, uint) == AliasSeq!(short, uint)));
    static assert(is(EraseAll!(int, short, uint) == AliasSeq!(short, uint)));
    static assert(is(EraseAll!(int, int, int) == AliasSeq!()));
}

/**
 * Returns an alias sequence which contains only items that satisfy the
 * condition $(D_PARAM pred).
 *
 * Params:
 *  pred = Template predicate.
 *  L    = Alias sequence.
 *
 * Returns: $(D_PARAM L) filtered so that it contains only items that satisfy
 *          $(D_PARAM pred).
 */
template Filter(alias pred, L...)
if (__traits(isTemplate, pred))
{
    static if (L.length == 0)
    {
        alias Filter = AliasSeq!();
    }
    else static if (pred!(L[0]))
    {
        alias Filter = AliasSeq!(L[0], Filter!(pred, L[1 .. $]));
    }
    else
    {
        alias Filter = Filter!(pred, L[1 .. $]);
    }
}

///
@nogc nothrow pure @safe unittest
{
    alias Given = AliasSeq!(real, int, bool, uint);
    static assert(is(Filter!(isIntegral, Given) == AliasSeq!(int, uint)));
}

/**
 * Removes all duplicates from the alias sequence $(D_PARAM L).
 *
 * Params:
 *  L = Alias sequence.
 *
 * Returns: $(D_PARAM L) containing only unique items.
 */
template NoDuplicates(L...)
{
    static if (L.length == 0)
    {
        alias NoDuplicates = AliasSeq!();
    }
    else
    {
        private alias Rest = NoDuplicates!(EraseAll!(L[0], L[1 .. $]));
        alias NoDuplicates = AliasSeq!(L[0], Rest);
    }
}

///
@nogc nothrow pure @safe unittest
{
    alias Given = AliasSeq!(int, uint, int, short, short, uint);
    static assert(is(NoDuplicates!Given == AliasSeq!(int, uint, short)));
}

/**
 * Converts an input range $(D_PARAM range) into an alias sequence.
 *
 * Params:
 *  range = Input range.
 *
 * Returns: Alias sequence with items from $(D_PARAM range).
 */
template aliasSeqOf(alias range)
{
    static if (isArray!(typeof(range)))
    {
        static if (range.length == 0)
        {
            alias aliasSeqOf = AliasSeq!();
        }
        else
        {
            alias aliasSeqOf = AliasSeq!(range[0], aliasSeqOf!(range[1 .. $]));
        }
    }
    else
    {
        ReturnType!(typeof(&range.front))[] toArray(typeof(range) range)
        {
            typeof(return) result;
            foreach (r; range)
            {
                result ~= r;
            }
            return result;
        }
        alias aliasSeqOf = aliasSeqOf!(toArray(range));
    }
}

///
@nogc nothrow pure @safe unittest
{
    static assert(aliasSeqOf!([0, 1, 2, 3]) == AliasSeq!(0, 1, 2, 3));
}

/**
 * Produces a alias sequence consisting of every $(D_PARAM n)th element of
 * $(D_PARAM Args), starting with the first.
 *
 * Params:
 *  n    = Step.
 *  Args = The items to stride.
 *
 * Returns: Alias sequence of every $(D_PARAM n)th element of $(D_PARAM Args).
 */
template Stride(size_t n, Args...)
if (n > 0)
{
    static if (Args.length > n)
    {
        alias Stride = AliasSeq!(Args[0], Stride!(n, Args[n .. $]));
    }
    else static if (Args.length > 0)
    {
        alias Stride = AliasSeq!(Args[0]);
    }
    else
    {
        alias Stride = AliasSeq!();
    }
}

///
@nogc nothrow pure @safe unittest
{
    static assert(Stride!(3, 1, 2, 3, 4, 5, 6, 7, 8) == AliasSeq!(1, 4, 7));
    static assert(Stride!(2, 1, 2, 3) == AliasSeq!(1, 3));
    static assert(Stride!(2, 1, 2) == AliasSeq!(1));
    static assert(Stride!(2, 1) == AliasSeq!(1));
    static assert(Stride!(1, 1, 2, 3) == AliasSeq!(1, 2, 3));
    static assert(is(Stride!3 == AliasSeq!()));
}

/**
 * Aliases itself to $(D_INLINECODE T[0]) if $(D_PARAM cond) is $(D_KEYWORD true),
 * to $(D_INLINECODE T[1]) if $(D_KEYWORD false).
 *
 * Params:
 *  cond = Template predicate.
 *  T    = Two arguments.
 *
 * Returns: $(D_INLINECODE T[0]) if $(D_PARAM cond) is $(D_KEYWORD true),
 * $(D_INLINECODE T[1]) otherwise.
 */
template Select(bool cond, T...)
if (T.length == 2)
{
    static if (cond)
    {
        alias Select = T[0];
    }
    else
    {
        alias Select = T[1];
    }
}

///
@nogc nothrow pure @safe unittest
{
    static assert(is(Select!(true, int, float) == int));
    static assert(is(Select!(false, int, float) == float));
}

/**
 * Attaches a numeric index to each element from $(D_PARAM Args).
 *
 * $(D_PSYMBOL EnumerateFrom) returns a sequence of tuples ($(D_PSYMBOL Pack)s)
 * consisting of the index of each element and the element itself.
 *
 * Params:
 *  start = Enumeration initial value.
 *  Args  = Enumerated sequence.
 *
 * See_Also: $(D_PSYMBOL Enumerate).
 */
template EnumerateFrom(size_t start, Args...)
{
    static if (Args.length == 0)
    {
        alias EnumerateFrom = AliasSeq!();
    }
    else
    {
        alias EnumerateFrom = AliasSeq!(Pack!(start, Args[0]), EnumerateFrom!(start + 1, Args[1 .. $]));
    }
}

///
@nogc nothrow pure @safe unittest
{
    static assert(EnumerateFrom!(0, int, uint, bool).length == 3);
}

///
@nogc nothrow pure @safe unittest
{
    alias Expected = AliasSeq!(Pack!(cast(size_t) 0, int),
                               Pack!(cast(size_t) 1, uint));
    static assert(is(EnumerateFrom!(0, int, uint) == Expected));
}

/**
 * Attaches a numeric index to each element from $(D_PARAM Args).
 *
 * $(D_PSYMBOL EnumerateFrom) returns a sequence of tuples ($(D_PSYMBOL Pack)s)
 * consisting of the index of each element and the element itself.
 *
 * Params:
 *  Args  = Enumerated sequence.
 *
 * See_Also: $(D_PSYMBOL EnumerateFrom).
 */
alias Enumerate(Args...) = EnumerateFrom!(0, Args);

///
@nogc nothrow pure @safe unittest
{
    alias Expected = AliasSeq!(Pack!(cast(size_t) 0, int),
                               Pack!(cast(size_t) 1, uint));
    static assert(is(Enumerate!(int, uint) == Expected));
}
