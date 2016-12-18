/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Copyright: Eugene Wissner 2016.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:belka@caraus.de, Eugene Wissner)
 */
module tanya.traits;

import std.traits;
import std.meta;

/**
 * Params:
 * 	T = Type.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM T) is a reference type or a pointer,
 *          $(D_KEYWORD false) otherwise.
 */
enum bool isReference(T) = isDynamicArray!T || isPointer!T
                        || is(T == class) || is(T == interface);

/**
 * Initializer list.
 *
 * Generates a static array with elements from $(D_PARAM args). All elements
 * should have the same type. It can be used in constructors which accept a
 * list of the elements of the same type in the situations where variadic
 * functions and templates can't be used.
 *
 * Params:
 * 	Args = Argument type.
 * 	args = Arguments.
 */
static enum IL(Args...)(Args args)
	if (Args.length > 0)
{
	alias BaseType = typeof(args[0]);

	BaseType[args.length] result;

	foreach (i, a; args)
	{
		static assert(isImplicitlyConvertible!(typeof(a), BaseType));
		result[i] = a;
	}
	return result;
}

///
unittest
{
	static assert(IL(1, 5, 8).length == 3);
}
