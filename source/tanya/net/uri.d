/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * URL parser.
 *
 * Copyright: Eugene Wissner 2017-2020.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/net/uri.d,
 *                 tanya/net/uri.d)
 */
module tanya.net.uri;

import tanya.conv;
import tanya.encoding.ascii;
import tanya.memory.allocator;

/**
 * Thrown if an invalid URI was specified.
 */
final class URIException : Exception
{
    /**
     * Params:
     *  msg  = The message for the exception.
     *  file = The file where the exception occurred.
     *  line = The line number where the exception occurred.
     *  next = The previous exception in the chain of exceptions, if any.
     */
    this(string msg,
         string file = __FILE__,
         size_t line = __LINE__,
         Throwable next = null) @nogc nothrow pure @safe
    {
        super(msg, file, line, next);
    }
}

/**
 * A Unique Resource Locator.
 */
struct URL
{
    /// The URL scheme.
    const(char)[] scheme;

    /// The username.
    const(char)[] user;

    /// The password.
    const(char)[] pass;

    /// The hostname.
    const(char)[] host;

    /// The port number.
    ushort port;

    /// The path.
    const(char)[] path;

    /// The query string.
    const(char)[] query;

    /// The anchor.
    const(char)[] fragment;

    /**
     * Attempts to parse an URL from a string.
     * Output string data (scheme, user, etc.) are just slices of input string
     * (i.e., no memory allocation and copying).
     *
     * Params:
     *  source = The string containing the URL.
     *
     * Throws: $(D_PSYMBOL URIException) if the URL is malformed.
     */
    this(const char[] source) @nogc pure
    {
        ptrdiff_t pos = -1, endPos = source.length, start;

        foreach (i, ref c; source)
        {
            if (pos == -1 && c == ':')
            {
                pos = i;
            }
            if (endPos == source.length && (c == '?' || c == '#'))
            {
                endPos = i;
            }
        }

        // Check if the colon is a part of the scheme or the port and parse
        // the appropriate part.
        if (source.length > 1 && source[0] == '/' && source[1] == '/')
        {
            // Relative scheme.
            start = 2;
        }
        else if (pos > 0)
        {
            // Validate scheme:
            // [ toLower(alpha) | digit | "+" | "-" | "." ]
            foreach (ref c; source[0 .. pos])
            {
                if (!c.isAlphaNum && c != '+' && c != '-' && c != '.')
                {
                    goto ParsePath;
                }
            }

            if (source.length == pos + 1) // only "scheme:" is available.
            {
                this.scheme = source[0 .. $ - 1];
                return;
            }
            else if (source.length > pos + 1 && source[pos + 1] == '/')
            {
                this.scheme = source[0 .. pos];

                if (source.length > pos + 2 && source[pos + 2] == '/')
                {
                    start = pos + 3;

                    if (source.length <= start)
                    {
                        // Only "scheme://" is available.
                        return;
                    }
                    if (this.scheme == "file" && source[start] == '/')
                    {
                        // Windows drive letters.
                        if (source.length - start > 2
                         && source[start + 2] == ':')
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
            else if (!parsePort(source[pos .. $]))
            {
                // Schemas like mailto: and zlib: may not have any slash after
                // them.
                this.scheme = source[0 .. pos];
                start = pos + 1;
                goto ParsePath;
            }
        }
        else if (pos == 0 && parsePort(source[pos .. $]))
        {
            // An URL shouldn't begin with a port number.
            throw defaultAllocator.make!URIException("URL begins with port");
        }
        else
        {
            goto ParsePath;
        }

        // Parse host.
        pos = -1;
        for (ptrdiff_t i = start; i < source.length; ++i)
        {
            if (source[i] == '@')
            {
                pos = i;
            }
            else if (source[i] == '/')
            {
                endPos = i;
                break;
            }
        }

        // Check for login and password.
        if (pos != -1)
        {
            // *( unreserved / pct-encoded / sub-delims / ":" )
            foreach (i, c; source[start .. pos])
            {
                if (c == ':')
                {
                    if (this.user is null)
                    {
                        this.user = source[start .. start + i];
                        this.pass = source[start + i + 1 .. pos]; 
                    }
                }
                else if (!c.isAlpha() &&
                         !c.isDigit() &&
                         c != '!' &&
                         c != ';' &&
                         c != '=' &&
                         c != '_' &&
                         c != '~' &&
                         !(c >= '$' && c <= '.'))
                {
                    this.scheme = this.user = this.pass = null;
                    throw make!URIException(defaultAllocator,
                                            "Restricted characters in user information");
                }
            }
            if (this.user is null)
            {
                this.user = source[start .. pos];
            }

            start = ++pos;
        }

        pos = endPos;
        if (endPos <= 1 || source[start] != '[' || source[endPos - 1] != ']')
        {
            // Short circuit portscan.
            // IPv6 embedded address.
            for (ptrdiff_t i = endPos - 1; i >= start; --i)
            {
                if (source[i] == ':')
                {
                    pos = i;
                    if  (this.port == 0 && !parsePort(source[i .. endPos]))
                    {
                        this.scheme = this.user = this.pass = null;
                        throw defaultAllocator.make!URIException("Invalid port");
                    }
                    break;
                }
            }
        }

        // Check if we have a valid host, if we don't reject the string as URL.
        if (pos <= start)
        {
            this.scheme = this.user = this.pass = null;
            throw defaultAllocator.make!URIException("Invalid host");
        }

        this.host = source[start .. pos];

        if (endPos == source.length)
        {
            return;
        }

        start = endPos;

    ParsePath:
        endPos = source.length;
        pos = -1;
        foreach (i, ref c; source[start .. $])
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
            this.path = source[start .. pos];
        }
        if (endPos >= ++pos)
        {
            this.query = source[pos .. endPos];
        }
        if (++endPos <= source.length)
        {
            this.fragment = source[endPos .. $];
        }
    }

    /*
     * Attempts to parse and set the port.
     *
     * Params:
     *  port = String beginning with a colon followed by the port number and
     *         an optional path (query string and/or fragment), like:
     *         `:12345/some_path` or `:12345`.
     *
     * Returns: Whether the port could be found.
     */
    private bool parsePort(const(char)[] port) @nogc nothrow pure @safe
    {
        auto unparsed = port[1 .. $];
        auto parsed = readIntegral!ushort(unparsed);
        if (unparsed.length == 0 || unparsed[0] == '/')
        {
            this.port = parsed;
            return true;
        }
        return false;
    }
}

///
@nogc pure @system unittest
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

/**
 * Attempts to parse an URL from a string and returns the specified component
 * of the URL or $(D_PSYMBOL URL) if no component is specified.
 *
 * Params:
 *  T      = "scheme", "host", "port", "user", "pass", "path", "query",
 *           "fragment".
 *  source = The string containing the URL.
 *
 * Returns: Requested URL component.
 */
auto parseURL(string T)(const char[] source)
if (T == "scheme"
 || T == "host"
 || T == "user"
 || T == "pass"
 || T == "path"
 || T == "query"
 || T == "fragment"
 || T == "port")
{
    auto ret = URL(source);
    return mixin("ret." ~ T);
}

/// ditto
URL parseURL(const char[] source) @nogc pure
{
    return URL(source);
}

///
@nogc pure @system unittest
{
    auto u = parseURL("http://example.org:5326");
    assert(u.scheme == parseURL!"scheme"("http://example.org:5326"));
    assert(u.host == parseURL!"host"("http://example.org:5326"));
    assert(u.user == parseURL!"user"("http://example.org:5326"));
    assert(u.pass == parseURL!"pass"("http://example.org:5326"));
    assert(u.path == parseURL!"path"("http://example.org:5326"));
    assert(u.query == parseURL!"query"("http://example.org:5326"));
    assert(u.fragment == parseURL!"fragment"("http://example.org:5326"));
    assert(u.port == parseURL!"port"("http://example.org:5326"));
}
