/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Low-level socket programming.
 *
 * Current API supports only server-side TCP communication.
 *
 * Here is an example of a cross-platform blocking server:
 *
 * ---
 * import std.stdio;
 * import tanya.memory;
 * import tanya.network;
 *
 * void main()
 * {
 *     auto socket = defaultAllocator.make!StreamSocket(AddressFamily.inet);
 *     auto address = defaultAllocator.make!InternetAddress("127.0.0.1",
 *                                                          cast(ushort) 8192);
 *
 *     socket.setOption(SocketOptionLevel.SOCKET, SocketOption.REUSEADDR, true);
 *     socket.blocking = true;
 *     socket.bind(address);
 *     socket.listen(5);
 *
 *     auto client = socket.accept();
 *     client.send(cast(const(ubyte)[]) "Test\n");
 *
 *     ubyte[100] buf;
 *     auto response = client.receive(buf[]);
 *
 *     writeln(cast(const(char)[]) buf[0 .. response]);
 *
 *     defaultAllocator.dispose(client);
 *     defaultAllocator.dispose(socket);
 * }
 * ---
 *
 * For an example of an asynchronous server refer to the documentation of the
 * $(D_PSYMBOL tanya.async.loop) module.
 *
 * Copyright: Eugene Wissner 2016-2020.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/network/socket.d,
 *                 tanya/network/socket.d)
 */
module tanya.network.socket;

import core.stdc.errno;
import core.time;
public import std.socket : SocketOption, SocketOptionLevel;
import tanya.bitmanip;
import tanya.memory.allocator;
import tanya.meta.trait;
import tanya.os.error;

/// Value returned by socket operations on error.
enum int socketError = -1;

