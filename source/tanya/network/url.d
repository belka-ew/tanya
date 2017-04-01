/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * URL parser.
 *
 * Copyright: Eugene Wissner 2016-2017.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 */
module tanya.network.url;

import std.ascii : isAlphaNum, isDigit;
import std.traits : isSomeString;
import std.uni : isAlpha, isNumber;
import std.uri;
import tanya.memory;

version (unittest) private
{
    import std.typecons;
    static Tuple!(string, string[string], ushort)[] URLTests;
}

static this()
{
    version (unittest)
    {
        URLTests = [
            tuple(`127.0.0.1`, [
                      "path": "127.0.0.1",
                  ], ushort(0)),

            tuple(`http://127.0.0.1`, [
                      "scheme": "http",
                      "host": "127.0.0.1",
                  ], ushort(0)),

            tuple(`http://127.0.0.1/`, [
                      "scheme": "http",
                      "host": "127.0.0.1",
                      "path": "/",
                  ], ushort(0)),

            tuple(`127.0.0.1/`, [
                      "path": "127.0.0.1/",
                  ], ushort(0)),

            tuple(`127.0.0.1:60000/`, [
                      "host": "127.0.0.1",
                      "path": "/",
                  ], ushort(60000)),

            tuple(`example.org`, [
                      "path": "example.org",
                  ], ushort(0)),

            tuple(`example.org/`, [
                      "path": "example.org/",
                  ], ushort(0)),

            tuple(`http://example.org`, [
                      "scheme": "http",
                      "host": "example.org",
                  ], ushort(0)),

            tuple(`http://example.org/`, [
                      "scheme": "http",
                      "host": "example.org",
                      "path": "/",
                  ], ushort(0)),

            tuple(`www.example.org`, [
                      "path": "www.example.org",
                  ], ushort(0)),

            tuple(`www.example.org/`, [
                      "path": "www.example.org/",
                  ], ushort(0)),

            tuple(`http://www.example.org`, [
                      "scheme": "http",
                      "host": "www.example.org",
                  ], ushort(0)),

            tuple(`http://www.example.org/`, [
                      "scheme": "http",
                      "host": "www.example.org",
                      "path": "/",
                  ], ushort(0)),

            tuple(`www.example.org:2`, [
                      "host": "www.example.org",
                  ], ushort(2)),

            tuple(`http://www.example.org:80`, [
                      "scheme": "http",
                      "host": "www.example.org",
                  ], ushort(80)),

            tuple(`http://www.example.org:80/`, [
                      "scheme": "http",
                      "host": "www.example.org",
                      "path": "/",
                  ], ushort(80)),

            tuple(`http://www.example.org/index.html`, [
                      "scheme": "http",
                      "host": "www.example.org",
                      "path": "/index.html",
                  ], ushort(0)),

            tuple(`www.example.org/?`, [
                      "path": "www.example.org/",
                    "query": "",
                  ], ushort(0)),

            tuple(`www.example.org:80/?`, [
                      "host": "www.example.org",
                      "path": "/",
                    "query": "",
                  ], ushort(80)),

            tuple(`http://www.example.org/?`, [
                      "scheme": "http",
                      "host": "www.example.org",
                      "path": "/",
                    "query": "",
                  ], ushort(0)),

            tuple(`http://www.example.org:80/?`, [
                      "scheme": "http",
                      "host": "www.example.org",
                      "path": "/",
                    "query": "",
                  ], ushort(80)),

            tuple(`http://www.example.org:80/index.html`, [
                      "scheme": "http",
                      "host": "www.example.org",
                      "path": "/index.html",
                  ], ushort(80)),

            tuple(`http://www.example.org:80/foo/bar/index.html`, [
                      "scheme": "http",
                      "host": "www.example.org",
                      "path": "/foo/bar/index.html",
                  ], ushort(80)),

            tuple(`http://www.example.org:80/this/is/a/very/deep/directory/structure/and/file.png`, [
                      "scheme": "http",
                      "host": "www.example.org",
                      "path": "/this/is/a/very/deep/directory/structure/and/file.png",
                  ], ushort(80)),

            tuple(`http://www.example.org:80/deep/directory/structure/and/file.png?lots=1&of=2&parameters=3&too=4`, [
                      "scheme": "http",
                      "host": "www.example.org",
                      "path": "/deep/directory/structure/and/file.png",
                      "query": "lots=1&of=2&parameters=3&too=4",
                  ], ushort(80)),

            tuple(`http://www.example.org:80/this/is/a/very/deep/directory/structure/and/`, [
                      "scheme": "http",
                      "host": "www.example.org",
                      "path": "/this/is/a/very/deep/directory/structure/and/",
                  ], ushort(80)),

            tuple(`http://www.example.org:80/this/is/a/very/deep/directory/structure/and/file.php`, [
                      "scheme": "http",
                      "host": "www.example.org",
                      "path": "/this/is/a/very/deep/directory/structure/and/file.php",
                  ], ushort(80)),

            tuple(`http://www.example.org:80/this/../a/../deep/directory`, [
                      "scheme": "http",
                      "host": "www.example.org",
                      "path": "/this/../a/../deep/directory",
                  ], ushort(80)),

            tuple(`http://www.example.org:80/this/../a/../deep/directory/`, [
                      "scheme": "http",
                      "host": "www.example.org",
                      "path": "/this/../a/../deep/directory/",
                  ], ushort(80)),

            tuple(`http://www.example.org:80/this/is/a/very/deep/directory/../image.png`, [
                      "scheme": "http",
                      "host": "www.example.org",
                      "path": "/this/is/a/very/deep/directory/../image.png",
                  ], ushort(80)),

            tuple(`http://www.example.org:80/index.html`, [
                      "scheme": "http",
                      "host": "www.example.org",
                      "path": "/index.html",
                  ], ushort(80)),

            tuple(`http://www.example.org:80/index.html?`, [
                      "scheme": "http",
                      "host": "www.example.org",
                      "path": "/index.html",
                    "query": "",
                  ], ushort(80)),

            tuple(`http://www.example.org:80/#foo`, [
                      "scheme": "http",
                      "host": "www.example.org",
                      "path": "/",
                      "fragment": "foo",
                  ], ushort(80)),

            tuple(`http://www.example.org:80/?#`, [
                      "scheme": "http",
                      "host": "www.example.org",
                      "path": "/",
                    "query": "",
                    "fragment": "",
                  ], ushort(80)),

            tuple(`http://www.example.org:80/?test=1`, [
                      "scheme": "http",
                      "host": "www.example.org",
                      "path": "/",
                      "query": "test=1",
                  ], ushort(80)),

            tuple(`http://www.example.org/?test=1&`, [
                      "scheme": "http",
                      "host": "www.example.org",
                      "path": "/",
                      "query": "test=1&",
                  ], ushort(0)),

            tuple(`http://www.example.org:80/?&`, [
                      "scheme": "http",
                      "host": "www.example.org",
                      "path": "/",
                      "query": "&",
                  ], ushort(80)),

            tuple(`http://www.example.org:80/index.html?test=1&`, [
                      "scheme": "http",
                      "host": "www.example.org",
                      "path": "/index.html",
                      "query": "test=1&",
                  ], ushort(80)),

            tuple(`http://www.example.org/index.html?&`, [
                      "scheme": "http",
                      "host": "www.example.org",
                      "path": "/index.html",
                      "query": "&",
                  ], ushort(0)),

            tuple(`http://www.example.org:80/index.html?foo&`, [
                      "scheme": "http",
                      "host": "www.example.org",
                      "path": "/index.html",
                      "query": "foo&",
                  ], ushort(80)),

            tuple(`http://www.example.org/index.html?&foo`, [
                      "scheme": "http",
                      "host": "www.example.org",
                      "path": "/index.html",
                      "query": "&foo",
                  ], ushort(0)),

            tuple(`http://www.example.org:80/index.html?test=1&test2=char`, [
                      "scheme": "http",
                      "host": "www.example.org",
                      "path": "/index.html",
                      "query": "test=1&test2=char",
                  ], ushort(80)),

            tuple(`www.example.org:80/index.html?test=1&test2=char#some_ref123`, [
                      "host": "www.example.org",
                      "path": "/index.html",
                      "query": "test=1&test2=char",
                      "fragment": "some_ref123",
                  ], ushort(80)),

            tuple(`http://secret@www.example.org:80/index.html?test=1&test2=char#some_ref123`, [
                      "scheme": "http",
                      "host": "www.example.org",
                      "user": "secret",
                      "path": "/index.html",
                      "query": "test=1&test2=char",
                      "fragment": "some_ref123",
                  ], ushort(80)),

            tuple(`http://secret:@www.example.org/index.html?test=1&test2=char#some_ref123`, [
                      "scheme": "http",
                      "host": "www.example.org",
                      "user": "secret",
                      "pass": "",
                      "path": "/index.html",
                      "query": "test=1&test2=char",
                      "fragment": "some_ref123",
                  ], ushort(0)),

            tuple(`http://:hideout@www.example.org:80/index.html?test=1&test2=char#some_ref123`, [
                      "scheme": "http",
                      "host": "www.example.org",
                      "user": "",
                      "pass": "hideout",
                      "path": "/index.html",
                      "query": "test=1&test2=char",
                      "fragment": "some_ref123",
                  ], ushort(80)),

            tuple(`http://secret:hideout@www.example.org/index.html?test=1&test2=char#some_ref123`, [
                      "scheme": "http",
                      "host": "www.example.org",
                      "user": "secret",
                      "pass": "hideout",
                      "path": "/index.html",
                      "query": "test=1&test2=char",
                      "fragment": "some_ref123",
                  ], ushort(0)),

            tuple(`http://secret:hid:out@www.example.org:80/index.html?test=1&test2=int#some_ref123`, [
                      "scheme": "http",
                      "host": "www.example.org",
                      "user": "secret",
                      "pass": "hid:out",
                      "path": "/index.html",
                      "query": "test=1&test2=int",
                      "fragment": "some_ref123",
                  ], ushort(80)),

            tuple(`nntp://news.example.org`, [
                      "scheme": "nntp",
                      "host": "news.example.org",
                  ], ushort(0)),

            tuple(`ftp://ftp.gnu.org/gnu/glic/glibc.tar.gz`, [
                      "scheme": "ftp",
                      "host": "ftp.gnu.org",
                      "path": "/gnu/glic/glibc.tar.gz",
                  ], ushort(0)),

            tuple(`zlib:http://foo@bar`, [
                      "scheme": "zlib",
                      "path": "http://foo@bar",
                  ], ushort(0)),

            tuple(`zlib:filename.txt`, [
                      "scheme": "zlib",
                      "path": "filename.txt",
                  ], ushort(0)),

            tuple(`zlib:/path/to/my/file/file.txt`, [
                      "scheme": "zlib",
                      "path": "/path/to/my/file/file.txt",
                  ], ushort(0)),

            tuple(`foo://foo@bar`, [
                      "scheme": "foo",
                      "host": "bar",
                      "user": "foo",
                  ], ushort(0)),

            tuple(`mailto:me@mydomain.com`, [
                      "scheme": "mailto",
                      "path": "me@mydomain.com",
                  ], ushort(0)),

            tuple(`/foo.php?a=b&c=d`, [
                      "path": "/foo.php",
                      "query": "a=b&c=d",
                  ], ushort(0)),

            tuple(`foo.php?a=b&c=d`, [
                      "path": "foo.php",
                      "query": "a=b&c=d",
                  ], ushort(0)),

            tuple(`http://user:passwd@www.example.com:8080?bar=1&boom=0`, [
                      "scheme": "http",
                      "host": "www.example.com",
                      "user": "user",
                      "pass": "passwd",
                      "query": "bar=1&boom=0",
                  ], ushort(8080)),

            tuple(`file:///path/to/file`, [
                      "scheme": "file",
                      "path": "/path/to/file",
                  ], ushort(0)),

            tuple(`file://path/to/file`, [
                      "scheme": "file",
                      "host": "path",
                      "path": "/to/file",
                  ], ushort(0)),

            tuple(`file:/path/to/file`, [
                      "scheme": "file",
                      "path": "/path/to/file",
                  ], ushort(0)),

            tuple(`http://1.2.3.4:/abc.asp?a=1&b=2`, [
                      "scheme": "http",
                      "host": "1.2.3.4",
                      "path": "/abc.asp",
                      "query": "a=1&b=2",
                  ], ushort(0)),

            tuple(`http://foo.com#bar`, [
                      "scheme": "http",
                      "host": "foo.com",
                      "fragment": "bar",
                  ], ushort(0)),

            tuple(`scheme:`, [
                      "scheme": "scheme",
                  ], ushort(0)),

            tuple(`foo+bar://baz@bang/bla`, [
                      "scheme": "foo+bar",
                      "host": "bang",
                      "user": "baz",
                      "path": "/bla",
                  ], ushort(0)),

            tuple(`gg:9130731`, [
                      "scheme": "gg",
                      "path": "9130731",
                  ], ushort(0)),

            tuple(`http://10.10.10.10/:80`, [
                      "scheme": "http",
                      "host": "10.10.10.10",
                      "path": "/:80",
                  ], ushort(0)),

            tuple(`http://x:?`, [
                      "scheme": "http",
                      "host": "x",
                    "query": "",
                  ], ushort(0)),

            tuple(`x:blah.com`, [
                      "scheme": "x",
                      "path": "blah.com",
                  ], ushort(0)),

            tuple(`x:/blah.com`, [
                      "scheme": "x",
                      "path": "/blah.com",
                  ], ushort(0)),

            tuple(`http://::?`, [
                      "scheme": "http",
                      "host": ":",
                    "query": "",
                  ], ushort(0)),

            tuple(`http://::#`, [
                      "scheme": "http",
                      "host": ":",
                    "fragment": "",
                  ], ushort(0)),

            tuple(`http://?:/`, [
                      "scheme": "http",
                      "host": "?",
                      "path": "/",
                  ], ushort(0)),

            tuple(`http://@?:/`, [
                      "scheme": "http",
                      "host": "?",
                      "user": "",
                      "path": "/",
                  ], ushort(0)),

            tuple(`file:///:`, [
                      "scheme": "file",
                      "path": "/:",
                  ], ushort(0)),

            tuple(`file:///a:/`, [
                      "scheme": "file",
                      "path": "a:/",
                  ], ushort(0)),

            tuple(`file:///ab:/`, [
                      "scheme": "file",
                      "path": "/ab:/",
                  ], ushort(0)),

            tuple(`file:///a:/`, [
                      "scheme": "file",
                      "path": "a:/",
                  ], ushort(0)),

            tuple(`file:///@:/`, [
                      "scheme": "file",
                      "path": "@:/",
                  ], ushort(0)),

            tuple(`file:///:80/`, [
                      "scheme": "file",
                      "path": "/:80/",
                  ], ushort(0)),

            tuple(`[]`, [
                      "path": "[]",
                  ], ushort(0)),

            tuple(`http://[x:80]/`, [
                      "scheme": "http",
                      "host": "[x:80]",
                      "path": "/",
                  ], ushort(0)),

            tuple(``, [
                      "path": "",
                  ], ushort(0)),

            tuple(`/`, [
                      "path": "/",
                  ], ushort(0)),

            tuple(`/rest/Users?filter={"id":"789"}`, [
                      "path": "/rest/Users",
                      "query": `filter={"id":"789"}`,
                  ], ushort(0)),

            tuple(`//example.org`, [
                      "host": "example.org",
                  ], ushort(0)),

            tuple(`/standard/?fq=B:20001`, [
                      "path": "/standard/",
                      "query": "fq=B:20001",
                  ], ushort(0)),

            tuple(`/standard/?fq=B:200013`, [
                      "path": "/standard/",
                      "query": "fq=B:200013",
                  ], ushort(0)),

            tuple(`/standard/?fq=home:012345`, [
                      "path": "/standard/",
                      "query": "fq=home:012345",
                  ], ushort(0)),

            tuple(`/standard/?fq=home:01234`, [
                      "path": "/standard/",
                      "query": "fq=home:01234",
                  ], ushort(0)),

            tuple(`http://user:pass@host`, [
                    "scheme": "http",
                    "host": "host",
                      "user": "user",
                      "pass": "pass",
                  ], ushort(0)),

            tuple(`//user:pass@host`, [
                    "host": "host",
                      "user": "user",
                      "pass": "pass",
                  ], ushort(0)),

            tuple(`//user@host`, [
                    "host": "host",
                      "user": "user",
                  ], ushort(0)),

            tuple(`//example.org:99/hey?a=b#c=d`, [
                    "host": "example.org",
                      "path": "/hey",
                      "query": "a=b",
                      "fragment": "c=d",
                  ], ushort(99)),

            tuple(`//example.org/hey?a=b#c=d`, [
                    "host": "example.org",
                      "path": "/hey",
                      "query": "a=b",
                      "fragment": "c=d",
                  ], ushort(0)),

            tuple(`http://example.org/some/path.cgi?t=1#fragment?data`, [
                    "scheme": "http",
                    "host": "example.org",
                      "path": "/some/path.cgi",
                      "query": "t=1",
                      "fragment": "fragment?data",
                  ], ushort(0)),

            tuple(`http://example.org/some/path.cgi#fragment?data`, [
                    "scheme": "http",
                    "host": "example.org",
                      "path": "/some/path.cgi",
                      "fragment": "fragment?data",
                  ], ushort(0)),

            tuple(`x://::abc/?`, string[string].init, ushort(0)),
            tuple(`http:///blah.com`, string[string].init, ushort(0)),
            tuple(`http://:80`, string[string].init, ushort(0)),
            tuple(`http://user@:80`, string[string].init, ushort(0)),
            tuple(`http://user:pass@:80`, string[string].init, ushort(0)),
            tuple(`http://:`, string[string].init, ushort(0)),
            tuple(`http://@/`, string[string].init, ushort(0)),
            tuple(`http://@:/`, string[string].init, ushort(0)),
            tuple(`http://:/`, string[string].init, ushort(0)),
            tuple(`http://?`, string[string].init, ushort(0)),
            tuple(`http://#`, string[string].init, ushort(0)),
            tuple(`http://:?`, string[string].init, ushort(0)),
            tuple(`http://blah.com:123456`, string[string].init, ushort(0)),
            tuple(`http://blah.com:70000`, string[string].init, ushort(0)),
            tuple(`http://blah.com:abcdef`, string[string].init, ushort(0)),
            tuple(`http://secret@hideout@www.example.org:80/index.html?test=1&test2=char#some_ref123`,
                  string[string].init,
                  ushort(0)),
            tuple(`http://user:@pass@host/path?argument?value#etc`, string[string].init, ushort(0)),
            tuple(`http://foo.com\@bar.com`, string[string].init, ushort(0)),
            tuple(`http://email@address.com:pass@example.org`, string[string].init, ushort(0)),
            tuple(`:`, string[string].init, ushort(0)),
        ];
    }
}

