/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Functions operating on ASCII characters.
 *
 * ASCII is $(B A)merican $(B S)tandard $(B C)ode for $(B I)nformation
 * $(B I)nterchange.
 *
 * Copyright: Eugene Wissner 2017-2018.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/encoding/ascii.d,
 *                 tanya/encoding/ascii.d)
 */
module tanya.encoding.ascii;

import tanya.meta.trait;

immutable string fullHexDigits = "0123456789ABCDEFabcdef"; /// 0..9A..Fa..f.
immutable string hexDigits = "0123456789ABCDEF"; /// 0..9A..F.
immutable string lowerHexDigits = "0123456789abcdef"; /// 0..9a..f.
immutable string digits = "0123456789"; /// 0..9.
immutable string octalDigits = "01234567"; /// 0..7.

/// A..Za..z.
immutable string letters = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";

immutable string uppercase = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"; /// A..Z.
immutable string lowercase = "abcdefghijklmnopqrstuvwxyz"; /// a..z.

/**
 * Whitespace, Horizontal Tab (HT), Line Feed (LF), Carriage Return (CR),
 * Vertical Tab (VT) or Form Feed (FF).
 */
immutable string whitespace = "\t\n\v\f\r ";

/// Letter case specifier.
enum LetterCase : bool
{
    upper, /// Uppercase.
    lower, /// Lowercase.
}

/**
 * Checks for an uppecase alphabetic character.
 *
 * Params:
 *  C = Some character type.
 *  c = Some character.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM c) is an uppercase alphabetic
 *          character, $(D_KEYWORD false) otherwise.
 */
bool isUpper(C)(C c)
if (isSomeChar!C)
{
    return (c >= 'A') && (c <= 'Z');
}

///
@nogc nothrow pure @safe unittest
{
    assert(isUpper('A'));
    assert(isUpper('Z'));
    assert(isUpper('L'));
    assert(!isUpper('a'));
    assert(!isUpper('!'));
}

/**
 * Checks for a lowercase alphabetic character.
 *
 * Params:
 *  C = Some character type.
 *  c = Some character.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM c) is a lowercase alphabetic
 *          character, $(D_KEYWORD false) otherwise.
 */
bool isLower(C)(C c)
if (isSomeChar!C)
{
    return (c >= 'a') && (c <= 'z');
}

///
@nogc nothrow pure @safe unittest
{
    assert(isLower('a'));
    assert(isLower('z'));
    assert(isLower('l'));
    assert(!isLower('A'));
    assert(!isLower('!'));
}

/**
 * Checks for an alphabetic character (upper- or lowercase).
 *
 * Params:
 *  C = Some character type.
 *  c = Some character.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM c) is an alphabetic character,
 *          $(D_KEYWORD false) otherwise.
 */
bool isAlpha(C)(C c)
if (isSomeChar!C)
{
    return isUpper(c) || isLower(c);
}

///
@nogc nothrow pure @safe unittest
{
    assert(isAlpha('A'));
    assert(isAlpha('Z'));
    assert(isAlpha('L'));
    assert(isAlpha('a'));
    assert(isAlpha('z'));
    assert(isAlpha('l'));
    assert(!isAlpha('!'));
}

/**
 * Checks for a digit.
 *
 * Params:
 *  C = Some character type.
 *  c = Some character.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM c) is a digit,
 *          $(D_KEYWORD false) otherwise.
 */
bool isDigit(C)(C c)
if (isSomeChar!C)
{
    return (c >= '0') && (c <= '9');
}

///
@nogc nothrow pure @safe unittest
{
    assert(isDigit('0'));
    assert(isDigit('1'));
    assert(isDigit('2'));
    assert(isDigit('3'));
    assert(isDigit('4'));
    assert(isDigit('5'));
    assert(isDigit('6'));
    assert(isDigit('7'));
    assert(isDigit('8'));
    assert(isDigit('9'));
    assert(!isDigit('a'));
    assert(!isDigit('!'));
}

/**
 * Checks for an alphabetic character (upper- or lowercase) or a digit.
 *
 * Params:
 *  C = Some character type.
 *  c = Some character.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM c) is an alphabetic character or a
 *          digit, $(D_KEYWORD false) otherwise.
 */
bool isAlphaNum(C)(C c)
if (isSomeChar!C)
{
    return isAlpha(c) || isDigit(c);
}

