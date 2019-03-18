/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * This module provides a portable way of using operating system error codes.
 *
 * Copyright: Eugene Wissner 2017-2019.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/os/tanya/os/error.d,
 *                 tanya/os/error.d)
 */
module tanya.os.error;

import tanya.meta.trait;

// Socket API error.
private template SAError(int posix, int wsa = posix)
{
    version (Windows)
    {
        enum SAError = 10000 + wsa;
    }
    else
    {
        alias SAError = posix;
    }
}

// Error for Windows and Posix separately.
private template NativeError(int posix, int win)
{
    version (Windows)
    {
        alias NativeError = win;
    }
    else
    {
        alias NativeError = posix;
    }
}

version (Windows)
{
    private enum eProtocolError = -71;
}
else version (OpenBSD)
{
    private enum eProtocolError = -71;
}
else
{
    private enum eProtocolError = 71;
}

/**
 * System error code.
 */
struct ErrorCode
{
    /**
     * Error code numbers.
     */
    enum ErrorNo : int
    {
        /// The operation completed successfully.
        success                   = 0,

        /// Operation not permitted.
        noPermission              = NativeError!(1, 5),

        /// Interrupted system call.
        interrupted               = SAError!4,

        /// Bad file descriptor.
        badDescriptor             = SAError!9,

        /// An operation on a non-blocking socket would block.
        wouldBlock                = SAError!(11, 35),

        /// Out of memory.
        noMemory                  = NativeError!(12, 14),

        /// Access denied.
        accessDenied              = SAError!13,

        /// An invalid pointer address detected.
        fault                     = SAError!14,

        /// No such device.
        noSuchDevice              = NativeError!(19, 20),

        /// An invalid argument was supplied.
        invalidArgument           = SAError!22,

        /// The limit on the number of open file descriptors.
        tooManyDescriptors        = NativeError!(23, 331),

        /// The limit on the number of open file descriptors.
        noDescriptors             = SAError!24,

        /// Broken pipe.
        brokenPipe                = NativeError!(32, 109),

        /// The name was too long.
        nameTooLong               = SAError!(36, 63),

        /// A socket operation was attempted on a non-socket.
        notSocket                 = SAError!(88, 38),

        /// Protocol error.
        protocolError             = eProtocolError,

        /// Message too long.
        messageTooLong            = SAError!(90, 40),

        /// Wrong protocol type for socket.
        wrongProtocolType         = SAError!(91, 41),

        /// Protocol not available.
        noProtocolOption          = SAError!(92, 42),

        /// The protocol is not implemented or has not been configured.
        protocolNotSupported      = SAError!(93, 43),

        /// The support for the specified socket type does not exist in this
        /// address family.
        socketNotSupported        = SAError!(94, 44),

        /// The address family is no supported by the protocol family.
        operationNotSupported     = SAError!(95, 45),

        /// Address family specified is not supported.
        addressFamilyNotSupported = SAError!(97, 47),

        /// Address already in use.
        addressInUse              = SAError!(98, 48),

        /// The network is not available.
        networkDown               = SAError!(100, 50),

        /// No route to host.
        networkUnreachable        = SAError!(101, 51),

        /// Network dropped connection because of reset.
        networkReset              = SAError!(102, 52),

        /// The connection has been aborted.
        connectionAborted         = SAError!(103, 53),

        /// Connection reset by peer.
        connectionReset           = SAError!(104, 54),

        /// No free buffer space is available for a socket operation.
        noBufferSpace             = SAError!(105, 55),

        /// Transport endpoint is already connected.
        alreadyConnected          = SAError!(106, 56),

        /// Transport endpoint is not connected.
        notConnected              = SAError!(107, 57),

        /// Cannot send after transport endpoint shutdown.
        shutdown                  = SAError!(108, 58),

        /// The connection attempt timed out, or the connected host has failed
        /// to respond.
        timedOut                  = SAError!(110, 60),

        /// Connection refused.
        connectionRefused         = SAError!(111, 61),

        /// Host is down.
        hostDown                  = SAError!(112, 64),

        /// No route to host.
        hostUnreachable           = SAError!(113, 65),

        /// Operation already in progress.
        alreadyStarted            = SAError!(114, 37),

        /// Operation now in progress.
        inProgress                = SAError!(115, 36),

        /// Operation cancelled.
        cancelled                 = SAError!(125, 103),
    }