version (Posix)
{
    import core.stdc.errno;
    import core.sys.posix.fcntl;
    import core.sys.posix.netdb;
    import core.sys.posix.netinet.in_;
    import core.sys.posix.sys.socket;
    import core.sys.posix.sys.time;
    import core.sys.posix.unistd;

    enum SocketType : int
    {
        init = -1,
    }

    private alias LingerField = int;
}
else version (Windows)
{
    import core.sys.windows.winbase;
    import core.sys.windows.winerror;
    import core.sys.windows.winsock2 : accept,
                                       addrinfo,
                                       bind,
                                       closesocket,
                                       FIONBIO,
                                       freeaddrinfo,
                                       getaddrinfo,
                                       getsockopt,
                                       ioctlsocket,
                                       listen,
                                       MSG_DONTROUTE,
                                       MSG_OOB,
                                       MSG_PEEK,
                                       recv,
                                       SD_BOTH,
                                       SD_RECEIVE,
                                       SD_SEND,
                                       send,
                                       setsockopt,
                                       shutdown,
                                       SO_TYPE,
                                       SOCKADDR,
                                       sockaddr,
                                       sockaddr_in,
                                       sockaddr_in6,
                                       SOCKADDR_STORAGE,
                                       socket,
                                       socklen_t,
                                       SOL_SOCKET,
                                       WSAEWOULDBLOCK,
                                       WSAGetLastError;
    import tanya.async.iocp;
    import tanya.sys.windows.def;
    public import tanya.sys.windows.winbase;
    public import tanya.sys.windows.winsock2;

    enum SocketType : size_t
    {
        init = ~0,
    }

    private alias LingerField = ushort;

    enum OverlappedSocketEvent
    {
        accept = 1,
        read = 2,
        write = 3,
    }

    class SocketState : State
    {
        private WSABUF buffer;
    }

    /**
     * Socket returned if a connection has been established.
     *
     * Note: Available only on Windows.
     */
    class OverlappedConnectedSocket : ConnectedSocket
    {
        /**
         * Create a socket.
         *
         * Params:
         *  handle = Socket handle.
         *  af     = Address family.
         */
        this(SocketType handle, AddressFamily af) @nogc
        {
            super(handle, af);
        }

        /**
         * Begins to asynchronously receive data from a connected socket.
         *
         * Params:
         *  buffer     = Storage location for the received data.
         *  flags      = Flags.
         *  overlapped = Unique operation identifier.
         *
         * Returns: $(D_KEYWORD true) if the operation could be finished synchronously.
         *          $(D_KEYWORD false) otherwise.
         *
         * Throws: $(D_PSYMBOL SocketException) if unable to receive.
         */
        bool beginReceive(ubyte[] buffer,
                          SocketState overlapped,
                          Flags flags = Flags(Flag.none)) @nogc @trusted
        {
            auto receiveFlags = cast(DWORD) flags;

            overlapped.handle = cast(HANDLE) handle_;
            overlapped.event = OverlappedSocketEvent.read;
            overlapped.buffer.len = cast(ULONG) buffer.length;
            overlapped.buffer.buf = cast(char*) buffer.ptr;

            auto result = WSARecv(handle_,
                                  cast(WSABUF*) &overlapped.buffer,
                                  1u,
                                  null,
                                  &receiveFlags,
                                  &overlapped.overlapped,
                                  null);

            if (result == socketError && !wouldHaveBlocked)
            {
                throw defaultAllocator.make!SocketException("Unable to receive");
            }
            return result == 0;
        }

        /**
         * Ends a pending asynchronous read.
         *
         * Params:
         *  overlapped = Unique operation identifier.
         *
         * Returns: Number of bytes received.
         *
         * Throws: $(D_PSYMBOL SocketException) if unable to receive.
         *
         * Postcondition: $(D_INLINECODE result >= 0).
         */
        int endReceive(SocketState overlapped) @nogc @trusted
        out (count)
        {
            assert(count >= 0);
        }
        do
        {
            DWORD lpNumber;
            BOOL result = GetOverlappedResult(overlapped.handle,
                                              &overlapped.overlapped,
                                              &lpNumber,
                                              FALSE);
            if (result == FALSE && !wouldHaveBlocked)
            {
                disconnected_ = true;
                throw defaultAllocator.make!SocketException("Unable to receive");
            }
            if (lpNumber == 0)
            {
                disconnected_ = true;
            }
            return lpNumber;
        }

        /**
         * Sends data asynchronously to a connected socket.
         *
         * Params:
         *  buffer     = Data to be sent.
         *  flags      = Flags.
         *  overlapped = Unique operation identifier.
         *
         * Returns: $(D_KEYWORD true) if the operation could be finished synchronously.
         *          $(D_KEYWORD false) otherwise.
         *
         * Throws: $(D_PSYMBOL SocketException) if unable to send.
         */
        bool beginSend(ubyte[] buffer,
                       SocketState overlapped,
                       Flags flags = Flags(Flag.none)) @nogc @trusted
        {
            overlapped.handle = cast(HANDLE) handle_;
            overlapped.event = OverlappedSocketEvent.write;
            overlapped.buffer.len = cast(ULONG) buffer.length;
            overlapped.buffer.buf = cast(char*) buffer.ptr;

            auto result = WSASend(handle_,
                                  &overlapped.buffer,
                                  1u,
                                  null,
                                  cast(DWORD) flags,
                                  &overlapped.overlapped,
                                  null);

            if (result == socketError && !wouldHaveBlocked)
            {
                disconnected_ = true;
                throw defaultAllocator.make!SocketException("Unable to send");
            }
            return result == 0;
        }

        /**
         * Ends a pending asynchronous send.
         *
         * Params:
         *  overlapped = Unique operation identifier.
         *
         * Returns: Number of bytes sent.
         *
         * Throws: $(D_PSYMBOL SocketException) if unable to receive.
         *
         * Postcondition: $(D_INLINECODE result >= 0).
        */
        int endSend(SocketState overlapped) @nogc @trusted
        out (count)
        {
            assert(count >= 0);
        }
        do
        {
            DWORD lpNumber;
            BOOL result = GetOverlappedResult(overlapped.handle,
                                              &overlapped.overlapped,
                                              &lpNumber,
                                              FALSE);
            if (result == FALSE && !wouldHaveBlocked)
            {
                disconnected_ = true;
                throw defaultAllocator.make!SocketException("Unable to receive");
            }
            return lpNumber;
        }
    }

    /**
     * Windows stream socket overlapped I/O.
     */
    class OverlappedStreamSocket : StreamSocket
    {
        // Accept extension function pointer.
        package LPFN_ACCEPTEX acceptExtension;

        /**
         * Create a socket.
         *
         * Params:
         *  af = Address family.
         *
         * Throws: $(D_PSYMBOL SocketException) on errors.
         */
        this(AddressFamily af) @nogc @trusted
        {
            super(af);
            scope (failure)
            {
                this.close();
            }
            blocking = false;

            GUID guidAcceptEx = WSAID_ACCEPTEX;
            DWORD dwBytes;

            auto result = WSAIoctl(handle_,
                                   SIO_GET_EXTENSION_FUNCTION_POINTER,
                                   &guidAcceptEx,
                                   guidAcceptEx.sizeof,
                                   &acceptExtension,
                                   acceptExtension.sizeof,
                                   &dwBytes,
                                   null,
                                   null);
            if (!result == socketError)
            {
                throw make!SocketException(defaultAllocator,
                                           "Unable to retrieve an accept extension function pointer");
            }
        }

        /**
         * Begins an asynchronous operation to accept an incoming connection attempt.
         *
         * Params:
         *  overlapped = Unique operation identifier.
         *
         * Returns: $(D_KEYWORD true) if the operation could be finished synchronously.
         *          $(D_KEYWORD false) otherwise.
         *
         * Throws: $(D_PSYMBOL SocketException) on accept errors.
         */
        bool beginAccept(SocketState overlapped) @nogc @trusted
        {
            auto socket = cast(SocketType) socket(addressFamily, 1, 0);
            if (socket == SocketType.init)
            {
                throw defaultAllocator.make!SocketException("Unable to create socket");
            }
            scope (failure)
            {
                closesocket(socket);
            }
            DWORD dwBytes;
            overlapped.handle = cast(HANDLE) socket;
            overlapped.event = OverlappedSocketEvent.accept;

            const len = (sockaddr_in.sizeof + 16) * 2;
            overlapped.buffer.len = len;
            overlapped.buffer.buf = cast(char*) defaultAllocator.allocate(len).ptr;

            // We don't want to get any data now, but only start to accept the connections
            BOOL result = acceptExtension(handle_,
                                          socket,
                                          overlapped.buffer.buf,
                                          0u,
                                          sockaddr_in.sizeof + 16,
                                          sockaddr_in.sizeof + 16,
                                          &dwBytes,
                                          &overlapped.overlapped);
            if (result == FALSE && !wouldHaveBlocked)
            {
                throw defaultAllocator.make!SocketException("Unable to accept socket connection");
            }
            return result == TRUE;
        }

        /**
         * Asynchronously accepts an incoming connection attempt and creates a
         * new socket to handle remote host communication.
         *
         * Params:
         *  overlapped = Unique operation identifier.
         *
         * Returns: Connected socket.
         *
         * Throws: $(D_PSYMBOL SocketException) if unable to accept.
         */
        OverlappedConnectedSocket endAccept(SocketState overlapped)
        @nogc @trusted
        {
            scope (exit)
            {
                defaultAllocator.dispose(overlapped.buffer.buf[0 .. overlapped.buffer.len]);
            }
            auto socket = make!OverlappedConnectedSocket(defaultAllocator,
                                                         cast(SocketType) overlapped.handle,
                                                         addressFamily);
            scope (failure)
            {
                defaultAllocator.dispose(socket);
            }
            socket.setOption(SocketOptionLevel.SOCKET,
                             cast(SocketOption) SO_UPDATE_ACCEPT_CONTEXT,
                             cast(size_t) handle);
            return socket;
        }
    }
}

