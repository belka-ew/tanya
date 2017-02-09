/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Copyright: Eugene Wissner 2016-2017.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 */
module tanya.async.event.selector;

version (Posix):

import tanya.async.loop;
import tanya.async.protocol;
import tanya.async.transport;
import tanya.async.watcher;
import tanya.container.buffer;
import tanya.container.vector;
import tanya.memory;
import tanya.memory.mmappool;
import tanya.network.socket;

/**
 * Transport for stream sockets.
 */
class SelectorStreamTransport : IOWatcher, StreamTransport
{
	/// Input buffer.
	package WriteBuffer!ubyte input;

	private SelectorLoop loop;

	/// Received notification that the underlying socket is write-ready.
	package bool writeReady;

	/**
	 * Params:
	 * 	loop     = Event loop.
	 * 	socket   = Socket.
	 *
	 * Precondition: $(D_INLINECODE loop !is null && socket !is null)
	 */
	this(SelectorLoop loop, ConnectedSocket socket) @nogc
	in 
	{
		assert(loop !is null);
		assert(socket !is null);
	}
	body
	{
		super(socket);
		this.loop = loop;
		input = WriteBuffer!ubyte(8192, MmapPool.instance);
	}

	/**
	 * Returns: Socket.
	 */
	override @property ConnectedSocket socket() pure nothrow @safe @nogc
	{
		return cast(ConnectedSocket) socket_;
	}

	private @property void socket(ConnectedSocket socket) pure nothrow @safe @nogc
	in
	{
		assert(socket !is null);
	}
	body
	{
		socket_ = socket;
	}

	/**
	 * Switches the protocol.
	 *
	 * The protocol is deallocated by the event loop, it should currently be
	 * allocated with $(D_PSYMBOL MmapPool).
	 *
	 * Params:
	 * 	protocol = Application protocol.
	 *
	 * Precondition: $(D_INLINECODE protocol !is null)
	 */
	@property void protocol(Protocol protocol) pure nothrow @safe @nogc
	in
	{
		assert(protocol !is null);
	}
	body
	{
		protocol_ = protocol;
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
	protected Vector!ConnectionWatcher connections;

	this() @nogc
	{
		super();
		connections = Vector!ConnectionWatcher(maxEvents, MmapPool.instance);
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
			connections.length = watcher.socket.handle + maxEvents / 2;
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

			SelectorStreamTransport transport;

			if (connections.length > client.handle)
			{
				transport = cast(SelectorStreamTransport) connections[client.handle];
			}
			else
			{
				connections.length = client.handle + maxEvents / 2;
			}
			if (transport is null)
			{
				transport = MmapPool.instance.make!SelectorStreamTransport(this, client);
				connections[client.handle] = transport;
			}
			else
			{
				transport.socket = client;
			}

			reify(transport, EventMask(Event.none), EventMask(Event.read, Event.write));
			connection.incoming.enqueue(transport);
		}

		if (!connection.incoming.empty)
		{
			pendings.enqueue(connection);
		}
	}
}
