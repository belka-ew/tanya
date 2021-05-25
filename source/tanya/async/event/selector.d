/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/*
 * This module contains base implementations for reactor event loops.
 *
 * Copyright: Eugene Wissner 2016-2020.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/async/event/selector.d,
 *                 tanya/async/event/selector.d)
 */
module tanya.async.event.selector;

version (D_Ddoc)
{
}
else version (Posix):

import tanya.async.loop;
import tanya.async.protocol;
import tanya.async.transport;
import tanya.async.watcher;
import tanya.container.array;
import tanya.container.buffer;
import tanya.memory.allocator;
import tanya.network.socket;

/**
 * Transport for stream sockets.
 */
package class StreamTransport : SocketWatcher, DuplexTransport, SocketTransport
{
    private SelectorLoop loop;

    private SocketException exception;

    package ReadBuffer!ubyte output;

    package WriteBuffer!ubyte input;

    private Protocol protocol_;

    private bool closing;

    /// Received notification that the underlying socket is write-ready.
    package bool writeReady;

    /**
     * Params:
     *  loop   = Event loop.
     *  socket = Socket.
     *
     * Precondition: $(D_INLINECODE loop !is null && socket !is null)
     */
    this(SelectorLoop loop, ConnectedSocket socket) @nogc
    in 
    {
        assert(loop !is null);
    }
    do
    {
        super(socket);
        this.loop = loop;
        output = ReadBuffer!ubyte(8192, 1024);
        input = WriteBuffer!ubyte(8192);
        active = true;
    }

    /**
     * Returns: Socket.
     *
     * Postcondition: $(D_INLINECODE socket !is null)
     */
    override @property ConnectedSocket socket() pure nothrow @safe @nogc
    out (socket)
    {
        assert(socket !is null);
    }
    do
    {
        return cast(ConnectedSocket) socket_;
    }

    private @property void socket(ConnectedSocket socket)
    pure nothrow @safe @nogc
    in
    {
        assert(socket !is null);
    }
    do
    {
        socket_ = socket;
    }

    /**
     * Returns: Application protocol.
     */
    @property Protocol protocol() pure nothrow @safe @nogc
    {
        return protocol_;
    }

    /**
     * Switches the protocol.
     *
     * The protocol is deallocated by the event loop.
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
    do
    {
        protocol_ = protocol;
    }

    /**
     * Returns $(D_PARAM true) if the transport is closing or closed.
     */
    bool isClosing() const pure nothrow @safe @nogc
    {
        return closing;
    }

    /**
     * Close the transport.
     *
     * Buffered data will be flushed.  No more data will be received.
     */
    void close() @nogc
    {
        closing = true;
        loop.reify(this,
                   EventMask(Event.read | Event.write),
                   EventMask(Event.write));
    }

    /**
     * Invokes the watcher callback.
     */
    override void invoke() @nogc
    {
        if (output.length)
        {
            protocol.received(output[0 .. $]);
            output.clear();
            if (isClosing() && input.length == 0)
            {
                loop.kill(this);
            }
        }
        else
        {
            protocol.disconnected(exception);
            defaultAllocator.dispose(protocol_);
            defaultAllocator.dispose(exception);
            active = false;
        }
    }

    /**
     * Write some data to the transport.
     *
     * Params:
     *  data = Data to send.
     */
    void write(ubyte[] data) @nogc
    {
        if (!data.length)
        {
            return;
        }
        // Try to write if the socket is write ready.
        if (writeReady)
        {
            ptrdiff_t sent;
            SocketException exception;
            try
            {
                sent = socket.send(data);
                if (sent == 0)
                {
                    writeReady = false;
                }
            }
            catch (SocketException e)
            {
                writeReady = false;
                exception = e;
            }
            if (sent < data.length)
            {
                input ~= data[sent..$];
                loop.feed(this, exception);
            }
        }
        else
        {
            input ~= data;
        }
    }
}

abstract class SelectorLoop : Loop
{
    /// Pending connections.
    protected Array!SocketWatcher connections;

