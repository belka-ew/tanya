/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Type transformations.
 *
 * Templates in this module can be used to modify type qualifiers or transform
 * types. They take some type as argument and return a different type after
 * perfoming the specified transformation.
 *
 * Copyright: Eugene Wissner 2017-2018.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/meta/transform.d,
 *                 tanya/meta/transform.d)
 */
module tanya.meta.transform;

import tanya.meta.metafunction;
import tanya.meta.trait;

/**
 * Removes any type qualifiers from $(D_PARAM T).
 *
 * Removed qualifiers are:
 * $(UL
 *  $(LI const)
 *  $(LI immutable)
 *  $(LI inout)
 *  $(LI shared)
 * )
 * and combinations of these.
 *
 * If the type $(D_PARAM T) doesn't have any qualifieres,
 * $(D_INLINECODE Unqual!T) becomes an alias for $(D_PARAM T).
 *
 * Params:
 *  T = A type.
 *
 * Returns: $(D_PARAM T) without any type qualifiers.
 */
template Unqual(T)
{
    static if (is(T U == const U)
            || is(T U == immutable U)
            || is(T U == inout U)
            || is(T U == inout const U)
            || is(T U == shared U)
            || is(T U == shared const U)
            || is(T U == shared inout U)
            || is(T U == shared inout const U))
    {
        alias Unqual = U;
    }
    else
    {
        alias Unqual = T;
    }
}

///
@nogc nothrow pure @safe unittest
{
    static assert(is(Unqual!bool == bool));
    static assert(is(Unqual!(immutable bool) == bool));
    static assert(is(Unqual!(inout bool) == bool));
    static assert(is(Unqual!(inout const bool) == bool));
    static assert(is(Unqual!(shared bool) == bool));
    static assert(is(Unqual!(shared const bool) == bool));
    static assert(is(Unqual!(shared inout const bool) == bool));
}

/**
 * If $(D_PARAM T) is an $(D_KEYWORD enum), $(D_INLINECODE OriginalType!T)
 * evaluates to the most base type of that $(D_KEYWORD enum) and to
 * $(D_PARAM T) otherwise.
 *
 * Params:
 *  T = A type.
 *
 * Returns: Base type of the $(D_KEYWORD enum) $(D_PARAM T) or $(D_PARAM T)
 *          itself.
 */
template OriginalType(T)
{
    static if (is(T U == enum))
    {
        alias OriginalType = OriginalType!U;
    }
    else
    {
        alias OriginalType = T;
    }
}

///
@nogc nothrow pure @safe unittest
{
    enum E1 : const(int)
    {
        n = 0,
    }
    enum E2 : bool
    {
        t = true,
    }
    enum E3 : E2
    {
        t = E2.t,
    }
    enum E4 : const(E2)
    {
        t = E2.t,
    }

    static assert(is(OriginalType!E1 == const int));
    static assert(is(OriginalType!E2 == bool));
    static assert(is(OriginalType!E3 == bool));
    static assert(is(OriginalType!E4 == bool));
    static assert(is(OriginalType!(const E4) == bool));
}

/**
 * Copies constness of $(D_PARAM From) to $(D_PARAM To).
 *
 * The following type qualifiers affect the constness and hence are copied:
 * $(UL
 *  $(LI const)
 *  $(LI immutable)
 *  $(LI inout)
 *  $(LI inout const)
 * )
 *
 * Params:
 *  From = Source type.
 *  To   = Target type.
 *
 * Returns: $(D_PARAM To) with the constness of $(D_PARAM From).
 *
 * See_Also: $(D_PSYMBOL CopyTypeQualifiers).
 */
template CopyConstness(From, To)
{
    static if (is(From T == immutable T))
    {
        alias CopyConstness = immutable To;
    }
    else static if (is(From T == const T) || is(From T == shared const T))
    {
        alias CopyConstness = const To;
    }
    else static if (is(From T == inout T) || is(From T == shared inout T))
    {
        alias CopyConstness = inout To;
    }
    else static if (is(From T == inout const T)
                 || is(From T == shared inout const T))
    {
        alias CopyConstness = inout const To;
    }
    else
    {
        alias CopyConstness = To;
    }
}

