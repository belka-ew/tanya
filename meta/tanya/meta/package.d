/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Template metaprogramming.
 *
 * This package contains utilities to acquire type information at compile-time,
 * to transform from one type to another. It has also different algorithms for
 * iterating, searching and modifying template arguments.
 *
 * Copyright: Eugene Wissner 2017-2020.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/meta/tanya/meta/package.d,
 *                 tanya/meta/package.d)
 */
module tanya.meta;

public import tanya.meta.metafunction;
public import tanya.meta.trait;
public import tanya.meta.transform;