/**
 * Socket option that specifies what should happen when the socket that
 * promises reliable delivery still has untransmitted messages when
 * it is closed.
 */
struct Linger
{
    /// If nonzero, $(D_PSYMBOL close) and $(D_PSYMBOL shutdown) block until
    /// the data are transmitted or the timeout period has expired.
    LingerField l_onoff;

    /// Time, in seconds to wait before any buffered data to be sent is
    /// discarded.
    LingerField l_linger;

    /**
     * If $(D_PARAM timeout) is `0`, linger is disabled, otherwise enables the
     * linger and sets the timeout.
     *
     * Params:
     *  timeout = Timeout, in seconds.
     */
    this(const ushort timeout)
    {
        time = timeout;
    }

    ///
    unittest
    {
        {
            auto linger = Linger(5);
            assert(linger.enabled);
            assert(linger.time == 5);
        }
        {
            auto linger = Linger(0);
            assert(!linger.enabled);
        }
        { // Default constructor.
            Linger linger;
            assert(!linger.enabled);
        }
    }

    /**
     * System dependent constructor.
     *
     * Params:
     *  l_onoff  = $(D_PSYMBOL l_onoff) value.
     *  l_linger = $(D_PSYMBOL l_linger) value.
     */
    this(LingerField l_onoff, LingerField l_linger)
    {
        this.l_onoff = l_onoff;
        this.l_linger = l_linger;
    }

    ///
    unittest
    {
        auto linger = Linger(1, 5);
        assert(linger.l_onoff == 1);
        assert(linger.l_linger == 5);
    }

    /**
     * Params:
     *  value = Whether to linger after the socket is closed.
     *
     * See_Also: $(D_PSYMBOL time).
     */
    @property void enabled(const bool value) pure nothrow @safe @nogc
    {
        this.l_onoff = value;
    }

    /**
     * Returns: Whether to linger after the socket is closed.
     */
    @property bool enabled() const pure nothrow @safe @nogc
    {
        return this.l_onoff != 0;
    }

    /**
     * Returns: Timeout period, in seconds, to wait before closing the socket
     *          if the $(D_PSYMBOL Linger) is $(D_PSYMBOL enabled).
     */
    @property ushort time() const pure nothrow @safe @nogc
    {
        return this.l_linger & ushort.max;
    }

    /**
     *  Sets timeout period, to wait before closing the socket if the
     *  $(D_PSYMBOL Linger) is $(D_PSYMBOL enabled), ignored otherwise.
     *
     * Params:
     *  timeout = Timeout period, in seconds.
     */
    @property void time(const ushort timeout) pure nothrow @safe @nogc
    {
        this.l_onoff = timeout > 0;
        this.l_linger = timeout;
    }
}