///
@nogc nothrow pure @safe unittest
{
    static assert(is(CopyConstness!(int, char) == char));
    static assert(is(CopyConstness!(const int, char) == const char));
    static assert(is(CopyConstness!(immutable int, char) == immutable char));
    static assert(is(CopyConstness!(inout int, char) == inout char));
    static assert(is(CopyConstness!(inout const int, char) == inout const char));

    static assert(is(CopyConstness!(shared int, char) == char));
    static assert(is(CopyConstness!(shared const int, char) == const char));
    static assert(is(CopyConstness!(shared inout int, char) == inout char));
    static assert(is(CopyConstness!(shared inout const int, char) == inout const char));

    static assert(is(CopyConstness!(const int, shared char) == shared const char));
    static assert(is(CopyConstness!(const int, immutable char) == immutable char));
    static assert(is(CopyConstness!(immutable int, const char) == immutable char));
}

/**
 * Copies type qualifiers of $(D_PARAM From) to $(D_PARAM To).
 *
 * Type qualifiers copied are:
 * $(UL
 *  $(LI const)
 *  $(LI immutable)
 *  $(LI inout)
 *  $(LI shared)
 * )
 * and combinations of these.
 *
 * Params:
 *  From = Source type.
 *  To   = Target type.
 *
 * Returns: $(D_PARAM To) with the type qualifiers of $(D_PARAM From).
 *
 * See_Also: $(D_PSYMBOL CopyConstness).
 */
template CopyTypeQualifiers(From, To)
{
    static if (is(From T == immutable T))
    {
        alias CopyTypeQualifiers = immutable To;
    }
    else static if (is(From T == const T))
    {
        alias CopyTypeQualifiers = const To;
    }
    else static if (is(From T == shared T))
    {
        alias CopyTypeQualifiers = shared To;
    }
    else static if (is(From T == shared const T))
    {
        alias CopyTypeQualifiers = shared const To;
    }
    else static if (is(From T == inout T))
    {
        alias CopyTypeQualifiers = inout To;
    }
    else static if (is(From T == shared inout T))
    {
        alias CopyTypeQualifiers = shared inout To;
    }
    else static if (is(From T == inout const T))
    {
        alias CopyTypeQualifiers = inout const To;
    }
    else static if (is(From T == shared inout const T))
    {
        alias CopyTypeQualifiers = shared inout const To;
    }
    else
    {
        alias CopyTypeQualifiers = To;
    }
}

///
@nogc nothrow pure @safe unittest
{
    static assert(is(CopyTypeQualifiers!(int, char) == char));
    static assert(is(CopyTypeQualifiers!(const int, char) == const char));
    static assert(is(CopyTypeQualifiers!(immutable int, char) == immutable char));
    static assert(is(CopyTypeQualifiers!(inout int, char) == inout char));
    static assert(is(CopyTypeQualifiers!(inout const int, char) == inout const char));

    static assert(is(CopyTypeQualifiers!(shared int, char) == shared char));
    static assert(is(CopyTypeQualifiers!(shared const int, char) == shared const char));
    static assert(is(CopyTypeQualifiers!(shared inout int, char) == shared inout char));
    static assert(is(CopyTypeQualifiers!(shared inout const int, char) == shared inout const char));
}

/**
 * Evaluates to the unsigned counterpart of the integral type $(D_PARAM T) preserving all type qualifiers.
 * If $(D_PARAM T) is already unsigned, $(D_INLINECODE Unsigned!T) aliases $(D_PARAM T).
 *
 * Params:
 *  T = A type.
 *
 * Returns: Unsigned counterpart of $(D_PARAM T).
 *
 * See_Also: $(D_PSYMBOL isSigned).
 */
template Unsigned(T)
if (isIntegral!T)
{
    alias UnqualedType = Unqual!(OriginalType!T);
    static if (is(UnqualedType == byte))
    {
        alias Unsigned = CopyTypeQualifiers!(T, ubyte);
    }
    else static if (is(UnqualedType == short))
    {
        alias Unsigned = CopyTypeQualifiers!(T, ushort);
    }
    else static if (is(UnqualedType == int))
    {
        alias Unsigned = CopyTypeQualifiers!(T, uint);
    }
    else static if (is(UnqualedType == long))
    {
        alias Unsigned = CopyTypeQualifiers!(T, ulong);
    }
    else
    {
        alias Unsigned = T;
    }
}

