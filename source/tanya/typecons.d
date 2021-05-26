/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Type constructors.
 *
 * This module contains templates that allow to build new types from the
 * available ones.
 *
 * Copyright: Eugene Wissner 2017-2020.
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
        in
        {
            assert(this.tag == staticIndexOf!(T, Types), "Variant isn't initialized");
        }
        do
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

        private ref typeof(this) copyAssign(T)(ref T that) return
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
        bool opEquals()(auto ref inout(Variant) that) inout
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