version (linux)
{
    enum SOCK_NONBLOCK = O_NONBLOCK;
    extern(C) int accept4(int, sockaddr*, socklen_t*, int flags) @nogc nothrow;
}
else version (OSX)
{
    version = MacBSD;
}
else version (iOS)
{
    version = MacBSD;
}
else version (FreeBSD)
{
    version = MacBSD;
}
else version (OpenBSD)
{
    version = MacBSD;
}
else version (DragonFlyBSD)
{
    version = MacBSD;
}

version (MacBSD)
{
    enum ESOCKTNOSUPPORT = 44; // Socket type not suppoted.
}

private immutable
{
    typeof(&getaddrinfo) getaddrinfoPointer;
    typeof(&freeaddrinfo) freeaddrinfoPointer;
}

shared static this()
{
    version (Windows)
    {
        auto ws2Lib = GetModuleHandle("ws2_32.dll");

        getaddrinfoPointer = cast(typeof(getaddrinfoPointer))
            GetProcAddress(ws2Lib, "getaddrinfo");
        freeaddrinfoPointer = cast(typeof(freeaddrinfoPointer))
            GetProcAddress(ws2Lib, "freeaddrinfo");
    }
    else version (Posix)
    {
        getaddrinfoPointer = &getaddrinfo;
        freeaddrinfoPointer = &freeaddrinfo;
    }
}

/**
 * $(D_PSYMBOL AddressFamily) specifies a communication domain; this selects
 * the protocol family which will be used for communication.
 */
enum AddressFamily : int
{
    unspec    = 0,     /// Unspecified.
    local     = 1,     /// Local to host (pipes and file-domain).
    unix      = local, /// POSIX name for PF_LOCAL.
    inet      = 2,     /// IP protocol family.
    ax25      = 3,     /// Amateur Radio AX.25.
    ipx       = 4,     /// Novell Internet Protocol.
    appletalk = 5,     /// Appletalk DDP.
    netrom    = 6,     /// Amateur radio NetROM.
    bridge    = 7,     /// Multiprotocol bridge.
    atmpvc    = 8,     /// ATM PVCs.
    x25       = 9,     /// Reserved for X.25 project.
    inet6     = 10,    /// IP version 6.
}

/**
 * $(D_PSYMBOL SocketException) should be thrown only if one of the socket functions
 * $(D_PSYMBOL socketError) and sets $(D_PSYMBOL errno), because
 * $(D_PSYMBOL SocketException) relies on the $(D_PSYMBOL errno) value.
 */
class SocketException : Exception
{
    const ErrorCode.ErrorNo error = ErrorCode.ErrorNo.success;

    /**
     * Params:
     *  msg  = The message for the exception.
     *  file = The file where the exception occurred.
     *  line = The line number where the exception occurred.
     *  next = The previous exception in the chain of exceptions, if any.
     */
    this(string msg,
         string file = __FILE__,
         size_t line = __LINE__,
         Throwable next = null) @nogc @safe nothrow
    {
        super(msg, file, line, next);

        foreach (member; EnumMembers!(ErrorCode.ErrorNo))
        {
            if (member == lastError)
            {
                error = member;
                return;
            }
        }
        if (lastError == ENOMEM)
        {
            error = ErrorCode.ErrorNo.noBufferSpace;
        }
        else if (lastError == EMFILE)
        {
            error = ErrorCode.ErrorNo.tooManyDescriptors;
        }
        else version (linux)
        {
            if (lastError == ENOSR)
            {
                error = ErrorCode.ErrorNo.networkDown;
            }
        }
        else version (Posix)
        {
            if (lastError == EPROTO)
            {
                error = ErrorCode.ErrorNo.networkDown;
            }
        }
    }
}

/**
 * Class for creating a network communication endpoint using the Berkeley
 * sockets interfaces of different types.
 */
abstract class Socket
{
    version (Posix)
    {
        /**
         * How a socket is shutdown.
         */
        enum Shutdown : int
        {
            receive = SHUT_RD,   /// Socket receives are disallowed
            send    = SHUT_WR,   /// Socket sends are disallowed
            both    = SHUT_RDWR, /// Both receive and send
        }
    }
    else version (Windows)
    {
        /// Property to get or set whether the socket is blocking or nonblocking.
        private bool blocking_ = true;

        /**
         * How a socket is shutdown.
         */
        enum Shutdown : int
        {
            receive = SD_RECEIVE, /// Socket receives are disallowed.
            send    = SD_SEND,    /// Socket sends are disallowed.
            both    = SD_BOTH,    /// Both receive and send.
        }

        // The WinSock timeouts seem to be effectively skewed by a constant
        // offset of about half a second (in milliseconds).
        private enum WINSOCK_TIMEOUT_SKEW = 500;
    }