///
@nogc nothrow pure @safe unittest
{
    static assert(is(Unsigned!byte == ubyte));
    static assert(is(Unsigned!short == ushort));
    static assert(is(Unsigned!int == uint));
    static assert(is(Unsigned!long == ulong));

    static assert(is(Unsigned!(const byte) == const ubyte));
    static assert(is(Unsigned!(shared byte) == shared ubyte));
    static assert(is(Unsigned!(shared const byte) == shared const ubyte));

    static assert(!is(Unsigned!float));
    static assert(is(Unsigned!ubyte == ubyte));
}

/**
 * Evaluates to the signed counterpart of the integral type $(D_PARAM T) preserving all type qualifiers.
 * If $(D_PARAM T) is already signed, $(D_INLINECODE Signed!T) aliases $(D_PARAM T).
 *
 * Params:
 *  T = A type.
 *
 * Returns: Signed counterpart of $(D_PARAM T).
 *
 * See_Also: $(D_PSYMBOL isUnsigned).
 */
template Signed(T)
if (isIntegral!T)
{
    alias UnqualedType = Unqual!(OriginalType!T);
    static if (is(UnqualedType == ubyte))
    {
        alias Signed = CopyTypeQualifiers!(T, byte);
    }
    else static if (is(UnqualedType == ushort))
    {
        alias Signed = CopyTypeQualifiers!(T, short);
    }
    else static if (is(UnqualedType == uint))
    {
        alias Signed = CopyTypeQualifiers!(T, int);
    }
    else static if (is(UnqualedType == ulong))
    {
        alias Signed = CopyTypeQualifiers!(T, long);
    }
    else
    {
        alias Signed = T;
    }
}

///
@nogc nothrow pure @safe unittest
{
    static assert(is(Signed!ubyte == byte));
    static assert(is(Signed!ushort == short));
    static assert(is(Signed!uint == int));
    static assert(is(Signed!ulong == long));

    static assert(is(Signed!(const ubyte) == const byte));
    static assert(is(Signed!(shared ubyte) == shared byte));
    static assert(is(Signed!(shared const ubyte) == shared const byte));

    static assert(!is(Signed!float));
    static assert(is(Signed!byte == byte));
}

/**
 * Retrieves the target type `U` of a pointer `U*`.
 *
 * Params:
 *  T = Pointer type.
 *
 * Returns: Pointer target type.
 */
template PointerTarget(T)
{
    static if (is(T U : U*))
    {
        alias PointerTarget = U;
    }
    else
    {
        static assert(T.stringof ~ " isn't a pointer type");
    }
}

///
@nogc nothrow pure @safe unittest
{
    static assert(is(PointerTarget!(bool*) == bool));
    static assert(is(PointerTarget!(const bool*) == const bool));
    static assert(is(PointerTarget!(const shared bool*) == const shared bool));
    static assert(!is(PointerTarget!bool));
}

/**
 * Params:
 *  T = The type of the associative array.
 *
 * Returns: The key type of the associative array $(D_PARAM T).
 */
template KeyType(T)
{
    static if (is(T V : V[K], K))
    {
        alias KeyType = K;
    }
    else
    {
        static assert(false, T.stringof ~ " isn't an associative array");
    }
}

///
@nogc nothrow pure @safe unittest
{
    static assert(is(KeyType!(int[string]) == string));
    static assert(!is(KeyType!(int[15])));
}

/**
 * Params:
 *  T = The type of the associative array.
 *
 * Returns: The value type of the associative array $(D_PARAM T).
 */
template ValueType(T)
{
    static if (is(T V : V[K], K))
    {
        alias ValueType = V;
    }
    else
    {
        static assert(false, T.stringof ~ " isn't an associative array");
    }
}

///
@nogc nothrow pure @safe unittest
{
    static assert(is(ValueType!(int[string]) == int));
    static assert(!is(ValueType!(int[15])));
}

/**
 * Params:
 *  T = Scalar type.
 *
 * Returns: The type $(D_PARAM T) will promote to.
 *
 * See_Also: $(LINK2 https://dlang.org/spec/type.html#integer-promotions,
 *                   Integer Promotions).
 */
template Promoted(T)
if (isScalarType!T)
{
    alias Promoted = CopyTypeQualifiers!(T, typeof(T.init + T.init));
}

