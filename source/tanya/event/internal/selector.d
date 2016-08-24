/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Copyright: Eugene Wissner 2016.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:belka@caraus.de, Eugene Wissner)
 */  
module tanya.event.internal.selector;

import tanya.memory;
import tanya.container.buffer;
import tanya.event.loop;
import tanya.event.protocol;
import tanya.event.transport;
import core.stdc.errno;
import core.sys.posix.netinet.in_;
import core.sys.posix.unistd;

/**
 * Transport for stream sockets.
 */
class SocketTransport : DuplexTransport
{
@nogc:
	private int socket_ = -1;

	private Protocol protocol_;

	/// Input buffer.
	private WriteBuffer input_;

	/// Output buffer.
	private ReadBuffer output_;

	private Loop loop;

	private bool disconnected_;

	package bool writeReady;

	/**
	 * Params:
	 * 	loop     = Event loop.
	 * 	socket   = Socket.
	 * 	protocol = Protocol.
	 */
	this(Loop loop, int socket, Protocol protocol = null)
	{
		socket_ = socket;
		protocol_ = protocol;
		this.loop = loop;
		input_ = make!WriteBuffer(defaultAllocator);
		output_ = make!ReadBuffer(defaultAllocator);
	}

	/**
	 * Close the transport and deallocate the data buffers.
	 */
	~this()
	{
		close(socket);
		finalize(defaultAllocator, input_);
		finalize(defaultAllocator, output_);
		finalize(defaultAllocator, protocol_);
	}

	/**
	 * Returns: Transport socket.
	 */
	int socket() const @safe pure nothrow
	{
		return socket_;
	}

	/**
	 * Returns: Protocol.
	 */
	@property Protocol protocol() @safe pure nothrow
	{
		return protocol_;
	}

	/**
	 *  Returns: $(D_KEYWORD true) if the remote peer closed the connection,
	 *           $(D_KEYWORD false) otherwise.
	 */
	@property immutable(bool) disconnected() const @safe pure nothrow
	{
		return disconnected_;
	}

	/**
	 * Params:
	 * 	protocol = Application protocol.
	 */
	@property void protocol(Protocol protocol) @safe pure nothrow
	{
		protocol_ = protocol;
	}

	/**
	 * Returns: Application protocol.
	 */
	@property inout(Protocol) protocol() inout @safe pure nothrow
	{
		return protocol_;
	}

	/**
	 * Write some data to the transport.
	 *
	 * Params:
	 * 	data = Data to send.
	 */
	void write(ubyte[] data)
	{
		// If the buffer wasn't empty the transport should be already there.
		if (!input.length && data.length)
		{
			loop.feed(this);
		}
		input ~= data;
	}

	/**
	 * Returns: Input buffer.
	 */
	@property WriteBuffer input() @safe pure nothrow
	{
		return input_;
	}

	/**
	 * Returns: Output buffer.
	 */
	@property ReadBuffer output() @safe pure nothrow
	{
		return output_;
	}

	/**
	 * Read data from the socket. Returns $(D_KEYWORD true) if the reading
	 * is completed. In the case that the peer closed the connection, returns
	 * $(D_KEYWORD true) aswell.
	 *
	 * Returns: Whether the reading is completed.
	 *
	 * Throws: $(D_PSYMBOL TransportException) if a read error is occured.
	 */
	bool receive()
	{
		auto readCount = recv(socket, output.buffer, output.free, 0);

		if (readCount > 0)
		{
			output_ ~= output.buffer[0..readCount];
			return false;
		}
		else if (readCount == 0)
		{
			disconnected_ = true;
			return true;
		}
		else if (errno == EAGAIN || errno == EWOULDBLOCK)
		{
			return true;
		}
		else
		{
			disconnected_ = true;
			throw make!TransportException(defaultAllocator,
			                              "Read from the socket failed.");
		}
	}

	/**
	 * Returns: Whether the writing is completed.
	 *
	 * Throws: $(D_PSYMBOL TransportException) if a read error is occured.
	 */
	bool send()
	{
		auto sentCount = core.sys.posix.netinet.in_.send(socket,
		                                                 input.buffer,
		                                                 input.length,
		                                                 0);

		input.written = sentCount;
		if (input.length == 0)
		{
			return true;
		}
		else if (sentCount >= 0)
		{
			loop.feed(this);

			return false;
		}
		else if (errno == EAGAIN || errno == EWOULDBLOCK)
		{
			writeReady = false;
			loop.feed(this);

			return false;
		}
		else
		{
			disconnected_ = true;
			loop.feed(this);
			throw make!TransportException(defaultAllocator,
			                              "Write to the socket failed.");
		}
	}
}
