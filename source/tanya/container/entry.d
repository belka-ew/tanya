/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/*
 * Internal package used by containers that rely on entries/nodes.
 *
 * Copyright: Eugene Wissner 2016.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 */  
module tanya.container.entry;

version (unittest)
{
	package struct ConstEqualsStruct
	{
		int opEquals(typeof(this) that) const @nogc
		{
			return true;
		}
	}

	package struct MutableEqualsStruct
	{
		int opEquals(typeof(this) that) @nogc
		{
			return true;
		}
	}

	package struct NoEqualsStruct
	{
	}
}

package struct Entry(T)
{
	/// Item content.
	T content;

	/// Next item.
	Entry* next;
}