///
@nogc nothrow pure @safe unittest
{
    static assert(is(Promoted!bool == int));
    static assert(is(Promoted!byte == int));
    static assert(is(Promoted!ubyte == int));
    static assert(is(Promoted!short == int));
    static assert(is(Promoted!ushort == int));
    static assert(is(Promoted!char == int));
    static assert(is(Promoted!wchar == int));
    static assert(is(Promoted!dchar == uint));

    static assert(is(Promoted!(const bool) == const int));
    static assert(is(Promoted!(shared bool) == shared int));
}

/**
 * Adds $(D_KEYWORD inout) qualifier to the type $(D_PARAM T).
 *
 * Params:
 *  T = A type.
 *
 * Returns: $(D_INLINECODE inout(T)).
 */
alias InoutOf(T) = inout(T);

///
@nogc nothrow pure @safe unittest
{
    static assert(is(InoutOf!int == inout int));
}

/**
 * Adds $(D_KEYWORD inout) qualifier to the type $(D_PARAM T).
 *
 * Params:
 *  T = A type.
 *
 * Returns: $(D_INLINECODE inout(T)).
 */
alias ConstOf(T) = const(T);

///
@nogc nothrow pure @safe unittest
{
    static assert(is(ConstOf!int == const int));
}

/**
 * Adds $(D_KEYWORD inout) qualifier to the type $(D_PARAM T).
 *
 * Params:
 *  T = A type.
 *
 * Returns: $(D_INLINECODE inout(T)).
 */
alias SharedOf(T) = shared(T);

///
@nogc nothrow pure @safe unittest
{
    static assert(is(SharedOf!int == shared int));
}

/**
 * Adds $(D_KEYWORD inout) qualifier to the type $(D_PARAM T).
 *
 * Params:
 *  T = A type.
 *
 * Returns: $(D_INLINECODE inout(T)).
 */
alias SharedInoutOf(T) = shared(inout T);

///
@nogc nothrow pure @safe unittest
{
    static assert(is(SharedInoutOf!int == shared inout int));
}

/**
 * Adds $(D_KEYWORD shared const) qualifier to the type $(D_PARAM T).
 *
 * Params:
 *  T = A type.
 *
 * Returns: $(D_INLINECODE shared(const T)).
 */
alias SharedConstOf(T) = shared(const T);

///
@nogc nothrow pure @safe unittest
{
    static assert(is(SharedConstOf!int == shared const int));
}

/**
 * Adds $(D_KEYWORD immutable) qualifier to the type $(D_PARAM T).
 *
 * Params:
 *  T = A type.
 *
 * Returns: $(D_INLINECODE immutable(T)).
 */
alias ImmutableOf(T) = immutable(T);

///
@nogc nothrow pure @safe unittest
{
    static assert(is(ImmutableOf!int == immutable int));
}

/**
 * Adds $(D_KEYWORD inout const) qualifier to the type $(D_PARAM T).
 *
 * Params:
 *  T = A type.
 *
 * Returns: $(D_INLINECODE inout(const T)).
 */
alias InoutConstOf(T) = inout(const T);

///
@nogc nothrow pure @safe unittest
{
    static assert(is(InoutConstOf!int == inout const int));
}

/**
 * Adds $(D_KEYWORD shared inout const) qualifier to the type $(D_PARAM T).
 *
 * Params:
 *  T = A type.
 *
 * Returns: $(D_INLINECODE shared(inout const T)).
 */
alias SharedInoutConstOf(T) = shared(inout const T);

///
@nogc nothrow pure @safe unittest
{
    static assert(is(SharedInoutConstOf!int == shared inout const int));
}

/**
 * Returns a template with one argument which applies all qualifiers of
 * $(D_PARAM T) on its argument if instantiated.
 *
 * Params:
 *  T = A type.
 *
 * Returns: $(D_INLINECODE shared(inout const T)).
 */
template QualifierOf(T)
{
    static if (is(T U == const U))
    {
        alias QualifierOf = ConstOf;
    }
    else static if (is(T U == immutable U))
    {
        alias QualifierOf = ImmutableOf;
    }
    else static if (is(T U == inout U))
    {
        alias QualifierOf = InoutOf;
    }
    else static if (is(T U == inout const U))
    {
        alias QualifierOf = InoutConstOf;
    }
    else static if (is(T U == shared U))
    {
        alias QualifierOf = SharedOf;
    }
    else static if (is(T U == shared const U))
    {
        alias QualifierOf = SharedConstOf;
    }
    else static if (is(T U == shared inout U))
    {
        alias QualifierOf = SharedInoutOf;
    }
    else static if (is(T U == shared inout const U))
    {
        alias QualifierOf = SharedInoutConstOf;
    }
    else
    {
        alias QualifierOf(T) = T;
    }
}