/**
 * A Unique Resource Locator.
 */
struct URL
{
    /** The URL scheme. */
    const(char)[] scheme;

    /** The username. */
    const(char)[] user;

    /** The password. */
    const(char)[] pass;

    /** The hostname. */
    const(char)[] host;

    /** The port number. */
    ushort port;

    /** The path. */
    const(char)[] path;

    /** The query string. */
    const(char)[] query;

    /** The anchor. */
    const(char)[] fragment;

    /**
     * Attempts to parse an URL from a string.
     * Output string data (scheme, user, etc.) are just slices of input string (e.g., no memory allocation and copying).
     *
     * Params:
     *  source = The string containing the URL.
     *
     * Throws: $(D_PSYMBOL URIException) if the URL is malformed.
     */
    this(in char[] source)
    {
        auto value = source;
        ptrdiff_t pos = -1, endPos = value.length, start;

        foreach (i, ref c; source)
        {
            if (pos == -1 && c == ':')
            {
                pos = i;
            }
            if (endPos == value.length && (c == '?' || c == '#'))
            {
                endPos = i;
            }
        }

        // Check if the colon is a part of the scheme or the port and parse
        // the appropriate part
        if (value.length > 1 && value[0] == '/' && value[1] == '/')
        {
            // Relative scheme
            start = 2;
        }
        else if (pos > 0)
        {
            // Validate scheme
            // [ toLower(alpha) | digit | "+" | "-" | "." ]
            foreach (ref c; value[0..pos])
            {
                if (!c.isAlphaNum && c != '+' && c != '-' && c != '.')
                {
                    if (endPos > pos)
                    {
                        if (!parsePort(value[pos..$]))
                        {
                            throw defaultAllocator.make!URIException("Failed to parse port");
                        }
                    }
                    goto ParsePath;
                }
            }

            if (value.length == pos + 1) // only scheme is available
            {
                scheme = value[0 .. $ - 1];
                return;
            }
            else if (value.length > pos + 1 && value[pos + 1] == '/')
            {
                scheme = value[0..pos];

                if (value.length > pos + 2 && value[pos + 2] == '/')
                {
                    start = pos + 3;
                    if (scheme == "file" && value.length > start && value[start] == '/')
                    {
                        // Windows drive letters
                        if (value.length - start > 2 && value[start + 2] == ':')
                        {
                            ++start;
                        }
                        goto ParsePath;
                    }
                }
                else
                {
                    start = pos + 1;
                    goto ParsePath;
                }
            }
            else // certain schemas like mailto: and zlib: may not have any / after them
            {
                
                if (!parsePort(value[pos..$]))
                {
                    scheme = value[0..pos];
                    start = pos + 1;
                    goto ParsePath;
                }
            }
        }
        else if (pos == 0 && parsePort(value[pos..$]))
        {
            // An URL shouldn't begin with a port number
            throw defaultAllocator.make!URIException("URL begins with port");
        }
        else
        {
            goto ParsePath;
        }

        // Parse host
        pos = -1;
        for (ptrdiff_t i = start; i < value.length; ++i)
        {
            if (value[i] == '@')
            {
                pos = i;
            }
            else if (value[i] == '/')
            {
                endPos = i;
                break;
            }
        }

        // Check for login and password
        if (pos != -1)
        {
            // *( unreserved / pct-encoded / sub-delims / ":" )
            foreach (i, c; value[start..pos])
            {
                if (c == ':')
                {
                    if (user is null)
                    {
                        user = value[start .. start + i];
                        pass = value[start + i + 1 .. pos]; 
                    }
                }
                else if (!c.isAlpha &&
                         !c.isNumber &&
                         c != '!' &&
                         c != ';' &&
                         c != '=' &&
                         c != '_' &&
                         c != '~' &&
                         !(c >= '$' && c <= '.'))
                {
                    if (scheme !is null)
                    {
                        scheme = null;
                    }
                    if (user !is null)
                    {
                        user = null;
                    }
                    if (pass !is null)
                    {
                        pass = null;
                    }
                    throw make!URIException(defaultAllocator,
                                            "Restricted characters in user information");
                }
            }
            if (user is null)
            {
                user = value[start..pos];
            }

            start = ++pos;
        }

        pos = endPos;
        if (endPos <= 1 || value[start] != '[' || value[endPos - 1] != ']')
        {
            // Short circuit portscan
            // IPv6 embedded address
            for (ptrdiff_t i = endPos - 1; i >= start; --i)
            {
                if (value[i] == ':')
                {
                    pos = i;
                    if  (port == 0 && !parsePort(value[i..endPos]))
                    {
                        if (scheme !is null)
                        {
                            scheme = null;
                        }
                        if (user !is null)
                        {
                            user = null;
                        }
                        if (pass !is null)
                        {
                            pass = null;
                        }
                        throw defaultAllocator.make!URIException("Invalid port");
                    }
                    break;
                }
            }
        }

        // Check if we have a valid host, if we don't reject the string as url
        if (pos <= start)
        {
            if (scheme !is null)
            {
                scheme = null;
            }
            if (user !is null)
            {
                user = null;
            }
            if (pass !is null)
            {
                pass = null;
            }
            throw defaultAllocator.make!URIException("Invalid host");
        }

        host = value[start..pos];

        if (endPos == value.length)
        {
            return;
        }

        start = endPos;

    ParsePath:
        endPos = value.length;
        pos = -1;
        foreach (i, ref c; value[start..$])
        {
            if (c == '?' && pos == -1)
            {
                pos = start + i;
            }
            else if (c == '#')
            {
                endPos = start + i;
                break;
            }
        }
        if (pos == -1)
        {
            pos = endPos;
        }

        if (pos > start)
        {
            path = value[start..pos];
        }
        if (endPos >= ++pos)
        {
            query = value[pos..endPos];
        }
        if (++endPos <= value.length)
        {
            fragment = value[endPos..$];
        }
    }