    /// Socket handle.
    protected SocketType handle_;

    /// Address family.
    protected AddressFamily family;

    private @property void handle(SocketType handle) @nogc
    in
    {
        assert(handle != SocketType.init);
        assert(handle_ == SocketType.init, "Socket handle cannot be changed");
    }
    do
    {
        handle_ = handle;

        // Set the option to disable SIGPIPE on send() if the platform
        // has it (e.g. on OS X).
        static if (is(typeof(SO_NOSIGPIPE)))
        {
            setOption(SocketOptionLevel.SOCKET, cast(SocketOption)SO_NOSIGPIPE, true);
        }
    }

    @property inout(SocketType) handle() inout const pure nothrow @safe @nogc
    {
        return handle_;
    }

    /**
     * Create a socket.
     *
     * Params:
     *  handle = Socket.
     *  af     = Address family.
     */
    this(SocketType handle, AddressFamily af) @nogc
    in
    {
        assert(handle != SocketType.init);
    }
    do
    {
        scope (failure)
        {
            this.close();
        }
        this.handle = handle;
        family = af;
    }

    /**
     * Closes the socket and calls the destructor on itself.
     */
    ~this() nothrow @trusted @nogc
    {
        this.close();
    }

    /**
     * Get a socket option.
     *
     * Params:
     *  level  = Protocol level at that the option exists.
     *  option = Option.
     *  result = Buffer to save the result.
     *
     * Returns: The number of bytes written to $(D_PARAM result).
     *
     * Throws: $(D_PSYMBOL SocketException) on error.
     */
    protected int getOption(SocketOptionLevel level,
                            SocketOption option,
                            void[] result) const @trusted @nogc
    {
        auto length = cast(socklen_t) result.length;
        if (getsockopt(handle_,
                       cast(int) level,
                       cast(int) option,
                       result.ptr,
                       &length) == socketError)
        {
            throw defaultAllocator.make!SocketException("Unable to get socket option");
        }
        return length;
    }

    /// Ditto.
    int getOption(SocketOptionLevel level,
                  SocketOption option,
                  out size_t result) const @trusted @nogc
    {
        return getOption(level, option, (&result)[0 .. 1]);
    }

    /// Ditto.
    int getOption(SocketOptionLevel level,
                  SocketOption option,
                  out Linger result) const @trusted @nogc
    {
        return getOption(level, option, (&result)[0 .. 1]);
    }

    /// Ditto.
    int getOption(SocketOptionLevel level,
                  SocketOption option,
                  out Duration result) const @trusted @nogc
    {
        // WinSock returns the timeout values as a milliseconds DWORD,
        // while Linux and BSD return a timeval struct.
        version (Posix)
        {
            timeval tv;
            auto ret = getOption(level, option, (&tv)[0 .. 1]);
            result = dur!"seconds"(tv.tv_sec) + dur!"usecs"(tv.tv_usec);
        }
        else version (Windows)
        {
            int msecs;
            auto ret = getOption(level, option, (&msecs)[0 .. 1]);
            if (option == SocketOption.RCVTIMEO)
            {
                msecs += WINSOCK_TIMEOUT_SKEW;
            }
            result = dur!"msecs"(msecs);
        }
        return ret;
    }

    /**
     * Set a socket option.
     *
     * Params:
     *  level  = Protocol level at that the option exists.
     *  option = Option.
     *  value  = Option value.
     *
     * Throws: $(D_PSYMBOL SocketException) on error.
     */
    protected void setOption(SocketOptionLevel level,
                             SocketOption option,
                             void[] value) const @trusted @nogc
    {
        if (setsockopt(handle_,
                       cast(int)level,
                       cast(int)option,
                       value.ptr,
                       cast(uint) value.length) == socketError)
        {
            throw defaultAllocator.make!SocketException("Unable to set socket option");
        }
    }

    /// Ditto.
    void setOption(SocketOptionLevel level, SocketOption option, size_t value)
    const @trusted @nogc
    {
        setOption(level, option, (&value)[0 .. 1]);
    }

    /// Ditto.
    void setOption(SocketOptionLevel level, SocketOption option, Linger value)
    const @trusted @nogc
    {
        setOption(level, option, (&value)[0 .. 1]);
    }

    /// Ditto.
    void setOption(SocketOptionLevel level, SocketOption option, Duration value)
    const @trusted @nogc
    {
        version (Posix)
        {
            timeval tv;
            value.split!("seconds", "usecs")(tv.tv_sec, tv.tv_usec);
            setOption(level, option, (&tv)[0 .. 1]);
        }
        else version (Windows)
        {
            auto msecs = cast(int) value.total!"msecs";
            if (msecs > 0 && option == SocketOption.RCVTIMEO)
            {
                msecs = max(1, msecs - WINSOCK_TIMEOUT_SKEW);
            }
            setOption(level, option, msecs);
        }
    }