///
@nogc nothrow pure @safe unittest
{
    alias MutableOf = QualifierOf!int;
    static assert(is(MutableOf!uint == uint));

    alias ConstOf = QualifierOf!(const int);
    static assert(is(ConstOf!uint == const uint));

    alias InoutOf = QualifierOf!(inout int);
    static assert(is(InoutOf!uint == inout uint));

    alias InoutConstOf = QualifierOf!(inout const int);
    static assert(is(InoutConstOf!uint == inout const uint));

    alias ImmutableOf = QualifierOf!(immutable int);
    static assert(is(ImmutableOf!uint == immutable uint));

    alias SharedOf = QualifierOf!(shared int);
    static assert(is(SharedOf!uint == shared uint));

    alias SharedConstOf = QualifierOf!(shared const int);
    static assert(is(SharedConstOf!uint == shared const uint));

    alias SharedInoutOf = QualifierOf!(shared inout int);
    static assert(is(SharedInoutOf!uint == shared inout uint));

    alias SharedInoutConstOf = QualifierOf!(shared inout const int);
    static assert(is(SharedInoutConstOf!uint == shared inout const uint));
}

/**
 * Determines the type of $(D_PARAM T). If $(D_PARAM T) is already a type,
 * $(D_PSYMBOL TypeOf) aliases itself to $(D_PARAM T).
 *
 * $(D_PSYMBOL TypeOf) evaluates to $(D_KEYWORD void) for template arguments.
 *
 * The symbols that don't have a type and aren't types cannot be used as
 * arguments to $(D_PSYMBOL TypeOf).
 *
 * Params:
 *  T = Expression, type or template.
 *
 * Returns: The type of $(D_PARAM T).
 */
alias TypeOf(T) = T;

/// ditto
template TypeOf(alias T)
if (isExpressions!T || __traits(isTemplate, T))
{
    alias TypeOf = typeof(T);
}

///
@nogc nothrow pure @safe unittest
{
    struct S(T)
    {
    }
    static assert(is(TypeOf!S == void));
    static assert(is(TypeOf!int == int));
    static assert(is(TypeOf!true == bool));
    static assert(!is(TypeOf!(tanya.meta)));
}

// e.g. returns int for int**.
private template FinalPointerTarget(T)
{
    static if (isPointer!T)
    {
        alias FinalPointerTarget = FinalPointerTarget!(PointerTarget!T);
    }
    else
    {
        alias FinalPointerTarget = T;
    }
}

// Returns true if T1 is void* and T2 is some pointer.
private template voidAndPointer(T1, T2)
{
    enum bool voidAndPointer = is(Unqual!(PointerTarget!T1) == void)
                            && isPointer!T2;
}

// Type returned by the ternary operator.
private alias TernaryType(T, U) = typeof(true ? T.init : U.init);

/**
 * Determines the type all $(D_PARAM Args) can be implicitly converted to.
 *
 * $(OL
 *  $(LI If one of the arguments is $(D_KEYWORD void), the common type is
 *       $(D_KEYWORD void).)
 *  $(LI The common type of integers with the same sign is the type with a
 *       larger size. Signed and unsigned integers don't have a common type.
 *       Type qualifiers are only preserved if all arguments are the same
 *       type.)
 *  $(LI The common type of floating point numbers is the type with more
 *       precision. Type qualifiers are only preserved if all arguments are
 *       the same type.)
 *  $(LI The common type of polymorphic objects is the next, more generic type
 *       both objects inherit from, e.g. $(D_PSYMBOL Object).)
 *  $(LI `void*` is concerned as a common type of pointers only if one of the
 *       arguments is a void pointer.)
 *  $(LI Other types have a common type only if their pointers have a common
 *       type. It means that for example $(D_KEYWORD bool) and $(D_KEYWORD int)
         don't have a common type. If the types fullfill this condition, the
         common type is determined with the ternary operator, i.e.
         `typeof(true ? T1.init : T2.init)` is evaluated.)
 * )
 *
 * If $(D_PARAM Args) don't have a common type, $(D_PSYMBOL CommonType) is
 * $(D_KEYWORD void).
 *
 * Params:
 *  Args = Type list.
 *
 * Returns: Common type for $(D_PARAM Args) or $(D_KEYWORD void) if
 *          $(D_PARAM Args) don't have a common type.
 */