    ~this()
    {
        if (scheme !is null)
        {
            scheme = null;
        }
        if (user !is null)
        {
            user = null;
        }
        if (pass !is null)
        {
            pass = null;
        }
        if (host !is null)
        {
            host = null;
        }
        if (path !is null)
        {
            path = null;
        }
        if (query !is null)
        {
            query = null;
        }
        if (fragment !is null)
        {
            fragment = null;
        }
    }

    /**
     * Attempts to parse and set the port.
     *
     * Params:
     *  port = String beginning with a colon followed by the port number and
     *         an optional path (query string and/or fragment), like:
     *         `:12345/some_path` or `:12345`.
     *
     * Returns: Whether the port could be found.
     */
    private bool parsePort(in char[] port) pure nothrow @safe @nogc
    {
        ptrdiff_t i = 1;
        float lPort = 0;

        for (; i < port.length && port[i].isDigit() && i <= 6; ++i)
        {
            lPort += (port[i] - '0') / cast(float)(10 ^^ (i - 1));
        }
        if (i == 1 && (i == port.length || port[i] == '/'))
        {
            return true;
        }
        else if (i == port.length || port[i] == '/')
        {
            lPort *= 10 ^^ (i - 2);
            if (lPort > ushort.max)
            {
                return false;
            }
            this.port = cast(ushort)lPort;
            return true;
        }
        return false;
    }
}

