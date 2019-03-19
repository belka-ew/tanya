/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
module tanya.math.tests;

import tanya.math;

static if (ieeePrecision!float == IEEEPrecision.doubleExtended)
@nogc nothrow pure @safe unittest
{
    assert(classify(1.68105e-10) == FloatingPointClass.normal);
    assert(classify(1.68105e-4932L) == FloatingPointClass.subnormal);

    // Emulate unnormals, because they aren't generated anymore since i386
    FloatBits!real unnormal;
    unnormal.exp = 0x123;
    unnormal.mantissa = 0x1;
    assert(classify(unnormal) == FloatingPointClass.subnormal);
}

@nogc nothrow pure @safe unittest
{
    assert(74653.isPseudoprime);
    assert(74687.isPseudoprime);
    assert(74699.isPseudoprime);
    assert(74707.isPseudoprime);
    assert(74713.isPseudoprime);
    assert(74717.isPseudoprime);
    assert(74719.isPseudoprime);
    assert(74747.isPseudoprime);
    assert(74759.isPseudoprime);
    assert(74761.isPseudoprime);
    assert(74771.isPseudoprime);
    assert(74779.isPseudoprime);
    assert(74797.isPseudoprime);
    assert(74821.isPseudoprime);
    assert(74827.isPseudoprime);
    assert(9973.isPseudoprime);
    assert(49979693.isPseudoprime);
    assert(104395303.isPseudoprime);
    assert(593441861.isPseudoprime);
    assert(104729.isPseudoprime);
    assert(15485867.isPseudoprime);
    assert(49979693.isPseudoprime);
    assert(104395303.isPseudoprime);
    assert(593441861.isPseudoprime);
    assert(899809363.isPseudoprime);
    assert(982451653.isPseudoprime);
}
