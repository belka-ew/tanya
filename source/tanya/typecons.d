/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Type constructors.
 *
 * This module contains templates that allow to build new types from the
 * available ones.
 *
 * Copyright: Eugene Wissner 2017-2019.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/typecons.d,
 *                 tanya/typecons.d)
 */
module tanya.typecons;

import tanya.algorithm.mutation;
import tanya.format;
import tanya.functional;
import tanya.meta.metafunction;
import tanya.meta.trait;
version (unittest) import tanya.test.stub;

/**
 * $(D_PSYMBOL Tuple) can store two or more heterogeneous objects.
 *
 * The objects can by accessed by index as `obj[0]` and `obj[1]` or by optional
 * names (e.g. `obj.first`).
 *
 * $(D_PARAM Specs) contains a list of object types and names. First
 * comes the object type, then an optional string containing the name.
 * If you want the object be accessible only by its index (`0` or `1`),
 * just skip the name.
 *
 * Params:
 *  Specs = Field types and names.
 *
 * See_Also: $(D_PSYMBOL tuple).
 */
template Tuple(Specs...)
{
    template parseSpecs(size_t fieldCount, Specs...)
    {
        static if (Specs.length == 0)
        {
            alias parseSpecs = AliasSeq!();
        }
        else static if (is(Specs[0]) && fieldCount < 2)
        {
            static if (is(typeof(Specs[1]) == string))
            {
                alias parseSpecs
                    = AliasSeq!(Pack!(Specs[0], Specs[1]),
                                parseSpecs!(fieldCount + 1, Specs[2 .. $]));
            }
            else
            {
                alias parseSpecs
                    = AliasSeq!(Pack!(Specs[0]),
                                parseSpecs!(fieldCount + 1, Specs[1 .. $]));
            }
        }
        else
        {
            static assert(false, "Invalid argument: " ~ Specs[0].stringof);
        }
    }

    alias ChooseType(alias T) = T.Seq[0];
    alias ParsedSpecs = parseSpecs!(0, Specs);

    static assert(ParsedSpecs.length > 1, "Invalid argument count");

    private string formatAliases(size_t n, Specs...)()
    {
        static if (Specs.length == 0)
        {
            return "";
        }
        else
        {
            string fieldAlias;
            static if (Specs[0].length == 2)
            {
                char[21] buffer;
                fieldAlias = "alias " ~ Specs[0][1] ~ " = expand["
                           ~ integral2String(n, buffer).idup ~ "];";
            }
            return fieldAlias ~ formatAliases!(n + 1, Specs[1 .. $])();
        }
    }

    struct Tuple
    {
        /// Field types.
        alias Types = Map!(ChooseType, ParsedSpecs);

        // Create field aliases.
        mixin(formatAliases!(0, ParsedSpecs[0 .. $])());

        /// Represents the values of the $(D_PSYMBOL Tuple) as a list of values.
        Types expand;

        alias expand this;
    }
}

///
@nogc nothrow pure @safe unittest
{
    auto pair = Tuple!(int, "first", string, "second")(1, "second");
    assert(pair.first == 1);
    assert(pair[0] == 1);
    assert(pair.second == "second");
    assert(pair[1] == "second");
}

@nogc nothrow pure @safe unittest
{
    static assert(is(Tuple!(int, int)));
    static assert(!is(Tuple!(int, 5)));

    static assert(is(Tuple!(int, "first", int)));
    static assert(is(Tuple!(int, "first", int, "second")));
    static assert(is(Tuple!(int, "first", int)));

    static assert(is(Tuple!(int, int, "second")));
    static assert(!is(Tuple!("first", int, "second", int)));
    static assert(!is(Tuple!(int, int, int)));

    static assert(!is(Tuple!(int, "first")));

    static assert(!is(Tuple!(int, double, char)));
    static assert(!is(Tuple!(int, "first", double, "second", char, "third")));
}

/**
 * Creates a new $(D_PSYMBOL Tuple).
 *
 * Params:
 *  Names = Field names.
 *
 * See_Also: $(D_PSYMBOL Tuple).
 */
template tuple(Names...)
{
    /**
     * Creates a new $(D_PSYMBOL Tuple).
     *
     * Params:
     *  Args = Field types.
     *  args = Field values.
     *
     * Returns: Newly created $(D_PSYMBOL Tuple).
     */
    auto tuple(Args...)(auto ref Args args)
    if (Args.length >= Names.length && isTypeTuple!Args)
    {
        alias Zipped = ZipWith!(AliasSeq, Pack!Args, Pack!Names);
        alias Nameless = Args[Names.length .. $];

        return Tuple!(Zipped, Nameless)(forward!args);
    }
}