///
unittest
{
    auto u = URL("example.org");
    assert(u.path == "example.org"); 

    u = URL("relative/path");
    assert(u.path == "relative/path"); 

    // Host and scheme
    u = URL("https://example.org");
    assert(u.scheme == "https");
    assert(u.host == "example.org");
    assert(u.path is null);
    assert(u.port == 0);
    assert(u.fragment is null);

    // With user and port and path
    u = URL("https://hilary:putnam@example.org:443/foo/bar");
    assert(u.scheme == "https");
    assert(u.host == "example.org");
    assert(u.path == "/foo/bar");
    assert(u.port == 443);
    assert(u.user == "hilary");
    assert(u.pass == "putnam");
    assert(u.fragment is null);

    // With query string
    u = URL("https://example.org/?login=true");
    assert(u.scheme == "https");
    assert(u.host == "example.org");
    assert(u.path == "/");
    assert(u.query == "login=true");
    assert(u.fragment is null);

    // With query string and fragment
    u = URL("https://example.org/?login=false#label");
    assert(u.scheme == "https");
    assert(u.host == "example.org");
    assert(u.path == "/");
    assert(u.query == "login=false");
    assert(u.fragment == "label");

    u = URL("redis://root:password@localhost:2201/path?query=value#fragment");
    assert(u.scheme == "redis");
    assert(u.user == "root");
    assert(u.pass == "password");
    assert(u.host == "localhost");
    assert(u.port == 2201);
    assert(u.path == "/path");
    assert(u.query == "query=value");
    assert(u.fragment == "fragment");
}

