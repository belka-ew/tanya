/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Copyright: Eugene Wissner 2016.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:belka@caraus.de, Eugene Wissner)
 */
module tanya.async.event.selector;

version (Posix):

import tanya.async.loop;
import tanya.async.transport;
import tanya.async.watcher;
import tanya.container.buffer;
import tanya.memory;
import tanya.memory.mmappool;
import tanya.network.socket;
import core.sys.posix.netinet.in_;
import core.stdc.errno;

/**
 * Transport for stream sockets.
 */
class SelectorStreamTransport : StreamTransport
{
	private ConnectedSocket socket_;

	/// Input buffer.
	package WriteBuffer!ubyte input;

	private SelectorLoop loop;

	/// Received notification that the underlying socket is write-ready.
	package bool writeReady;

	/**
	 * Params:
	 * 	loop     = Event loop.
	 * 	socket   = Socket.
	 */
	this(SelectorLoop loop, ConnectedSocket socket) @nogc
	{
		socket_ = socket;
		this.loop = loop;
		input = WriteBuffer!ubyte(8192, MmapPool.instance);
	}

	/**
	 * Returns: Transport socket.
	 */
	inout(ConnectedSocket) socket() inout pure nothrow @safe @nogc
	{
		return socket_;
	}

	/**
	 * Write some data to the transport.
	 *
	 * Params:
	 * 	data = Data to send.
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
	protected ConnectionWatcher[] connections;

	this() @nogc
	{
		super();
		MmapPool.instance.resizeArray(connections, maxEvents);
	}

	~this() @nogc
	{
		foreach (ref connection; connections)
		{
			// We want to free only IOWatchers. ConnectionWatcher are created by the
			// user and should be freed by himself.
			auto io = cast(IOWatcher) connection;
			if (io !is null)
			{
				MmapPool.instance.dispose(io);
				connection = null;
			}
		}
		MmapPool.instance.dispose(connections);
	}

	/**
	 * If the transport couldn't send the data, the further sending should
	 * be handled by the event loop.
	 *
	 * Params:
	 * 	transport = Transport.
	 * 	exception = Exception thrown on sending.
	 *
	 * Returns: $(D_KEYWORD true) if the operation could be successfully
	 *          completed or scheduled, $(D_KEYWORD false) otherwise (the
	 *          transport will be destroyed then).
	 */
	protected bool feed(SelectorStreamTransport transport,
	                    SocketException exception = null) @nogc
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
			auto watcher = cast(IOWatcher) connections[transport.socket.handle];
			assert(watcher !is null);

			kill(watcher, exception);
			return false;
		}
		return true;
	}

	/**
	 * Start watching.
	 *
	 * Params:
	 * 	watcher = Watcher.
	 */
	override void start(ConnectionWatcher watcher) @nogc
	{
		if (watcher.active)
		{
			return;
		}

		if (connections.length <= watcher.socket)
		{
			MmapPool.instance.resizeArray(connections, watcher.socket.handle + maxEvents / 2);
		}
		connections[watcher.socket.handle] = watcher;

		super.start(watcher);
	}

	/**
	 * Accept incoming connections.
	 *
	 * Params:
	 * 	connection = Connection watcher ready to accept.
	 */
	package void acceptConnections(ConnectionWatcher connection) @nogc
	in
	{
		assert(connection !is null);
	}
	body
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

			IOWatcher io;
			auto transport = MmapPool.instance.make!SelectorStreamTransport(this, client);

			if (connections.length > client.handle)
			{
				io = cast(IOWatcher) connections[client.handle];
			}
			else
			{
				MmapPool.instance.resizeArray(connections, client.handle + maxEvents / 2);
			}
			if (io is null)
			{
				io = MmapPool.instance.make!IOWatcher(transport,
				                                      connection.protocol);
				connections[client.handle] = io;
			}
			else
			{
				io(transport, connection.protocol);
			}

			reify(io, EventMask(Event.none), EventMask(Event.read, Event.write));
			connection.incoming.enqueue(io);
		}

		if (!connection.incoming.empty)
		{
			swapPendings.enqueue(connection);
		}
	}
}