///
@nogc nothrow pure @safe unittest
{
    auto t = tuple!("one", "two")(20, 5);
    assert(t.one == 20);
    assert(t.two == 5);
}

/**
 * $(D_PSYMBOL Option) is a type that contains an optional value.
 *
 * Params:
 *  T = Type of the encapsulated value.
 *
 * See_Also: $(D_PSYMBOL option).
 */
struct Option(T)
{
    private bool isNothing_ = true;
    private T value = void;

    /**
     * Constructs a new option with $(D_PARAM value).
     *
     * Params:
     *  value = Encapsulated value.
     */
    this()(ref T value)
    {
        this.value = value;
        this.isNothing_ = false;
    }

    /// ditto
    this()(T value) @trusted
    {
        moveEmplace(value, this.value);
        this.isNothing_ = false;
    }

    /**
     * Tells if the option is just a value or nothing.
     *
     * Returns: $(D_KEYWORD true) if this $(D_PSYMBOL Option) contains a nothing,
     *          $(D_KEYWORD false) if it contains a value.
     */
    @property bool isNothing() const
    {
        return this.isNothing_;
    }

    /**
     * Returns the encapsulated value.
     *
     * Returns: Value encapsulated in this $(D_PSYMBOL Option).
     *
     * See_Also: $(D_PSYMBOL or).
     *
     * Precondition: `!isNothing`.
     */
    @property ref inout(T) get() inout
    in (!isNothing, "Option is nothing")
    {
        return this.value;
    }

    /// ditto
    deprecated("Call Option.get explicitly instead of relying on alias this")
    @property ref inout(T) get_() inout
    in (!isNothing, "Option is nothing")
    {
        return this.value;
    }

    /**
     * Returns the encapsulated value if available or a default value
     * otherwise.
     *
     * Note that the contained value can be returned by reference only if the
     * default value is passed by reference as well.
     *
     * Params:
     *  U            = Type of the default value.
     *  defaultValue = Default value.
     *
     * Returns: The value of this $(D_PSYMBOL Option) if available,
     *          $(D_PARAM defaultValue) otherwise.
     *
     * See_Also: $(D_PSYMBOL isNothing), $(D_PSYMBOL get).
     */
    @property U or(U)(U defaultValue) inout
    if (is(U == T) && isCopyable!T)
    {
        return isNothing ? defaultValue : this.value;
    }

    /// ditto
    @property ref inout(T) or(ref inout(T) defaultValue) inout
    {
        return isNothing ? defaultValue : this.value;
    }

    /**
     * Casts this $(D_PSYMBOL Option) to $(D_KEYWORD bool).
     *
     * An $(D_PSYMBOL Option) is $(D_KEYWORD true) if it contains a value,
     * ($D_KEYWORD false) if it contains nothing.
     *
     * Returns: $(D_KEYWORD true) if this $(D_PSYMBOL Option) contains a value,
     *          ($D_KEYWORD false) if it contains nothing.
     */
    bool opCast(U : bool)()
    {
        return !isNothing;
    }

    /**
     * Compares this $(D_PSYMBOL Option) with $(D_PARAM that).
     *
     * If both objects are options of the same type and they don't contain a
     * value, they are considered equal. If only one of them contains a value,
     * they aren't equal. Otherwise, the encapsulated values are compared for
     * equality.
     *
     * If $(D_PARAM U) is a type comparable with the type encapsulated by this
     * $(D_PSYMBOL Option), the value of this $(D_PSYMBOL Option) is compared
     * with $(D_PARAM that), this $(D_PSYMBOL Option) must have a value then.
     *
     * Params:
     *  U    = Type of the object to compare with.
     *  that = Object to compare with.
     *
     * Returns: $(D_KEYWORD true) if this $(D_PSYMBOL Option) and
     *          $(D_PARAM that) are equal, $(D_KEYWORD false) if not.
     *
     * Precondition: `!isNothing` if $(D_PARAM U) is equality comparable with
     *               $(D_PARAM T).
     */
    bool opEquals(U)(auto ref const U that) const
    if (is(U == Option))
    {
        if (!isNothing && !that.isNothing)
        {
            return this.value == that.value;
        }
        return isNothing == that.isNothing;
    }

    /// ditto
    bool opEquals(U)(auto ref const U that) const
    if (ifTestable!(U, a => a == T.init) && !is(U == Option))
    in
    {
        assert(!isNothing);
    }
    do
    {
        return get == that;
    }

    /**
     * Resets this $(D_PSYMBOL Option) and destroys the contained value.
     *
     * $(D_PSYMBOL reset) can be safely called on an $(D_PSYMBOL Option) that
     * doesn't contain any value.
     */
    void reset()
    {
        static if (hasElaborateDestructor!T)
        {
            destroy(this.value);
        }
        this.isNothing_ = true;
    }