    /**
     * Returns: Socket's blocking flag.
     */
    @property inout(bool) blocking() inout const nothrow @nogc
    {
        version (Posix)
        {
            return !(fcntl(handle_, F_GETFL, 0) & O_NONBLOCK);
        }
        else version (Windows)
        {
            return this.blocking_;
        }
    }

    /**
     * Params:
     *  yes = Socket's blocking flag.
     */
    @property void blocking(bool yes) @nogc
    {
        version (Posix)
        {
            int fl = fcntl(handle_, F_GETFL, 0);

            if (fl != socketError)
            {
                fl = yes ? fl & ~O_NONBLOCK : fl | O_NONBLOCK;
                fl = fcntl(handle_, F_SETFL, fl);
            }
            if (fl == socketError)
            {
                throw make!SocketException(defaultAllocator,
                                           "Unable to set socket blocking");
            }
        }
        else version (Windows)
        {
            uint num = !yes;
            if (ioctlsocket(handle_, FIONBIO, &num) == socketError)
            {
                throw make!SocketException(defaultAllocator,
                                           "Unable to set socket blocking");
            }
            this.blocking_ = yes;
        }
    }

    /**
     * Returns: The socket's address family.
     */
    @property AddressFamily addressFamily() const @nogc @safe pure nothrow
    {
        return family;
    }

    /**
     * Returns: $(D_KEYWORD true) if this is a valid, alive socket.
     */
    @property bool isAlive() @trusted const nothrow @nogc
    {
        int type;
        socklen_t typesize = cast(socklen_t) type.sizeof;
        return !getsockopt(handle_, SOL_SOCKET, SO_TYPE, cast(char*)&type, &typesize);
    }

    /**
     * Disables sends and/or receives.
     *
     * Params:
     *  how = What to disable.
     *
     * See_Also:
     *  $(D_PSYMBOL Shutdown)
     */
    void shutdown(Shutdown how = Shutdown.both) @nogc @trusted const nothrow
    {
        .shutdown(handle_, cast(int)how);
    }

    /**
     * Immediately drop any connections and release socket resources.
     * Calling $(D_PSYMBOL shutdown) before $(D_PSYMBOL close) is recommended
     * for connection-oriented sockets. The $(D_PSYMBOL Socket) object is no
     * longer usable after $(D_PSYMBOL close).
     */
    void close() nothrow @trusted @nogc
    {
        version(Windows)
        {
            .closesocket(handle_);
        }
        else version(Posix)
        {
            .close(handle_);
        }
        handle_ = SocketType.init;
    }

    /**
     * Listen for an incoming connection. $(D_PSYMBOL bind) must be called before you
     * can $(D_PSYMBOL listen).
     *
     * Params:
     *  backlog = Request of how many pending incoming connections are
     *            queued until $(D_PSYMBOL accept)ed.
     */
    void listen(int backlog) const @trusted @nogc
    {
        if (.listen(handle_, backlog) == socketError)
        {
            throw defaultAllocator.make!SocketException("Unable to listen on socket");
        }
    }

    /**
     * Compare handles.
     *
     * Params:
     *  that = Another handle.
     *
     * Returns: Comparision result.
     */
    int opCmp(size_t that) const pure nothrow @safe @nogc
    {
        return handle_ < that ? -1 : handle_ > that ? 1 : 0;
    }
}

/**
 * Interface with common fileds for stream and connected sockets.
 */
interface ConnectionOrientedSocket
{
    /**
     * Flags may be OR'ed together.
     */
    enum Flag : int
    {
        /// No flags specified.
        none      = 0,
        /// Out-of-band stream data.
        outOfBand = MSG_OOB,
        /// Peek at incoming data without removing it from the queue, only for receiving.
        peek      = MSG_PEEK,
        /// Data should not be subject to routing; this flag may be ignored. Only for sending.
        dontRoute = MSG_DONTROUTE,
    }

    alias Flags = BitFlags!Flag;
}

class StreamSocket : Socket, ConnectionOrientedSocket
{
    /**
     * Create a socket.
     *
     * Params:
     *  af = Address family.
     */
    this(AddressFamily af) @trusted @nogc
    {
        auto handle = cast(SocketType) socket(af, 1, 0);
        if (handle == SocketType.init)
        {
            throw defaultAllocator.make!SocketException("Unable to create socket");
        }
        super(handle, af);
    }

    /**
     * Associate a local address with this socket.
     *
     * Params:
     *  address = Local address.
     *
     * Throws: $(D_PSYMBOL SocketException) if unable to bind.
     */
    void bind(Address address) const @trusted @nogc
    {
        if (.bind(handle_, address.name, address.length) == socketError)
        {
            throw defaultAllocator.make!SocketException("Unable to bind socket");
        }
    }

