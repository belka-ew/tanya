/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * $(D_PSYMBOL tanya.range.array) implements range primitives for built-in arrays.
 *
 * This module is a submodule of
 * $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/range/package.d, tanya.range).
 *
 * After importing of
 * $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/range/array.d, tanya/range/array.d)
 * built-in arrays can act as bidirectional ranges. For that to work the module
 * defines a set of functions that accept a built-in array of any type as their
 * first argument, so thanks to UFCS (Uniform Function Call Syntax) they can be
 * called as if they were array member functions. For example the arrays the
 * `.length`-property, but no `.empty` property. So here can be find the
 * $(D_PSYMBOL empty) function. Since $(D_INLINECODE empty(array)) and
 * $(D_INLINECODE array.empty) are equal for the arrays, arrays get a faked
 * property `empty`.
 *
 * The functions in this module don't change array elements or its underlying
 * storage, but some functions alter the slice. Each array maintains a pointer
 * to its data and the length and there can be several pointers which point to
 * the same data. Array pointer can be advanced and the length can be reduced
 * without changing the underlying storage. So slices offer the possibility to
 * have multiple views into the same array, point to different positions inside
 * it.
 *
 * Strings ($(D_INLINECODE char[]), (D_INLINECODE wchar[]) and
 * (D_INLINECODE dchar[])) are treated as any other normal array, they aren't
 * auto-decoded.
 *
 * Copyright: Eugene Wissner 2017-2019.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/range/array.d,
 *                 tanya/range/array.d)
 */
module tanya.range.array;

/**
 * Returns the first element of the $(D_PARAM array).
 *
 * The element is returned by reference, so $(D_PSYMBOL front) can be also used
 * to change the first element of $(D_PARAM array) if it is mutable.
 *
 * Params:
 *  T     = Element type of $(D_PARAM array).
 *  array = Built-in array.
 *
 * Returns: First element.
 *
 * Precondition: $(D_INLINECODE array.length > 0).
 */
@property ref inout(T) front(T)(return scope inout(T)[] array)
in (array.length > 0)
{
    return array[0];
}

///
@nogc nothrow pure @safe unittest
{
    string s = "Wenn die Wunde nicht mehr wehtut, schmerzt die Narbe";
    static assert(is(typeof(s.front) == immutable char));
    assert(s.front == 'W');

    wstring w = "Волны несутся, гремя и сверкая";
    static assert(is(typeof(w.front) == immutable wchar));
    assert(w.front == 'В');

    dstring d = "Для писателя память - это почти все";
    static assert(is(typeof(d.front) == immutable dchar));
    assert(d.front == 'Д');
}

/**
 * Returns the last element of the $(D_PARAM array).
 *
 * The element is returned by reference, so $(D_PSYMBOL back) can be also used
 * to change the last element of $(D_PARAM array) if it is mutable.
 *
 * Params:
 *  T     = Element type of $(D_PARAM array).
 *  array = Built-in array.
 *
 * Returns: Last element.
 *
 * Precondition: $(D_INLINECODE array.length > 0).
 */
@property ref inout(T) back(T)(return scope inout(T)[] array)
in (array.length > 0)
{
    return array[$ - 1];
}

///
@nogc nothrow pure @safe unittest
{
    string s = "Brecht";
    static assert(is(typeof(s.back) == immutable char));
    assert(s.back == 't');

    wstring w = "Тютчев";
    static assert(is(typeof(w.back) == immutable wchar));
    assert(w.back == 'в');

    dstring d = "Паустовский";
    static assert(is(typeof(d.back) == immutable dchar));
    assert(d.back == 'й');
}

/**
 * $(D_PSYMBOL popFront) and $(D_PSYMBOL popBack) advance the $(D_PARAM array)
 * and remove one element from its back, respectively.
 *
 * $(D_PSYMBOL popFront) and $(D_PSYMBOL popBack) don't alter the array
 * storage, they only narrow the view into the array.
 *
 * Params:
 *  T     = Element type of $(D_PARAM array).
 *  array = Built-in array.
 *
 * Precondition: $(D_INLINECODE array.length > 0).
 */
void popFront(T)(scope ref inout(T)[] array)
in (array.length > 0)
{
    array = array[1 .. $];
}

/// ditto
void popBack(T)(scope ref inout(T)[] array)
in (array.length > 0)
{
    array = array[0 .. $ - 1];
}

///
@nogc nothrow pure @safe unittest
{
    wstring array = "Der finstere Ozean der Metaphysik. Nietzsche";

    array.popFront();
    assert(array.length == 43);
    assert(array.front == 'e');

    array.popBack();
    assert(array.length == 42);
    assert(array.back == 'h');
}

/**
 * Tests whether $(D_PARAM array) is empty.
 *
 * Params:
 *  T     = Element type of $(D_PARAM array).
 *  array = Built-in array.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM array) has no elements,
 *          $(D_KEYWORD false) otherwise.
 */
@property bool empty(T)(scope const T[] array)
{
    return array.length == 0;
}

///
@nogc nothrow pure @safe unittest
{
    int[1] array;
    assert(!array.empty);
    assert(array[1 .. 1].empty);
}

/**
 * Returns a copy of the slice $(D_PARAM array).
 *
 * $(D_PSYMBOL save) doesn't copy the array itself, but only the data pointer
 * and the length.
 *
 * Params:
 *  T     = Element type of $(D_PARAM array).
 *  array = Built-in array.
 *
 * Returns: A copy of the slice $(D_PARAM array).
 */
@property inout(T)[] save(T)(return scope inout(T)[] array)
{
    return array;
}

///
@nogc nothrow pure @safe unittest
{
    ubyte[8] array;
    auto slice = array.save;

    assert(slice.length == array.length);
    slice.popFront();
    assert(slice.length < array.length);
}