    /**
     * Assigns a new value.
     *
     * Params:
     *  U    = Type of the new value.
     *  that = New value.
     *
     * Returns: $(D_KEYWORD this).
     */
    ref typeof(this) opAssign(U)(ref U that)
    if (is(U : T) && !is(U == Option))
    {
        this.value = that;
        this.isNothing_ = false;
        return this;
    }

    /// ditto
    ref typeof(this) opAssign(U)(U that)
    if (is(U == T))
    {
        move(that, this.value);
        this.isNothing_ = false;
        return this;
    }

    /// ditto
    ref typeof(this) opAssign(U)(ref U that)
    if (is(U == Option))
    {
        if (that.isNothing)
        {
            reset();
        }
        else
        {
            this.value = that.get;
            this.isNothing_ = false;
        }
        return this;
    }

    /// ditto
    ref typeof(this) opAssign(U)(U that)
    if (is(U == Option))
    {
        move(that.value, this.value);
        this.isNothing_ = that.isNothing_;
        return this;
    }

    version (D_Ddoc)
    {
        /**
         * If $(D_PARAM T) has a `toHash()` method, $(D_PSYMBOL Option) defines
         * `toHash()` which returns `T.toHash()` if it is set or 0 otherwise.
         *
         * Returns: Hash value.
         */
        size_t toHash() const;
    }
    else static if (is(typeof(T.init.toHash()) == size_t))
    {
        size_t toHash() const
        {
            return isNothing ? 0U : this.value.toHash();
        }
    }

    alias get_ this;
}

///
@nogc nothrow pure @safe unittest
{
    Option!int option;
    assert(option.isNothing);
    assert(option.or(8) == 8);
    
    option = 5;
    assert(!option.isNothing);
    assert(option.get == 5);
    assert(option.or(8) == 5);

    option.reset();
    assert(option.isNothing);
}

// Assigns a new value
@nogc nothrow pure @safe unittest
{
    {
        Option!int option = 5;
        option = 8;
        assert(!option.isNothing);
        assert(option == 8);
    }
    {
        Option!int option;
        const int newValue = 8;
        assert(option.isNothing);
        option = newValue;
        assert(!option.isNothing);
        assert(option == newValue);
    }
    {
        Option!int option1;
        Option!int option2 = 5;
        assert(option1.isNothing);
        option1 = option2;
        assert(!option1.isNothing);
        assert(option1.get == 5);
    }
}

// Constructs with a value passed by reference
@nogc nothrow pure @safe unittest
{
    int i = 5;
    assert(Option!int(i).get == 5);
}

// Moving
@nogc nothrow pure @safe unittest
{
    static assert(is(typeof(Option!NonCopyable(NonCopyable()))));
    // The value cannot be returned by reference because the default value
    // isn't passed by reference
    static assert(!is(typeof(Option!DisabledPostblit().or(NonCopyable()))));
    {
        NonCopyable notCopyable;
        static assert(is(typeof(Option!NonCopyable().or(notCopyable))));
    }
    {
        Option!NonCopyable option;
        assert(option.isNothing);
        option = NonCopyable();
        assert(!option.isNothing);
    }
    {
        Option!NonCopyable option;
        assert(option.isNothing);
        option = Option!NonCopyable(NonCopyable());
        assert(!option.isNothing);
    }
}

// Cast to bool is done before touching the encapsulated value
@nogc nothrow pure @safe unittest
{
    assert(Option!bool(false));
}

// Option can be const
@nogc nothrow pure @safe unittest
{
    assert((const Option!int(5)).get == 5);
    assert((const Option!int()).or(5) == 5);
}

// Equality
@nogc nothrow pure @safe unittest
{
    assert(Option!int() == Option!int());
    assert(Option!int(0) != Option!int());
    assert(Option!int(5) == Option!int(5));
    assert(Option!int(5) == 5);
    assert(Option!int(5) == cast(ubyte) 5);
}

// Returns default value
@nogc nothrow pure @safe unittest
{
    int i = 5;
    assert(((ref e) => e)(Option!int().or(i)) == 5);
}

// Implements toHash() for nothing
@nogc nothrow pure @safe unittest
{
    alias OptionT = Option!Hashable;
    assert(OptionT().toHash() == 0U);
    assert(OptionT(Hashable(1U)).toHash() == 1U);
}

// Can assign Option that is nothing
@nogc nothrow pure @safe unittest
{
    auto option1 = Option!int(5);
    Option!int option2;
    option1 = option2;
    assert(option1.isNothing);
}

/**
 * Creates a new $(D_PSYMBOL Option).
 *
 * Params:
 *  T     = Option type.
 *  value = Initial value.
 *
 * See_Also: $(D_PSYMBOL Option).
 */
