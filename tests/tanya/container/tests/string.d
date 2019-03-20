/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
module tanya.container.tests.string;

import tanya.container.string;
import tanya.test.assertion;

@nogc nothrow pure @safe unittest
{
    auto s = String(0, 'K');
    assert(s.length == 0);
}

// Allocates enough space for 3-byte character.
@nogc pure @safe unittest
{
    String s;
    s.insertBack('\u8100');
}

@nogc pure @safe unittest
{
    assertThrown!UTFException(() => String(1, cast(dchar) 0xd900));
    assertThrown!UTFException(() => String(1, cast(wchar) 0xd900));
}

@nogc nothrow pure @safe unittest
{
    auto s1 = String("Buttercup");
    auto s2 = String("Cap");
    s2[] = s1[6 .. $];
    assert(s2 == "cup");
}

@nogc nothrow pure @safe unittest
{
    auto s1 = String("Wow");
    s1[] = 'a';
    assert(s1 == "aaa");
}

@nogc nothrow pure @safe unittest
{
    auto s1 = String("ö");
    s1[] = "oe";
    assert(s1 == "oe");
}

// Postblit works
@nogc nothrow pure @safe unittest
{
    void internFunc(String arg)
    {
    }
    void middleFunc(S...)(S args)
    {
        foreach (arg; args)
        {
            internFunc(arg);
        }
    }
    void topFunc(String args)
    {
        middleFunc(args);
    }
    topFunc(String("asdf"));
}

// Const range produces mutable ranges
@nogc pure @safe unittest
{
    auto s = const String("И снизу лед, и сверху - маюсь между.");
    {
        const constRange = s[];

        auto fromConstRange = constRange[];
        fromConstRange.popFront();
        assert(fromConstRange.front == s[1]);

        fromConstRange = constRange[0 .. $];
        fromConstRange.popFront();
        assert(fromConstRange.front == s[1]);

        assert(constRange.get() is s.get());
    }
    {
        const constRange = s.byCodePoint();

        auto fromConstRange = constRange[];
        fromConstRange.popFront();
        assert(fromConstRange.front == ' ');
    }
}

// Can pop multibyte characters
@nogc pure @safe unittest
{
    auto s = String("\U00024B62\U00002260");
    auto range = s.byCodePoint();

    range.popFront();
    assert(!range.empty);

    range.popFront();
    assert(range.empty);

    range = s.byCodePoint();
    range.popFront();
    s[$ - 3] = 0xf0;
    assertThrown!UTFException(&(range.popFront));
}

// Inserts own char range correctly
@nogc nothrow pure @safe unittest
{
    auto s1 = String(`ü`);
    String s2;
    s2.insertBack(s1[]);
    assert(s1 == s2);
}
