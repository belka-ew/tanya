/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Network interfaces.
 *
 * Copyright: Eugene Wissner 2018-2020.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/net/iface.d,
 *                 tanya/net/iface.d)
 */
module tanya.net.iface;

import tanya.algorithm.mutation;
import tanya.container.string;
import tanya.meta.trait;
import tanya.meta.transform;
import tanya.range;

version (Windows)
{
    private union NET_LUID_LH { ulong Value, Info; }
    private alias NET_LUID = NET_LUID_LH;
    private alias NET_IFINDEX = uint;
    private enum IF_MAX_STRING_SIZE = 256;
    extern(Windows) @nogc nothrow private @system
    {
        uint ConvertInterfaceNameToLuidA(const(char)* InterfaceName,
            NET_LUID* InterfaceLuid);
        uint ConvertInterfaceLuidToIndex(const(NET_LUID)* InterfaceLuid,
            NET_IFINDEX* InterfaceIndex);
        uint ConvertInterfaceIndexToLuid(NET_IFINDEX InterfaceIndex,
            NET_LUID* InterfaceLuid);
        uint ConvertInterfaceLuidToNameA(const(NET_LUID)* InterfaceLuid,
            char* InterfaceName,
            size_t Length);
    }
}
else version (Posix)
{
    import core.sys.posix.net.if_;
}

/**
 * Converts the name of a network interface to its index.
 *
 * If an interface with the name $(D_PARAM name) cannot be found or another
 * error occurres, returns 0.
 *
 * Params:
 *  name = Interface name.
 *
 * Returns: Returns interface index or 0.
 */
uint nameToIndex(R)(R name) @trusted
if (isInputRange!R && is(Unqual!(ElementType!R) == char) && hasLength!R)
{
    version (Windows)
    {
        if (name.length > IF_MAX_STRING_SIZE)
        {
            return 0;
        }
        char[IF_MAX_STRING_SIZE + 1] buffer;
        NET_LUID luid;

        copy(name, buffer[]);
        buffer[name.length] = '\0';

        if (ConvertInterfaceNameToLuidA(buffer.ptr, &luid) != 0)
        {
            return 0;
        }
        NET_IFINDEX index;
        if (ConvertInterfaceLuidToIndex(&luid, &index) == 0)
        {
            return index;
        }
        return 0;
    }
    else version (Posix)
    {
        if (name.length >= IF_NAMESIZE)
        {
            return 0;
        }
        char[IF_NAMESIZE] buffer;

        copy(name, buffer[]);
        buffer[name.length] = '\0';

        return if_nametoindex(buffer.ptr);
    }
}

///
@nogc nothrow @safe unittest
{
    version (linux)
    {
        assert(nameToIndex("lo") == 1);
    }
    else version (Windows)
    {
        assert(nameToIndex("loopback_0") == 1);
    }
    else
    {
        assert(nameToIndex("lo0") == 1);
    }
    assert(nameToIndex("ecafretni") == 0);
}

/**
 * Converts the index of a network interface to its name.
 *
 * If an interface with the $(D_PARAM index) cannot be found or another
 * error occurres, returns an empty $(D_PSYMBOL String).
 *
 * Params:
 *  index = Interface index.
 *
 * Returns: Returns interface name or an empty $(D_PSYMBOL String).
 */
String indexToName(uint index) @nogc nothrow @trusted
{
    import tanya.memory.op : findNullTerminated;

    version (Windows)
    {
        NET_LUID luid;
        if (ConvertInterfaceIndexToLuid(index, &luid) != 0)
        {
            return String();
        }

        char[IF_MAX_STRING_SIZE + 1] buffer;
        if (ConvertInterfaceLuidToNameA(&luid,
                                        buffer.ptr,
                                        IF_MAX_STRING_SIZE + 1) != 0)
        {
            return String();
        }
        return String(findNullTerminated(buffer));
    }
    else version (Posix)
    {
        char[IF_NAMESIZE] buffer;
        if (if_indextoname(index, buffer.ptr) is null)
        {
            return String();
        }
        return String(findNullTerminated(buffer));
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