Option!T option(T)(auto ref T value)
{
    return Option!T(forward!value);
}

/// ditto
Option!T option(T)()
{
    return Option!T();
}

///
@nogc nothrow pure @safe unittest
{
    assert(option!int().isNothing);
    assert(option(5) == 5);
}

private struct VariantAccessorInfo
{
    string accessor;
    size_t tag;
}

/**
 * Tagged union.
 *
 * Params:
 *  Specs = Types of the union members.
 */
package (tanya) template Variant(Specs...)
if (isTypeTuple!Specs)
{
    union AlignedUnion(Args...)
    {
        static if (Args.length > 0)
        {
            Args[0] value;
        }
        static if (Args.length > 1)
        {
            AlignedUnion!(Args[1 .. $]) rest;
        }
    }

    template accessor(T, Union)
    {
        enum VariantAccessorInfo info = accessorImpl!(T, Union, 1);
        enum accessor = VariantAccessorInfo("this.values" ~ info.accessor, info.tag);
    }

    template accessorImpl(T, Union, size_t tag)
    {
        static if (is(T == typeof(Union.value)))
        {
            enum accessorImpl = VariantAccessorInfo(".value", tag);
        }
        else
        {
            enum VariantAccessorInfo info = accessorImpl!(T, typeof(Union.rest), tag + 1);
            enum accessorImpl = VariantAccessorInfo(".rest" ~ info.accessor, info.tag);
        }
    }

    struct Variant
    {
        /// Types can be present in this $(D_PSYMBOL Variant).
        alias Types = Specs;

        private ptrdiff_t tag = -1;
        private AlignedUnion!Types values;

        this(T)(auto ref T value)
        if (canFind!(T, Types))
        {
            opAssign!T(forward!value);
        }

        bool hasValue() const
        {
            return this.tag != -1;
        }

        bool peek(T)() const
        if (canFind!(T, Types))
        {
            return this.tag == staticIndexOf!(T, Types);
        }

        ref inout(T) get(T)() inout
        if (canFind!(T, Types))
        in (this.tag == staticIndexOf!(T, Types), "Variant isn't initialized")
        {
            mixin("return " ~ accessor!(T, AlignedUnion!Types).accessor ~ ";");
        }

        typeof(this) opAssign(T)(auto ref T value)
        if (canFind!(T, Types))
        {
            this.tag = staticIndexOf!(T, Types);
            mixin(accessor!(T, AlignedUnion!Types).accessor ~ " = forward!value;");
            return this;
        }

        TypeInfo type()
        {
            static foreach (i, Type; Types)
            {
                if (this.tag == i)
                {
                    return typeid(Type);
                }
            }
            assert(false, "Variant isn't initialized");
        }

        bool opEquals()(auto ref inout Variant that) inout
        {
            if (this.tag != that.tag)
            {
                return false;
            }
            static foreach (i, Type; Types)
            {
                if (this.tag == i)
                {
                    return get!Type == that.get!Type;
                }
            }
            return true;
        }
    }
}

@nogc nothrow pure @safe unittest
{
    Variant!(int, double) variant;
    variant = 5;
    assert(variant.peek!int);
}

@nogc nothrow pure @safe unittest
{
    Variant!(int, double) variant;
    variant = 5.0;
    assert(!variant.peek!int);
}

@nogc nothrow pure @safe unittest
{
    Variant!(int, double) variant = 5;
    assert(variant.get!int == 5);
}

@nogc nothrow pure @safe unittest
{
    static assert(is(Variant!(int, float)));
    static assert(is(Variant!int));
}

@nogc nothrow pure @safe unittest
{
    static struct WithDestructorAndCopy
    {
        this(this) @nogc nothrow pure @safe
        {
        }

        ~this() @nogc nothrow pure @safe
        {
        }
    }
    static assert(is(Variant!WithDestructorAndCopy));
}

// Equality compares the underlying objects
@nogc nothrow pure @safe unittest
{
    Variant!(int, double) variant1 = 5;
    Variant!(int, double) variant2 = 5;
    assert(variant1 == variant2);
}

@nogc nothrow pure @safe unittest
{
    Variant!(int, double) variant1 = 5;
    Variant!(int, double) variant2 = 6;
    assert(variant1 != variant2);
}

// Differently typed variants aren't equal
@nogc nothrow pure @safe unittest
{
    Variant!(int, double) variant1 = 5;
    Variant!(int, double) variant2 = 5.0;
    assert(variant1 != variant2);
}

// Uninitialized variants are equal
@nogc nothrow pure @safe unittest
{
    Variant!(int, double) variant1, variant2;
    assert(variant1 == variant2);
}