    /**
     * Accept an incoming connection.
     *
     * The blocking mode is always inherited.
     *
     * Returns: $(D_PSYMBOL Socket) for the accepted connection or
     *          $(D_KEYWORD null) if the call would block on a
     *          non-blocking socket.
     *
     * Throws: $(D_PSYMBOL SocketException) if unable to accept.
     */
    ConnectedSocket accept() @trusted @nogc
    {
        SocketType sock;

        version (linux)
        {
            int flags;
            if (!blocking)
            {
                flags |= SOCK_NONBLOCK;
            }
            sock = cast(SocketType).accept4(handle_, null, null, flags);
        }
        else
        {
            sock = cast(SocketType).accept(handle_, null, null);
        }

        if (sock == SocketType.init)
        {
            if (wouldHaveBlocked())
            {
                return null;
            }
            throw make!SocketException(defaultAllocator,
                                       "Unable to accept socket connection");
        }

        auto newSocket = defaultAllocator.make!ConnectedSocket(sock, addressFamily);

        version (linux)
        { // Blocking mode already set
        }
        else version (Posix)
        {
            if (!blocking)
            {
                try
                {
                    newSocket.blocking = blocking;
                }
                catch (SocketException e)
                {
                    defaultAllocator.dispose(newSocket);
                    throw e;
                }
            }
        }
        else version (Windows)
        { // Inherits blocking mode
            newSocket.blocking_ = blocking;
        }
        return newSocket;
    }
}

/**
 * Socket returned if a connection has been established.
 */
class ConnectedSocket : Socket, ConnectionOrientedSocket
{
    /**
     * $(D_KEYWORD true) if the stream socket peer has performed an orderly
     * shutdown.
     */
    protected bool disconnected_;

    /**
     * Returns: $(D_KEYWORD true) if the stream socket peer has performed an orderly
     *          shutdown.
     */
    @property inout(bool) disconnected() inout const pure nothrow @safe @nogc
    {
        return disconnected_;
    }

    /**
     * Create a socket.
     *
     * Params:
     *  handle = Socket.
     *  af     = Address family.
     */
    this(SocketType handle, AddressFamily af) @nogc
    {
        super(handle, af);
    }

    version (Windows)
    {
        private static int capToMaxBuffer(size_t size) pure nothrow @safe @nogc
        {
            // Windows uses int instead of size_t for length arguments.
            // Luckily, the send/recv functions make no guarantee that
            // all the data is sent, so we use that to send at most
            // int.max bytes.
            return size > size_t (int.max) ? int.max : cast(int) size;
        }
    }
    else
    {
        private static size_t capToMaxBuffer(size_t size) pure nothrow @safe @nogc
        {
            return size;
        }
    }

    /**
     * Receive data on the connection.
     *
     * Params:
     *  buf   = Buffer to save received data.
     *  flags = Flags.
     *
     * Returns: The number of bytes received or 0 if nothing received
     *          because the call would block.
     *
     * Throws: $(D_PSYMBOL SocketException) if unable to receive.
     */
    ptrdiff_t receive(ubyte[] buf, Flags flags = Flag.none) @trusted @nogc
    {
        ptrdiff_t ret;
        if (!buf.length)
        {
            return 0;
        }

        ret = recv(handle_, buf.ptr, capToMaxBuffer(buf.length), cast(int) flags);
        if (ret == 0)
        {
            disconnected_ = true;
        }
        else if (ret == socketError)
        {
            if (wouldHaveBlocked())
            {
                return 0;
            }
            disconnected_ = true;
            throw defaultAllocator.make!SocketException("Unable to receive");
        }
        return ret;
    }

    /**
     * Send data on the connection. If the socket is blocking and there is no
     * buffer space left, $(D_PSYMBOL send) waits, non-blocking socket returns
     * 0 in this case.
     *
     * Params:
     *  buf   = Data to be sent.
     *  flags = Flags.
     *
     * Returns: The number of bytes actually sent.
     *
     * Throws: $(D_PSYMBOL SocketException) if unable to send.
     */
    ptrdiff_t send(const(ubyte)[] buf, Flags flags = Flag.none)
    const @trusted @nogc
    {
        int sendFlags = cast(int) flags;
        ptrdiff_t sent;

        static if (is(typeof(MSG_NOSIGNAL)))
        {
            sendFlags |= MSG_NOSIGNAL;
        }

        sent = .send(handle_, buf.ptr, capToMaxBuffer(buf.length), sendFlags);
        if (sent != socketError)
        {
            return sent;
        }
        else if (wouldHaveBlocked())
        {
            return 0;
        }
        throw defaultAllocator.make!SocketException("Unable to send");
    }
}

/**
 * Socket address representation.
 */
abstract class Address
{
    /**
     * Returns: Pointer to underlying $(D_PSYMBOL sockaddr) structure.
     */
    abstract @property inout(sockaddr)* name() inout pure nothrow @nogc;

