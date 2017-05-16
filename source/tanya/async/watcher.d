/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Copyright: Eugene Wissner 2016-2017.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 */
module tanya.async.watcher;

import std.functional;
import std.exception;
import tanya.async.loop;
import tanya.async.protocol;
import tanya.async.transport;
import tanya.container.buffer;
import tanya.container.queue;
import tanya.memory;
import tanya.memory.mmappool;
import tanya.network.socket;

/**
 * A watcher is an opaque structure that you allocate and register to record
 * your interest in some event. 
 */
abstract class Watcher
{
    /// Whether the watcher is active.
    bool active;

    /**
     * Invoke some action on event.
     */
    void invoke() @nogc;
}

/**
 * Socket watcher.
 */
abstract class SocketWatcher : Watcher
{
    /// Watched socket.
    protected Socket socket_;

    /**
     * Params:
     *  socket = Socket.
     *
     * Precondition: $(D_INLINECODE socket !is null)
     */
    this(Socket socket) pure nothrow @safe @nogc
    in
    {
        assert(socket !is null);
    }
    body
    {
        socket_ = socket;
    }

    /**
     * Returns: Socket.
     */
    @property Socket socket() pure nothrow @safe @nogc
    {
        return socket_;
    }
}

/**
 * Connection watcher.
 */
class ConnectionWatcher : SocketWatcher
{
    /// Incoming connection queue.
    Queue!DuplexTransport incoming;

    private Protocol delegate() @nogc protocolFactory;

    /**
     * Params:
     *  socket = Socket.
     */
    this(Socket socket) @nogc
    {
        super(socket);
        incoming = Queue!DuplexTransport(MmapPool.instance);
    }

    /**
     * Params:
     *  P = Protocol should be used.
     */
    void setProtocol(P : Protocol)() @nogc
    {
        this.protocolFactory = () @nogc => cast(Protocol) MmapPool.instance.make!P;
    }

    /**
     * Invokes new connection callback.
     */
    override void invoke() @nogc
    in
    {
        assert(protocolFactory !is null, "Protocol isn't set.");
    }
    body
    {
        foreach (transport; incoming)
        {
            transport.protocol = protocolFactory();
            transport.protocol.connected(transport);
        }
    }
}