private unittest
{
    foreach(t; URLTests)
    {
        if (t[1].length == 0 && t[2] == 0)
        {
            try
            {
                URL(t[0]);
                assert(0);
            }
            catch (URIException e)
            {
                assert(1);
            }
        }
        else
        {
            auto u = URL(t[0]);
            assert("scheme" in t[1] ? u.scheme == t[1]["scheme"] : u.scheme is null,
                   t[0]);
            assert("user" in t[1] ? u.user == t[1]["user"] : u.user is null, t[0]);
            assert("pass" in t[1] ? u.pass == t[1]["pass"] : u.pass is null, t[0]);
            assert("host" in t[1] ? u.host == t[1]["host"] : u.host is null, t[0]);
            assert(u.port == t[2], t[0]);
            assert("path" in t[1] ? u.path == t[1]["path"] : u.path is null, t[0]);
            assert("query" in t[1] ? u.query == t[1]["query"] : u.query is null, t[0]);
            if ("fragment" in t[1])
            {
                assert(u.fragment == t[1]["fragment"], t[0]);
            }
            else
            {
                assert(u.fragment is null, t[0]);
            }
        }
    }
}

/**
 * Contains possible URL components that can be returned from
 * $(D_PSYMBOL parseURL).
 */
enum Component : string
{
    scheme = "scheme",
    host = "host",
    port = "port",
    user = "user",
    pass = "pass",
    path = "path",
    query = "query",
    fragment = "fragment",
}