///
@nogc nothrow pure @safe unittest
{
    assert(isAlphaNum('0'));
    assert(isAlphaNum('1'));
    assert(isAlphaNum('9'));
    assert(isAlphaNum('A'));
    assert(isAlphaNum('Z'));
    assert(isAlphaNum('L'));
    assert(isAlphaNum('a'));
    assert(isAlphaNum('z'));
    assert(isAlphaNum('l'));
    assert(!isAlphaNum('!'));
}

/**
 * Checks for a 7-bit ASCII character.
 *
 * Params:
 *  C = Some character type.
 *  c = Some character.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM c) is an ASCII character,
 *          $(D_KEYWORD false) otherwise.
 */
bool isASCII(C)(C c)
if (isSomeChar!C)
{
    return c < 128;
}

///
@nogc nothrow pure @safe unittest
{
    assert(isASCII('0'));
    assert(isASCII('L'));
    assert(isASCII('l'));
    assert(isASCII('!'));
    assert(!isASCII('©'));
    assert(!isASCII('§'));
    assert(!isASCII(char.init)); // 0xFF
    assert(!isASCII(wchar.init)); // 0xFFFF
    assert(!isASCII(dchar.init)); // 0xFFFF
}

/**
 * Checks for a control character.
 *
 * Control characters are non-printable characters. Their ASCII codes are those
 * between 0x00 (NUL) and 0x1f (US), and 0x7f (DEL).
 *
 * Params:
 *  C = Some character type.
 *  c = Some character.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM c) is a control character,
 *          $(D_KEYWORD false) otherwise.
 *
 * See_Also: $(D_PSYMBOL isPrintable),  $(D_PSYMBOL isGraphical).
 */
bool isControl(C)(C c)
if (isSomeChar!C)
{
    return (c <= 0x1f) || (c == 0x7f);
}

///
@nogc nothrow pure @safe unittest
{
    assert(isControl('\t'));
    assert(isControl('\0'));
    assert(isControl('\u007f'));
    assert(!isControl(' '));
    assert(!isControl('a'));
    assert(!isControl(char.init)); // 0xFF
    assert(!isControl(wchar.init)); // 0xFFFF
}

/**
 * Checks for a whitespace character.
 *
 * Whitespace characters are:
 *
 * $(UL
 *  $(LI Whitespace)
 *  $(LI Horizontal Tab (HT))
 *  $(LI Line Feed (LF))
 *  $(LI Carriage Return (CR))
 *  $(LI Vertical Tab (VT))
 *  $(LI Form Feed (FF))
 * )
 *
 * Params:
 *  C = Some character type.
 *  c = Some character.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM c) is a whitespace character,
 *          $(D_KEYWORD false) otherwise.
 *
 * See_Also: $(D_PSYMBOL whitespace).
 */
bool isWhite(C)(C c)
if (isSomeChar!C)
{
    return ((c >= 0x09) && (c <= 0x0d)) || (c == 0x20);
}

///
@nogc nothrow pure @safe unittest
{
    assert(isWhite('\t'));
    assert(isWhite('\n'));
    assert(isWhite('\v'));
    assert(isWhite('\f'));
    assert(isWhite('\r'));
    assert(isWhite(' '));
}

/**
 * Checks for a graphical character.
 *
 * Graphical characters are printable characters but whitespace characters.
 *
 * Params:
 *  C = Some character type.
 *  c = Some character.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM c) is a control character,
 *          $(D_KEYWORD false) otherwise.
 *
 * See_Also: $(D_PSYMBOL isControl), $(D_PSYMBOL isWhite).
 */
bool isGraphical(C)(C c)
if (isSomeChar!C)
{
    return (c > 0x20) && (c < 0x7f);
}

///
@nogc nothrow pure @safe unittest
{
    assert(isGraphical('a'));
    assert(isGraphical('0'));
    assert(!isGraphical('\u007f'));
    assert(!isGraphical('§'));
    assert(!isGraphical('\n'));
    assert(!isGraphical(' '));
}

/**
 * Checks for a printable character.
 *
 * This is the opposite of a control character.
 *
 * Params:
 *  C = Some character type.
 *  c = Some character.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM c) is a control character,
 *          $(D_KEYWORD false) otherwise.
 *
 * See_Also: $(D_PSYMBOL isControl).
 */
