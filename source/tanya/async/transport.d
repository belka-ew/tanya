/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Copyright: Eugene Wissner 2016-2017.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 */
module tanya.async.transport;

import tanya.async.protocol;
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
     *  data = Data to send.
     */
    void write(ubyte[] data) @nogc;
}

/**
 * Represents a bidirectional transport.
 */
interface DuplexTransport : ReadTransport, WriteTransport
{
    /**
     * Returns: Application protocol.
     *
     * Postcondition: $(D_INLINECODE protocol !is null)
     */
    @property Protocol protocol() pure nothrow @safe @nogc
    out (protocol)
    {
        assert(protocol !is null);
    }

    /**
     * Switches the protocol.
     *
     * The protocol is deallocated by the event loop, it should currently be
     * allocated with $(D_PSYMBOL MmapPool).
     *
     * Params:
     *  protocol = Application protocol.
     *
     * Precondition: $(D_INLINECODE protocol !is null)
     */
    @property void protocol(Protocol protocol) pure nothrow @safe @nogc
    in
    {
        assert(protocol !is null);
    }


    /**
     * Returns $(D_PARAM true) if the transport is closing or closed.
     */
    bool isClosing() const pure nothrow @safe @nogc;

    /**
     * Close the transport.
     *
     * Buffered data will be flushed.  No more data will be received.
     */
    void close() @nogc;
}

/**
 * Represents a socket transport.
 */
interface SocketTransport : Transport
{
    /**
     * Returns: Socket.
     */
    @property Socket socket() pure nothrow @safe @nogc;
}
