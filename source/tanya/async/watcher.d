/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Watchers register user's interest in some event.
 *
 * Copyright: Eugene Wissner 2016-2020.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/async/watcher.d,
 *                 tanya/async/watcher.d)
 */
module tanya.async.watcher;

import tanya.async.loop;
import tanya.async.protocol;
import tanya.async.transport;
import tanya.container.buffer;
import tanya.container.list;
import tanya.memory.allocator;
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
    in (socket !is null)
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
    DList!DuplexTransport incoming;

    private Protocol delegate() @nogc protocolFactory;

    /**
     * Params:
     *  socket = Socket.
     */
    this(Socket socket) @nogc
    {
        super(socket);
    }

    /**
     * Params:
     *  P = Protocol should be used.
     */
    void setProtocol(P : Protocol)() @nogc
    {
        this.protocolFactory = () @nogc => cast(Protocol) defaultAllocator.make!P;
    }

    /**
     * Invokes new connection callback.
     */
    override void invoke() @nogc
    in (protocolFactory !is null, "Protocol isn't set.")
    {
        for (; !this.incoming.empty; this.incoming.removeFront())
        {
            this.incoming.front.protocol = protocolFactory();
            this.incoming.front.protocol.connected(this.incoming.front);
        }
    }
}