    /**
     * Returns: Actual size of underlying $(D_PSYMBOL sockaddr) structure.
     */
    abstract @property inout(socklen_t) length() inout const pure nothrow @nogc;
}

class InternetAddress : Address
{
    version (Windows)
    {
        /// Internal internet address representation.
        protected SOCKADDR_STORAGE storage;
    }
    else version (Posix)
    {
        /// Internal internet address representation.
        protected sockaddr_storage storage;
    }
    const ushort port_;

    enum ushort anyPort = 0;

    this(string host, const ushort port = anyPort) @nogc
    {
        if (getaddrinfoPointer is null || freeaddrinfoPointer is null)
        {
            throw make!SocketException(defaultAllocator,
                                       "Address info lookup is not available on this system");
        }
        addrinfo* ai_res;
        this.port_ = port;

        // Make C-string from host.
        auto node = cast(char[]) allocator.allocate(host.length + 1);
        node[0 .. $ - 1] = host;
        node[$ - 1] = '\0';
        scope (exit)
        {
            allocator.deallocate(node);
        }

        // Convert port to a C-string.
        char[6] service = [0, 0, 0, 0, 0, 0];
        const(char)* servicePointer;
        if (port)
        {
            ushort originalPort = port;
            ushort start;
            for (ushort j = 10, i = 4; i > 0; j *= 10, --i)
            {
                ushort rest = originalPort % 10;
                if (rest != 0)
                {
                    service[i] = cast(char) (rest + '0');
                    start = i;
                }
                originalPort /= 10;
            }
            servicePointer = service[start .. $].ptr;
        }

        auto ret = getaddrinfoPointer(node.ptr, servicePointer, null, &ai_res);
        if (ret)
        {
            throw defaultAllocator.make!SocketException("Address info lookup failed");
        }
        scope (exit)
        {
            freeaddrinfoPointer(ai_res);
        }

        ubyte* dp = cast(ubyte*) &storage, sp = cast(ubyte*) ai_res.ai_addr;
        for (auto i = ai_res.ai_addrlen; i > 0; --i, *dp++, *sp++)
        {
            *dp = *sp;
        }
        if (ai_res.ai_family != AddressFamily.inet && ai_res.ai_family != AddressFamily.inet6)
        {
            throw defaultAllocator.make!SocketException("Wrong address family");
        }
    }

    ///
    unittest
    {
        auto address = defaultAllocator.make!InternetAddress("127.0.0.1");
        assert(address.port == InternetAddress.anyPort);
        assert(address.name !is null);
        assert(address.family == AddressFamily.inet);

        defaultAllocator.dispose(address);
    }

    /**
     * Returns: Pointer to underlying $(D_PSYMBOL sockaddr) structure.
     */
    override @property inout(sockaddr)* name() inout pure nothrow @nogc
    {
        return cast(sockaddr*) &storage;
    }

    /**
     * Returns: Actual size of underlying $(D_PSYMBOL sockaddr) structure.
     */
    override @property inout(socklen_t) length() inout const pure nothrow @nogc
    {
        // FreeBSD wants to know the exact length of the address on bind.
        switch (family)
        {
            case AddressFamily.inet:
                return sockaddr_in.sizeof;
            case AddressFamily.inet6:
                return sockaddr_in6.sizeof;
            default:
                assert(false);
        }
    }

    /**
     * Returns: Family of this address.
     */
    @property inout(AddressFamily) family() inout const pure nothrow @nogc
    {
        return cast(AddressFamily) storage.ss_family;
    }

    @property inout(ushort) port() inout const pure nothrow @nogc
    {
        return port_;
    }

    ///
    unittest
    {
        auto address = defaultAllocator.make!InternetAddress("127.0.0.1",
                                                             cast(ushort) 1234);
        assert(address.port == 1234);
        defaultAllocator.dispose(address);
    }
}

/**
 * Checks if the last error is a serious error or just a special
 * behaviour error of non-blocking sockets (for example an error
 * returned because the socket would block or because the
 * asynchronous operation was successfully started but not finished yet).
 *
 * Returns: $(D_KEYWORD false) if a serious error happened, $(D_KEYWORD true)
 *          otherwise.
 */
bool wouldHaveBlocked() nothrow @trusted @nogc
{
    version (Posix)
    {
        return errno == EAGAIN || errno == EWOULDBLOCK;
    }
    else version (Windows)
    {
        return WSAGetLastError() == ERROR_IO_PENDING
            || WSAGetLastError() == WSAEWOULDBLOCK
            || WSAGetLastError() == ERROR_IO_INCOMPLETE;
    }
}

/**
 * Returns: Platform specific error code.
 */
private @property int lastError() nothrow @safe @nogc
{
    version (Windows)
    {
        return WSAGetLastError();
    }
    else
    {
        return errno;
    }
}
