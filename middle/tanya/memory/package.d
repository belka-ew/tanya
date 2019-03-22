/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Dynamic memory management.
 *
 * Copyright: Eugene Wissner 2016-2019.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/middle/tanya/memory/package.d,
 *                 tanya/memory/package.d)
 */
module tanya.memory;

public import tanya.memory.allocator;
public import tanya.memory.lifetime;
deprecated("Use tanya.meta.trait.stateSize instead")
public import tanya.meta.trait : stateSize;
