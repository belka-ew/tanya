/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Copyright: Eugene Wissner 2016.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:belka@caraus.de, Eugene Wissner)
 */
module tanya.async.transport;

import tanya.network.socket;

/**
 * Base transport interface.
 */
interface Transport
{
}

/**
 * Interface for read-only transports.
 */
interface ReadTransport : Transport
{
}

/**
 * Interface for write-only transports.
 */
interface WriteTransport : Transport
{
    /**
     * Write some data to the transport.
     *
     * Params:
     *     data = Data to send.
     */
    void write(ubyte[] data);
}

/**
 * Represents a bidirectional transport.
 */
interface DuplexTransport : ReadTransport, WriteTransport
{
}

/**
 * Represents a socket transport.
 */
interface SocketTransport : Transport
{
    @property inout(Socket) socket() inout pure nothrow @safe @nogc;
}

/**
 * Represents a connection-oriented socket transport.
 */
package interface StreamTransport : DuplexTransport, SocketTransport
{
}