template CommonType(Args...)
if (allSatisfy!(isType, Args))
{
    static if (Args.length == 0
            || is(Unqual!(Args[0]) == void)
            || is(Unqual!(Args[1]) == void))
    {
        alias CommonType = void;
    }
    else static if (Args.length == 1)
    {
        alias CommonType = Args[0];
    }
    else
    {
        private alias Pair = Args[0 .. 2];
        private enum bool sameSigned = allSatisfy!(isIntegral, Pair)
                                    && isSigned!(Args[0]) == isSigned!(Args[1]);

        static if (is(Args[0] == Args[1]))
        {
            alias CommonType = CommonType!(Args[0], Args[2 .. $]);
        }
        else static if (sameSigned || allSatisfy!(isFloatingPoint, Pair))
        {
            alias CommonType = CommonType!(Unqual!(Largest!Pair),
                                           Args[2 .. $]);
        }
        else static if (voidAndPointer!Pair
                     || voidAndPointer!(Args[1], Args[0]))
        {
            // Workaround for https://issues.dlang.org/show_bug.cgi?id=15557.
            // Determine the qualifiers returned by the ternary operator as if
            // both pointers were int*. Then copy the qualifiers to void*.
            alias P1 = CopyTypeQualifiers!(FinalPointerTarget!(Args[0]), int)*;
            alias P2 = CopyTypeQualifiers!(FinalPointerTarget!(Args[1]), int)*;
            static if (is(TernaryType!(P1, P2) U))
            {
                alias CommonType = CopyTypeQualifiers!(PointerTarget!U, void)*;
            }
            else
            {
                alias CommonType = void;
            }
        }
        else static if ((isPointer!(Args[0]) || isPolymorphicType!(Args[0]))
                     && is(TernaryType!Pair U))
        {
            alias CommonType = CommonType!(U, Args[2 .. $]);
        }
        else static if (is(TernaryType!(Args[0]*, Args[1]*)))
        {
            alias CommonType = CommonType!(TernaryType!Pair, Args[2 .. $]);
        }
        else
        {
            alias CommonType = void;
        }
    }
}

///
@nogc nothrow pure @safe unittest
{
    static assert(is(CommonType!(int, int, int) == int));
    static assert(is(CommonType!(ubyte, ushort, uint) == uint));
    static assert(is(CommonType!(int, uint) == void));

    static assert(is(CommonType!(int, const int) == int));
    static assert(is(CommonType!(const int, const int) == const int));

    static assert(is(CommonType!(int[], const(int)[]) == const(int)[]));
    static assert(is(CommonType!(string, char[]) == const(char)[]));

    class A
    {
    }
    static assert(is(CommonType!(const A, Object) == const Object));
}

@nogc nothrow pure @safe unittest
{
    static assert(is(CommonType!(void*, int*) == void*));
    static assert(is(CommonType!(void*, const(int)*) == const(void)*));
    static assert(is(CommonType!(void*, const(void)*) == const(void)*));
    static assert(is(CommonType!(int*, void*) == void*));
    static assert(is(CommonType!(const(int)*, void*) == const(void)*));
    static assert(is(CommonType!(const(void)*, void*) == const(void)*));

    static assert(is(CommonType!() == void));
    static assert(is(CommonType!(int*, const(int)*) == const(int)*));
    static assert(is(CommonType!(int**, const(int)**) == const(int*)*));

    static assert(is(CommonType!(float, double) == double));
    static assert(is(CommonType!(float, int) == void));

    static assert(is(CommonType!(bool, const bool) == bool));
    static assert(is(CommonType!(int, bool) == void));
    static assert(is(CommonType!(int, void) == void));
    static assert(is(CommonType!(Object, void*) == void));

    class A
    {
    }
    static assert(is(CommonType!(A, Object) == Object));
    static assert(is(CommonType!(const(A)*, Object*) == const(Object)*));
    static assert(is(CommonType!(A, typeof(null)) == A));

    class B : A
    {
    }
    class C : A
    {
    }
    static assert(is(CommonType!(B, C) == A));

    static struct S
    {
        int opCast(T : int)()
        {
            return 1;
        }
    }
    static assert(is(CommonType!(S, int) == void));
    static assert(is(CommonType!(const S, S) == const S));
}