    /**
     * Error descriptions.
     */
    private enum ErrorStr : string
    {
        success                   = "The operation completed successfully",
        noPermission              = "Operation not permitted",
        interrupted               = "Interrupted system call",
        badDescriptor             = "Bad file descriptor",
        wouldBlock                = "An operation on a non-blocking socket would block",
        noMemory                  = "Out of memory",
        accessDenied              = "Access denied",
        fault                     = "An invalid pointer address detected",
        noSuchDevice              = "No such device",
        invalidArgument           = "An invalid argument was supplied",
        tooManyDescriptors        = "The limit on the number of open file descriptors",
        noDescriptors             = "The limit on the number of open file descriptors",
        brokenPipe                = "Broken pipe",
        nameTooLong               = "The name was too long",
        notSocket                 = "A socket operation was attempted on a non-socket",
        protocolError             = "Protocol error",
        messageTooLong            = "Message too long",
        wrongProtocolType         = "Wrong protocol type for socket",
        noProtocolOption          = "Protocol not available",
        protocolNotSupported      = "The protocol is not implemented or has not been configured",
        socketNotSupported        = "Socket type not supported",
        operationNotSupported     = "The address family is no supported by the protocol family",
        addressFamilyNotSupported = "Address family specified is not supported",
        addressInUse              = "Address already in use",
        networkDown               = "The network is not available",
        networkUnreachable        = "No route to host",
        networkReset              = "Network dropped connection because of reset",
        connectionAborted         = "The connection has been aborted",
        connectionReset           = "Connection reset by peer",
        noBufferSpace             = "No free buffer space is available for a socket operation",
        alreadyConnected          = "Transport endpoint is already connected",
        notConnected              = "Transport endpoint is not connected",
        shutdown                  = "Cannot send after transport endpoint shutdown",
        timedOut                  = "Operation timed out",
        connectionRefused         = "Connection refused",
        hostDown                  = "Host is down",
        hostUnreachable           = "No route to host",
        alreadyStarted            = "Operation already in progress",
        inProgress                = "Operation now in progress",
        cancelled                 = "Operation cancelled",
    }

    /**
     * Constructor.
     *
     * Params:
     *  value = Numeric error code.
     */
    this(const ErrorNo value) @nogc nothrow pure @safe
    {
        this.value_ = value;
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        ErrorCode ec;
        assert(ec == ErrorCode.success);

        ec = ErrorCode.fault;
        assert(ec == ErrorCode.fault);
    }

    /**
     * Resets this $(D_PSYMBOL ErrorCode) to default
     * ($(D_PSYMBOL ErrorCode.success)).
     */
    void reset() @nogc nothrow pure @safe
    {
        this.value_ = ErrorNo.success;
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        auto ec = ErrorCode(ErrorCode.fault);
        assert(ec == ErrorCode.fault);

        ec.reset();
        assert(ec == ErrorCode.success);
    }

    /**
     * Returns: Numeric error code.
     */
    ErrorNo opCast(T : ErrorNo)() const
    {
        return this.value_;
    }

    /// ditto
    ErrorNo opCast(T : int)() const
    {
        return this.value_;
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        ErrorCode ec = ErrorCode.fault;
        auto errorNo = cast(ErrorCode.ErrorNo) ec;

        assert(errorNo == ErrorCode.fault);
        static assert(is(typeof(cast(int) ec)));
    }

    /**
     * Assigns another error code or error code number.
     *
     * Params:
     *  that = Numeric error code.
     *
     * Returns: $(D_KEYWORD this).
     */
    ref ErrorCode opAssign(const ErrorNo that) @nogc nothrow pure @safe
    {
        this.value_ = that;
        return this;
    }

    /// ditto
    ref ErrorCode opAssign(const ErrorCode that) @nogc nothrow pure @safe
    {
        this.value_ = that.value_;
        return this;
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        ErrorCode ec;
        assert(ec == ErrorCode.success);

        ec = ErrorCode.fault;
        assert(ec == ErrorCode.fault);
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        auto ec1 = ErrorCode(ErrorCode.fault);
        ErrorCode ec2;
        assert(ec2 == ErrorCode.success);

        ec2 = ec1;
        assert(ec1 == ec2);
    }

    /**
     * Equality with another error code or error code number.
     *
     * Params:
     *  that = Numeric error code.
     *
     * Returns: Whether $(D_KEYWORD this) and $(D_PARAM that) are equal.
     */
    bool opEquals(const ErrorNo that) const @nogc nothrow pure @safe
    {
        return this.value_ == that;
    }

    /// ditto
    bool opEquals(const ErrorCode that) const @nogc nothrow pure @safe
    {
        return this.value_ == that.value_;
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        ErrorCode ec1 = ErrorCode.fault;
        ErrorCode ec2 = ErrorCode.accessDenied;

        assert(ec1 != ec2);
        assert(ec1 != ErrorCode.accessDenied);
        assert(ErrorCode.fault != ec2);
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        ErrorCode ec1 = ErrorCode.fault;
        ErrorCode ec2 = ErrorCode.fault;

        assert(ec1 == ec2);
        assert(ec1 == ErrorCode.fault);
        assert(ErrorCode.fault == ec2);
    }

    /**
     * Returns string describing the error number. If a description for a
     * specific error number is not available, returns $(D_KEYWORD null).
     *
     * Returns: String describing the error number.
     */
    string toString() const @nogc nothrow pure @safe
    {
        foreach (e; __traits(allMembers, ErrorNo))
        {
            if (__traits(getMember, ErrorNo, e) == this.value_)
            {
                return __traits(getMember, ErrorStr, e);
            }
        }
        return null;
    }

    ///
    @nogc nothrow pure @safe unittest
    {
        ErrorCode ec = ErrorCode.fault;
        assert(ec.toString() == "An invalid pointer address detected");
    }

    private ErrorNo value_ = ErrorNo.success;

    alias ErrorNo this;
}