/**
 * Attempts to parse an URL from a string.
 *
 * Params:
 *  T      = $(D_SYMBOL Component) member or $(D_KEYWORD null) for a
 *           struct with all components.
 *  source = The string containing the URL.
 *
 * Returns: Requested URL components.
 */
URL parseURL(typeof(null) T)(in char[] source)
{
    return URL(source);
}

/// Ditto.
const(char)[] parseURL(immutable(char)[] T)(in char[] source)
    if (T == "scheme"
     || T == "host"
     || T == "user"
     || T == "pass"
     || T == "path"
     || T == "query"
     || T == "fragment")
{
    auto ret = URL(source);
    return mixin("ret." ~ T);
}

/// Ditto.
ushort parseURL(immutable(char)[] T)(in char[] source)
    if (T == "port")
{
    auto ret = URL(source);
    return ret.port;
}

unittest
{
    assert(parseURL!(Component.port)("http://example.org:5326") == 5326);
}

private unittest
{
    foreach(t; URLTests)
    {
        if (t[1].length == 0 && t[2] == 0)
        {
            try
            {
                parseURL!(Component.port)(t[0]);
                parseURL!(Component.user)(t[0]);
                parseURL!(Component.pass)(t[0]);
                parseURL!(Component.host)(t[0]);
                parseURL!(Component.path)(t[0]);
                parseURL!(Component.query)(t[0]);
                parseURL!(Component.fragment)(t[0]);
                assert(0);
            }
            catch (URIException e)
            {
                assert(1);
            }
        }
        else
        {
            ushort port = parseURL!(Component.port)(t[0]);
            auto component = parseURL!(Component.scheme)(t[0]);
            assert("scheme" in t[1] ? component == t[1]["scheme"] : component is null,
                   t[0]);
            component = parseURL!(Component.user)(t[0]);
            assert("user" in t[1] ? component == t[1]["user"] : component is null,
                   t[0]);
            component = parseURL!(Component.pass)(t[0]);
            assert("pass" in t[1] ? component == t[1]["pass"] : component is null,
                   t[0]);
            component = parseURL!(Component.host)(t[0]);
            assert("host" in t[1] ? component == t[1]["host"] : component is null,
                   t[0]);
            assert(port == t[2], t[0]);
            component = parseURL!(Component.path)(t[0]);
            assert("path" in t[1] ? component == t[1]["path"] : component is null,
                   t[0]);
            component = parseURL!(Component.query)(t[0]);
            assert("query" in t[1] ? component == t[1]["query"] : component is null,
                   t[0]);
            component = parseURL!(Component.fragment)(t[0]);
            if ("fragment" in t[1])
            {
                assert(component == t[1]["fragment"], t[0]);
            }
            else
            {
                assert(component is null, t[0]);
            }
        }
    }
}
