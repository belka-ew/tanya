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

/**
 * Params:
 * 	T = Type.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM T) is a reference type or a pointer,
 *          $(D_KEYWORD false) otherwise.
 */
enum bool isReference(T) = isDynamicArray!T || isPointer!T
                        || is(T == class) || is(T == interface);
