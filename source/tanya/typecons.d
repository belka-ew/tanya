/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Type constructors.
 *
 * This module contains templates that allow to build new types from the
 * available ones.
 *
 * Copyright: Eugene Wissner 2017-2018.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/typecons.d,
 *                 tanya/typecons.d)
 */
module tanya.typecons;

import tanya.meta.metafunction : AliasSeq, AliasTuple = Tuple, Map;

deprecated("Use tanya.typecons.Tuple instead")
template Pair(Specs...)
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
                    = AliasSeq!(AliasTuple!(Specs[0], Specs[1]),
                                parseSpecs!(fieldCount + 1, Specs[2 .. $]));
            }
            else
            {
                alias parseSpecs
                    = AliasSeq!(AliasTuple!(Specs[0]),
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

    static assert(ParsedSpecs.length == 2, "Invalid argument count");

    struct Pair
    {
        /// Field types.
        alias Types = Map!(ChooseType, ParsedSpecs);

        // Create field aliases.
        static if (ParsedSpecs[0].length == 2)
        {
            mixin("alias " ~ ParsedSpecs[0][1] ~ " = expand[0];");
        }
        static if (ParsedSpecs[1].length == 2)
        {
            mixin("alias " ~ ParsedSpecs[1][1] ~ " = expand[1];");
        }

        /// Represents the values of the $(D_PSYMBOL Pair) as a list of values.
        Types expand;

        alias expand this;
    }
}

/**
 * $(D_PSYMBOL Tuple) can store two heterogeneous objects.
 *
 * The objects can by accessed by index as $(D_INLINECODE obj[0]) and
 * $(D_INLINECODE obj[1]) or by optional names (e.g.
 * $(D_INLINECODE obj.first)).
 *
 * $(D_PARAM Specs) contains a list of object types and names. First
 * comes the object type, then an optional string containing the name.
 * If you want the object be accessible only by its index (`0` or `1`),
 * just skip the name.
 *
 * Params:
 *  Specs = Field types and names.
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
                    = AliasSeq!(AliasTuple!(Specs[0], Specs[1]),
                                parseSpecs!(fieldCount + 1, Specs[2 .. $]));
            }
            else
            {
                alias parseSpecs
                    = AliasSeq!(AliasTuple!(Specs[0]),
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

    static assert(ParsedSpecs.length == 2, "Invalid argument count");

    struct Tuple
    {
        /// Field types.
        alias Types = Map!(ChooseType, ParsedSpecs);

        // Create field aliases.
        static if (ParsedSpecs[0].length == 2)
        {
            mixin("alias " ~ ParsedSpecs[0][1] ~ " = expand[0];");
        }
        static if (ParsedSpecs[1].length == 2)
        {
            mixin("alias " ~ ParsedSpecs[1][1] ~ " = expand[1];");
        }

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
}
