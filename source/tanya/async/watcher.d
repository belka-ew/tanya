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

version (Windows)
{
	import core.sys.windows.basetyps;
	import core.sys.windows.mswsock;
	import core.sys.windows.winbase;
	import core.sys.windows.windef;
	import core.sys.windows.winsock2;
}

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

class ConnectionWatcher : Watcher
{
	/// Watched socket.
	protected Socket socket_;

	/// Protocol factory.
	protected Protocol delegate() @nogc protocolFactory;

	package Queue!DuplexTransport incoming;

	/**
	 * Params:
	 * 	socket = Socket.
	 */
	this(Socket socket) @nogc
	{
		incoming = Queue!DuplexTransport(MmapPool.instance);
		socket_ = socket;
	}

	/**
	 * Destroys the watcher.
	 */
	~this() @nogc
	{
		foreach (w; incoming)
		{
			MmapPool.instance.dispose(w);
		}
	}

	/**
	 * Params:
	 * 	P = Protocol should be used.
	 */
	void setProtocol(P : Protocol)() @nogc
	{
		this.protocolFactory = () @nogc => cast(Protocol) MmapPool.instance.make!P;
	}

	/**
	 * Returns: Socket.
	 */
	@property Socket socket() pure nothrow @safe @nogc
	{
		return socket_;
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

/**
 * Contains a pending watcher with the invoked events or a transport can be
 * read from.
 */
class IOWatcher : ConnectionWatcher
{
	package SocketException exception;

	protected Protocol protocol_;

	/**
	 * Returns: Underlying output buffer.
	 */
	package ReadBuffer!ubyte output;

	/**
	 * Params:
	 * 	socket = Socket.
	 *
	 * Precondition: $(D_INLINECODE socket !is null)
	 */
	this(ConnectedSocket socket) @nogc
	in
	{
		assert(socket !is null);
	}
	body
	{
		super(socket);
		output = ReadBuffer!ubyte(8192, 1024, MmapPool.instance);
		active = true;
	}

	/**
	 * Destroys the watcher.
	 */
	~this() @nogc
	{
		MmapPool.instance.dispose(protocol_);
	}

	/**
	 * Returns: Application protocol.
	 */
	@property Protocol protocol() pure nothrow @safe @nogc
	{
		return protocol_;
	}

	/**
	 * Returns: Socket.
	 *
	 * Precondition: $(D_INLINECODE socket !is null)
	 */
	override @property ConnectedSocket socket() pure nothrow @safe @nogc
	out (socket)
	{
		assert(socket !is null);
	}
	body
	{
		return cast(ConnectedSocket) socket_;
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
		}
		else
		{
			protocol.disconnected(exception);
			MmapPool.instance.dispose(protocol);
			defaultAllocator.dispose(exception);
			active = false;
		}
	}
}
