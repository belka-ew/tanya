/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */
module tanya.net.tests.uri;

import tanya.net.uri;
import tanya.test.assertion;

@nogc pure @system unittest
{
    const u = URL("127.0.0.1");
    assert(u.path == "127.0.0.1");
}

@nogc pure @system unittest
{
    const u = URL("http://127.0.0.1");
    assert(u.scheme == "http");
    assert(u.host == "127.0.0.1");
}

@nogc pure @system unittest
{
    const u = URL("http://127.0.0.1:9000");
    assert(u.scheme == "http");
    assert(u.host == "127.0.0.1");
    assert(u.port == 9000);
}

@nogc pure @system unittest
{
    const u = URL("127.0.0.1:80");
    assert(u.host == "127.0.0.1");
    assert(u.port == 80);
    assert(u.path is null);
}

@nogc pure @system unittest
{
    const u = URL("//example.net");
    assert(u.host == "example.net");
    assert(u.scheme is null);
}

@nogc pure @system unittest
{
    const u = URL("//example.net?q=before:after");
    assert(u.host == "example.net");
    assert(u.query == "q=before:after");
}

@nogc pure @system unittest
{
    const u = URL("localhost:8080");
    assert(u.host == "localhost");
    assert(u.port == 8080);
    assert(u.path is null);
}

@nogc pure @system unittest
{
    const u = URL("ftp:");
    assert(u.scheme == "ftp");
}

@nogc pure @system unittest
{
    const u = URL("file:///C:\\Users");
    assert(u.scheme == "file");
    assert(u.path == "C:\\Users");
}

@nogc pure @system unittest
{
    const u = URL("localhost:66000");
    assert(u.scheme == "localhost");
    assert(u.path == "66000");
}

@nogc pure @system unittest
{
    const u = URL("file:///home/");
    assert(u.scheme == "file");
    assert(u.path == "/home/");
}

@nogc pure @system unittest
{
    const u = URL("file:///home/?q=asdf");
    assert(u.scheme == "file");
    assert(u.path == "/home/");
    assert(u.query == "q=asdf");
}

@nogc pure @system unittest
{
    const u = URL("http://secret@example.org");
    assert(u.scheme == "http");
    assert(u.host == "example.org");
    assert(u.user == "secret");
}

@nogc pure @system unittest
{
    const u = URL("h_tp://:80");
    assert(u.path == "h_tp://:80");
    assert(u.port == 0);
}

@nogc pure @system unittest
{
    const u = URL("zlib:/home/user/file.gz");
    assert(u.scheme == "zlib");
    assert(u.path == "/home/user/file.gz");
}

@nogc pure @system unittest
{
    const u = URL("h_tp:asdf");
    assert(u.path == "h_tp:asdf");
}

@nogc pure @system unittest
{
    assertThrown!URIException(() => URL("http://:80"));
    assertThrown!URIException(() => URL(":80"));
    assertThrown!URIException(() => URL("http://u1:p1@u2:p2@example.org"));
    assertThrown!URIException(() => URL("http://blah.com:port"));
    assertThrown!URIException(() => URL("http://blah.com:66000"));
}

@nogc pure @system unittest
{
    const u = URL("ftp://");
    assert(u.scheme == "ftp");
}