bool isPrintable(C)(C c)
if (isSomeChar!C)
{
    return (c >= 0x20) && (c < 0x7f);
}

///
@nogc nothrow pure @safe unittest
{
    assert(isPrintable('a'));
    assert(isPrintable('0'));
    assert(!isPrintable('\u007f'));
    assert(!isPrintable('§'));
    assert(!isPrintable('\n'));
    assert(isPrintable(' '));
}

/**
 * Checks for a hexadecimal digit.
 *
 * Params:
 *  C = Some character type.
 *  c = Some character.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM c) is a hexadecimal digit,
 *          $(D_KEYWORD false) otherwise.
 */
bool isHexDigit(C)(C c)
if (isSomeChar!C)
{
    return ((c >= '0') && (c <= '9'))
        || ((c >= 'a') && (c <= 'f'))
        || ((c >= 'A') && (c <= 'F'));
}

///
@nogc nothrow pure @safe unittest
{
    assert(isHexDigit('0'));
    assert(isHexDigit('1'));
    assert(isHexDigit('8'));
    assert(isHexDigit('9'));
    assert(isHexDigit('A'));
    assert(isHexDigit('F'));
    assert(!isHexDigit('G'));
    assert(isHexDigit('a'));
    assert(isHexDigit('f'));
    assert(!isHexDigit('g'));
}

/**
 * Checks for an octal character.
 *
 * Params:
 *  C = Some character type.
 *  c = Some character.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM c) is an octal character,
 *          $(D_KEYWORD false) otherwise.
 */
bool isOctalDigit(C)(C c)
if (isSomeChar!C)
{
    return (c >= '0') && (c <= '7');
}

///
@nogc nothrow pure @safe unittest
{
    assert(isOctalDigit('0'));
    assert(isOctalDigit('1'));
    assert(isOctalDigit('2'));
    assert(isOctalDigit('3'));
    assert(isOctalDigit('4'));
    assert(isOctalDigit('5'));
    assert(isOctalDigit('6'));
    assert(isOctalDigit('7'));
    assert(!isOctalDigit('8'));
}

/**
 * Checks for a octal character.
 *
 * Params:
 *  C = Some character type.
 *  c = Some character.
 *
 * Returns: $(D_KEYWORD true) if $(D_PARAM c) is a octal character,
 *          $(D_KEYWORD false) otherwise.
 */
bool isPunctuation(C)(C c)
if (isSomeChar!C)
{
    return ((c >= 0x21) && (c <= 0x2f))
        || ((c >= 0x3a) && (c <= 0x40))
        || ((c >= 0x5b) && (c <= 0x60))
        || ((c >= 0x7b) && (c <= 0x7e));
}

///
@nogc nothrow pure @safe unittest
{
    assert(isPunctuation('!'));
    assert(isPunctuation(':'));
    assert(isPunctuation('\\'));
    assert(isPunctuation('|'));
    assert(!isPunctuation('0'));
    assert(!isPunctuation(' '));
}

/**
 * Converts $(D_PARAM c) to uppercase.
 *
 * If $(D_PARAM c) is not a lowercase character, $(D_PARAM c) is returned
 * unchanged.
 *
 * Params:
 *  C = Some character type.
 *  c = Some character.
 *
 * Returns: The lowercase of $(D_PARAM c) if available, just $(D_PARAM c)
 *          otherwise.
 */
C toUpper(C)(C c)
if (isSomeChar!C)
{
    return isLower(c) ? (cast(C) (c - 32)) : c;
}

///
@nogc nothrow pure @safe unittest
{
    assert(toUpper('a') == 'A');
    assert(toUpper('A') == 'A');
    assert(toUpper('!') == '!');
}

/**
 * Converts $(D_PARAM c) to lowercase.
 *
 * If $(D_PARAM c) is not an uppercase character, $(D_PARAM c) is returned
 * unchanged.
 *
 * Params:
 *  C = Some character type.
 *  c = Some character.
 *
 * Returns: The uppercase of $(D_PARAM c) if available, just $(D_PARAM c)
 *          otherwise.
 */
C toLower(C)(C c)
if (isSomeChar!C)
{
    return isUpper(c) ? (cast(C) (c + 32)) : c;
}

///
@nogc nothrow pure @safe unittest
{
    assert(toLower('A') == 'a');
    assert(toLower('a') == 'a');
    assert(toLower('!') == '!');
}
