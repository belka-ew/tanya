/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Type constructors.
 *
 * This module contains templates that allow to build new types from the
 * available ones.
 *
 * Copyright: Eugene Wissner 2017.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/typecons.d,
 *                 tanya/typecons.d)
 */
module tanya.typecons;

import std.meta;

/**
 * $(D_PSYMBOL Pair) can store two heterogeneous objects.
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
template Pair(Specs...)
{
    template parseSpecs(int fieldCount, Specs...)
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
                    = AliasSeq!(Specs[0],
                                parseSpecs!(fieldCount + 1, Specs[2 .. $]));
            }
            else
            {
                alias parseSpecs
                    = AliasSeq!(Specs[0],
                                parseSpecs!(fieldCount + 1, Specs[1 .. $]));
            }
        }
        else
        {
            static assert(false, "Invalid argument: " ~ Specs[0].stringof);
        }
    }

    struct Pair
    {
        /// Field types.
        alias Types = parseSpecs!(0, Specs);

        static assert(Types.length == 2, "Invalid argument count.");

        // Create field aliases.
        static if (is(typeof(Specs[1]) == string))
        {
            mixin("alias " ~ Specs[1] ~ " = expand[0];");
        }
        static if (is(typeof(Specs[2]) == string))
        {
            mixin("alias " ~ Specs[2] ~ " = expand[1];");
        }
        else static if (is(typeof(Specs[3]) == string))
        {
            mixin("alias " ~ Specs[3] ~ " = expand[1];");
        }

        /// Represents the values of the $(D_PSYMBOL Pair) as a list of values.
        Types expand;

        alias expand this;
    }
}

///
unittest
{
    static assert(is(Pair!(int, int)));
    static assert(!is(Pair!(int, 5)));

    static assert(is(Pair!(int, "first", int)));
    static assert(is(Pair!(int, "first", int, "second")));
    static assert(is(Pair!(int, "first", int)));

    static assert(is(Pair!(int, int, "second")));
    static assert(!is(Pair!("first", int, "second", int)));
    static assert(!is(Pair!(int, int, int)));

    static assert(!is(Pair!(int, "first")));
}