    this() @nogc
    {
        super();
        this.connections = Array!SocketWatcher(maxEvents);
    }

    ~this() @nogc
    {
        foreach (ref connection; this.connections[])
        {
            // We want to free only the transports. ConnectionWatcher are
            // created by the user and should be freed by himself.
            if (cast(StreamTransport) connection !is null)
            {
                defaultAllocator.dispose(connection);
            }
        }
    }

    /**
     * Should be called if the backend configuration changes.
     *
     * Params:
     *  watcher   = Watcher.
     *  oldEvents = The events were already set.
     *  events    = The events should be set.
     *
     * Returns: $(D_KEYWORD true) if the operation was successful.
     */
    override abstract protected bool reify(SocketWatcher watcher,
                                           EventMask oldEvents,
                                           EventMask events) @nogc;

    /**
     * Kills the watcher and closes the connection.
     *
     * Params:
     *  transport = Transport.
     *  exception = Occurred exception.
     */
    protected void kill(StreamTransport transport,
                        SocketException exception = null) @nogc
    in
    {
        assert(transport !is null);
    }
    do
    {
        transport.socket.shutdown();
        defaultAllocator.dispose(transport.socket);
        transport.exception = exception;
        pendings.insertBack(transport);
    }

    /**
     * If the transport couldn't send the data, the further sending should
     * be handled by the event loop.
     *
     * Params:
     *  transport = Transport.
     *  exception = Exception thrown on sending.
     *
     * Returns: $(D_KEYWORD true) if the operation could be successfully
     *          completed or scheduled, $(D_KEYWORD false) otherwise (the
     *          transport will be destroyed then).
     */
    protected bool feed(StreamTransport transport,
                        SocketException exception = null) @nogc
    in
    {
        assert(transport !is null);
    }
    do
    {
        while (transport.input.length && transport.writeReady)
        {
            try
            {
                ptrdiff_t sent = transport.socket.send(transport.input[]);
                if (sent == 0)
                {
                    transport.writeReady = false;
                }
                else
                {
                    transport.input += sent;
                }
            }
            catch (SocketException e)
            {
                exception = e;
                transport.writeReady = false;
            }
        }
        if (exception !is null)
        {
            kill(transport, exception);
            return false;
        }
        if (transport.input.length == 0 && transport.isClosing())
        {
            kill(transport);
        }
        return true;
    }

    /**
     * Start watching.
     *
     * Params:
     *  watcher = Watcher.
     */
    override void start(ConnectionWatcher watcher) @nogc
    {
        if (watcher.active)
        {
            return;
        }

        if (connections.length <= watcher.socket)
        {
            connections.length = watcher.socket.handle + maxEvents / 2;
        }
        connections[watcher.socket.handle] = watcher;

        super.start(watcher);
    }

    /**
     * Accept incoming connections.
     *
     * Params:
     *  connection = Connection watcher ready to accept.
     */
    package void acceptConnections(ConnectionWatcher connection) @nogc
    in
    {
        assert(connection !is null);
    }
    do
    {
        while (true)
        {
            ConnectedSocket client;
            try
            {
                client = (cast(StreamSocket) connection.socket).accept();
            }
            catch (SocketException e)
            {
                defaultAllocator.dispose(e);
                break;
            }
            if (client is null)
            {
                break;
            }

            StreamTransport transport;

            if (connections.length > client.handle)
            {
                transport = cast(StreamTransport) connections[client.handle];
            }
            else
            {
                connections.length = client.handle + maxEvents / 2;
            }
            if (transport is null)
            {
                transport = defaultAllocator.make!StreamTransport(this, client);
                connections[client.handle] = transport;
            }
            else
            {
                transport.socket = client;
            }

            reify(transport,
                  EventMask(Event.none),
                  EventMask(Event.read | Event.write));
            connection.incoming.insertBack(transport);
        }

        if (!connection.incoming.empty)
        {
            pendings.insertBack(connection);
        }
    }
}
