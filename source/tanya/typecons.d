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

import tanya.format;
import tanya.memory.lifetime;
import tanya.meta.metafunction;
import tanya.meta.trait;

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
    in (!isNothing)
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

/**
 * Type that can hold one of the types listed as its template parameters.
 *
 * $(D_PSYMBOL Variant) is a type similar to $(D_KEYWORD union), but
 * $(D_PSYMBOL Variant) keeps track of the actually used type and throws an
 * assertion error when trying to access an invalid type at runtime.
 *
 * Params:
 *  Specs = Types this $(D_SPYBMOL Variant) can hold.
 */
template Variant(Specs...)
if (isTypeTuple!Specs && NoDuplicates!Specs.length == Specs.length)
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

    private struct VariantAccessorInfo
    {
        string accessor;
        ptrdiff_t tag;
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

        /**
         * Constructs this $(D_PSYMBOL Variant) with one of the types supported
         * in it.
         *
         * Params:
         *  T     = Type of the initial value.
         *  value = Initial value.
         */
        this(T)(ref T value)
        if (canFind!(T, Types))
        {
            copyAssign!T(value);
        }

        /// ditto
        this(T)(T value)
        if (canFind!(T, Types))
        {
            moveAssign!T(value);
        }

        ~this()
        {
            reset();
        }

        this(this)
        {
            alias pred(U) = hasElaborateCopyConstructor!(U.Seq[1]);
            static foreach (Type; Filter!(pred, Enumerate!Types))
            {
                if (this.tag == Type.Seq[0])
                {
                    get!(Type.Seq[1]).__postblit();
                }
            }
        }

        /**
         * Tells whether this $(D_PSYMBOL Variant) is initialized.
         *
         * Returns: $(D_KEYWORD true) if this $(D_PSYMBOL Variant) contains a
         *          value, $(D_KEYWORD false) otherwise.
         */
        bool hasValue() const
        {
            return this.tag != -1;
        }

        /**
         * Tells whether this $(D_PSYMBOL Variant) holds currently a value of
         * type $(D_PARAM T).
         *
         * Params:
         *  T = Examined type.
         *
         * Returns: $(D_KEYWORD true) if this $(D_PSYMBOL Variant) currently
         *          contains a value of type $(D_PARAM T), $(D_KEYWORD false)
         *          otherwise.
         */
        bool peek(T)() const
        if (canFind!(T, Types))
        {
            return this.tag == staticIndexOf!(T, Types);
        }

        /**
         * Returns the underlying value, assuming it is of the type $(D_PARAM T).
         *
         * Params:
         *  T = Type of the value should be returned.
         *
         * Returns: The underyling value.
         *
         * Precondition: The $(D_PSYMBOL Variant) has a value.
         *
         * See_Also: $(D_PSYMBOL peek), $(D_PSYMBOL hasValue).
         */
        ref inout(T) get(T)() inout
        if (canFind!(T, Types))
        in (this.tag == staticIndexOf!(T, Types), "Variant isn't initialized")
        {
            mixin("return " ~ accessor!(T, AlignedUnion!Types).accessor ~ ";");
        }

        /**
         * Reassigns the value.
         *
         * Params:
         *  T    = Type of the new value
         *  that = New value.
         *
         * Returns: $(D_KEYWORD this).
         */
        ref typeof(this) opAssign(T)(T that)
        if (canFind!(T, Types))
        {
            reset();
            return moveAssign!T(that);
        }

        /// ditto
        ref typeof(this) opAssign(T)(ref T that)
        if (canFind!(T, Types))
        {
            reset();
            return copyAssign!T(that);
        }

        private ref typeof(this) moveAssign(T)(ref T that) @trusted
        {
            this.tag = staticIndexOf!(T, Types);

            enum string accessorMixin = accessor!(T, AlignedUnion!Types).accessor;
            moveEmplace(that, mixin(accessorMixin));

            return this;
        }

        private ref typeof(this) copyAssign(T)(ref T that)
        {
            this.tag = staticIndexOf!(T, Types);

            enum string accessorMixin = accessor!(T, AlignedUnion!Types).accessor;
            emplace!T((() @trusted => (&mixin(accessorMixin))[0 .. 1])(), that);

            return this;
        }

        private void reset()
        {
            alias pred(U) = hasElaborateDestructor!(U.Seq[1]);
            static foreach (Type; Filter!(pred, Enumerate!Types))
            {
                if (this.tag == Type.Seq[0])
                {
                    destroy(get!(Type.Seq[1]));
                }
            }
        }

        /**
         * Returns $(D_PSYMBOL TypeInfo) corresponding to the current type.
         *
         * If this $(D_PSYMBOL Variant) isn't initialized, returns
         * $(D_KEYWORD null).
         *
         * Returns: $(D_PSYMBOL TypeInfo) of the current type.
         */
        @property TypeInfo type()
        {
            static foreach (i, Type; Types)
            {
                if (this.tag == i)
                {
                    return typeid(Type);
                }
            }
            return null;
        }

        /**
         * Compares this $(D_PSYMBOL Variant) with another one with the same
         * specification for equality.
         *
         * $(UL
         *  $(LI If both hold values of the same type, these values are
         *       compared.)
         *  $(LI If they hold values of different types, then the
         *       $(D_PSYMBOL Variant)s aren't equal.)
         *  $(LI If only one of them is initialized but another one not, they
         *       aren't equal.)
         *  $(LI If neither of them is initialized, they are equal.)
         * )
         *
         * Params:
         *  that = The $(D_PSYMBOL Variant) to compare with.
         *
         * Returns: $(D_KEYWORD true) if this $(D_PSYMBOL Variant) is equal to
         *          $(D_PARAM that), $(D_KEYWORD false) otherwise.
         */
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

///
@nogc nothrow pure @safe unittest
{
    Variant!(int, double) variant = 5;
    assert(variant.peek!int);
    assert(variant.get!int == 5);

    variant = 5.4;
    assert(!variant.peek!int);
    assert(variant.get!double == 5.4);
}
