/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * This module contains functions that manipulate template type lists as well
 * as algorithms to perform arbitrary compile-time computations.
 *
 * Copyright: Eugene Wissner 2017.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/meta/metafunction.d,
 *                 tanya/meta/metafunction.d)
 */
module tanya.meta.metafunction;

version (unittest)
{
    import tanya.meta.trait;
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

/// Ditto.
alias Alias(T) = T;

///
pure nothrow @safe @nogc unittest
{
    static assert(is(Alias!int));

    static assert(is(typeof(Alias!5)));
    static assert(is(typeof(Alias!(() {}))));

    int i;
    static assert(is(typeof(Alias!i)));
}

/**
 * Params:
 *  Args = List of symbols.
 *
 * Returns: An alias for sequence $(D_PARAM Args).
 *
 * See_Also: $(D_PSYMBOL Alias).
 */
alias AliasSeq(Args...) = Args;

///
pure nothrow @safe @nogc unittest
{
    static assert(is(typeof({ alias T = AliasSeq!(short, 5); })));
    static assert(is(typeof({ alias T = AliasSeq!(int, short, 5); })));
    static assert(is(typeof({ alias T = AliasSeq!(() {}, short, 5); })));
    static assert(is(typeof({ alias T = AliasSeq!(); })));

    static assert(AliasSeq!().length == 0);
    static assert(AliasSeq!(int, short, 5).length == 3);
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
template allSatisfy(alias F, L...)
{
    static if (L.length == 0)
    {
        enum bool allSatisfy = true;
    }
    else static if (F!(L[0]))
    {
        enum bool allSatisfy = allSatisfy!(F, L[1 .. $]);
    }
    else
    {
        enum bool allSatisfy = false;
    }
}

///
pure nothrow @safe @nogc unittest
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
template anySatisfy(alias F, L...)
{
    static if (L.length == 0)
    {
        enum bool anySatisfy = false;
    }
    else static if (F!(L[0]))
    {
        enum bool anySatisfy = true;
    }
    else
    {
        enum bool anySatisfy = anySatisfy!(F, L[1 .. $]);
    }
}

///
pure nothrow @safe @nogc unittest
{
    static assert(anySatisfy!(isSigned, int, short, byte, long));
    static assert(anySatisfy!(isUnsigned, uint, ushort, float, ulong));
    static assert(!anySatisfy!(isSigned, uint, ushort, ulong));
}

private template indexOf(ptrdiff_t i, Args...)
if (Args.length > 0)
{
    static if (Args.length == 1)
    {
        enum ptrdiff_t indexOf = -1;
    }
    else static if (is(Args[0] == Args[1])
                 || (is(typeof(Args[0] == Args[1])) && (Args[0] == Args[1])))
    {
        enum ptrdiff_t indexOf = i;
    }
    else
    {
        enum ptrdiff_t indexOf = indexOf!(i + 1,
                                          AliasSeq!(Args[0], Args[2 .. $]));
    }
}

/**
 * Returns the index of the first occurrence of $(D_PARAM T) in $(D_PARAM L).
 * `-1` is returned if $(D_PARAM T) is not found.
 *
 * Params:
 *  T = The type to search for.
 *  L = Type list.
 *
 * Returns: The index of the first occurence of $(D_PARAM T) in $(D_PARAM L).
 */
template staticIndexOf(T, L...)
{
    enum ptrdiff_t staticIndexOf = indexOf!(0, AliasSeq!(T, L));
}

/// Ditto.
template staticIndexOf(alias T, L...)
{
    enum ptrdiff_t staticIndexOf = indexOf!(0, AliasSeq!(T, L));
}

///
pure nothrow @safe @nogc unittest
{
    static assert(staticIndexOf!(int) == -1);
    static assert(staticIndexOf!(int, int) == 0);
    static assert(staticIndexOf!(int, float, double, int, real) == 2);
    static assert(staticIndexOf!(3, () {}, uint, 5, 3) == 3);
}

/**
 * Instantiates the template $(D_PARAM T) with $(D_PARAM ARGS).
 *
 * Params:
 *  T    = Template.
 *  Args = Template parameters.
 *
 * Returns: Instantiated template.
 */
alias Instantiate(alias T, Args...) = T!Args;

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
pure nothrow @safe @nogc unittest
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
pure nothrow @safe @nogc unittest
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
{
    enum bool templateNot(T...) = !pred!T;
}

///
pure nothrow @safe @nogc unittest
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
 *  cmp = Comparison template.
 *  L   = Arguments.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM L) is sorted, $(D_KEYWORD false)
 *          if not.
 */
template staticIsSorted(alias cmp, L...)
{
    static if (L.length <= 1)
    {
        enum bool staticIsSorted = true;
    }
    else
    {
        // `L` is sorted if the both halves are sorted.
        enum bool halves = staticIsSorted!(cmp, L[0 .. $ / 2])
                        && staticIsSorted!(cmp, L[$ / 2 .. $]);
        // Compare the boundary values of the havles.
        enum result = cmp!(L[$ / 2], L[$ / 2 - 1]);
        static if (is(typeof(result) == bool))
        {
            enum bool staticIsSorted = !result && halves;
        }
        else
        {
            enum bool staticIsSorted = result >= 0 && halves;
        }
    }
}

///
pure nothrow @safe @nogc unittest
{
    enum cmp(T, U) = T.sizeof < U.sizeof;
    static assert(staticIsSorted!(cmp));
    static assert(staticIsSorted!(cmp, byte));
    static assert(staticIsSorted!(cmp, byte, ubyte, short, uint));
    static assert(!staticIsSorted!(cmp, long, byte, ubyte, short, uint));
}

private pure nothrow @safe @nogc unittest
{
    enum cmp(int x, int y) = x - y;
    static assert(staticIsSorted!(cmp));
    static assert(staticIsSorted!(cmp, 1));
    static assert(staticIsSorted!(cmp, 1, 2, 2));
    static assert(staticIsSorted!(cmp, 1, 2, 2, 4));
    static assert(staticIsSorted!(cmp, 1, 2, 2, 4, 8));
    static assert(!staticIsSorted!(cmp, 32, 2, 2, 4, 8));
    static assert(staticIsSorted!(cmp, 32, 32));
}

private pure nothrow @safe @nogc unittest
{
    enum cmp(int x, int y) = x < y;
    static assert(staticIsSorted!(cmp));
    static assert(staticIsSorted!(cmp, 1));
    static assert(staticIsSorted!(cmp, 1, 2, 2));
    static assert(staticIsSorted!(cmp, 1, 2, 2, 4));
    static assert(staticIsSorted!(cmp, 1, 2, 2, 4, 8));
    static assert(!staticIsSorted!(cmp, 32, 2, 2, 4, 8));
    static assert(staticIsSorted!(cmp, 32, 32));
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
pure nothrow @safe @nogc unittest
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
pure nothrow @safe @nogc unittest
{
    alias intIs = ApplyRight!(allSatisfy, int);
    static assert(intIs!(isIntegral));
    static assert(!intIs!(isUnsigned));
}
