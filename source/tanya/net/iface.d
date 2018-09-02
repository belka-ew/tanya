/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Network interfaces.
 *
 * Copyright: Eugene Wissner 2018.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/net/iface.d,
 *                 tanya/net/iface.d)
 */
module tanya.net.iface;

import tanya.algorithm.comparison;
import tanya.algorithm.mutation;
import tanya.container.string;
import tanya.meta.trait;
import tanya.meta.transform;
import tanya.range;

version (TanyaNative)
{
    import mir.linux._asm.unistd;
    import tanya.sys.linux.syscall;
    import tanya.sys.posix.ioctl;
    import tanya.sys.posix.net.if_;
    import tanya.sys.posix.socket;
}
else version (Windows)
{
    import tanya.sys.windows.ifdef;
    import tanya.sys.windows.iphlpapi;
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
    version (TanyaNative)
    {
        if (name.length >= IF_NAMESIZE)
        {
            return 0;
        }
        ifreq ifreq_ = void;

        copy(name, ifreq_.ifr_name[]);
        ifreq_.ifr_name[name.length] = '\0';

        auto socket = syscall(AF_INET,
                              SOCK_DGRAM | SOCK_CLOEXEC,
                              0,
                              NR_socket);
        if (socket <= 0)
        {
            return 0;
        }
        scope (exit)
        {
            syscall(socket, NR_close);
        }
        if (syscall(socket,
                    SIOCGIFINDEX,
                    cast(ptrdiff_t) &ifreq_,
                    NR_ioctl) == 0)
        {
            return ifreq_.ifr_ifindex;
        }
        return 0;
    }
    else version (Windows)
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

    version (TanyaNative)
    {
        ifreq ifreq_ = void;
        ifreq_.ifr_ifindex = index;

        auto socket = syscall(AF_INET,
                              SOCK_DGRAM | SOCK_CLOEXEC,
                              0,
                              NR_socket);
        if (socket <= 0)
        {
            return String();
        }
        scope (exit)
        {
            syscall(socket, NR_close);
        }
        if (syscall(socket,
                    SIOCGIFNAME,
                    cast(ptrdiff_t) &ifreq_,
                    NR_ioctl) == 0)
        {
            return String(findNullTerminated(ifreq_.ifr_name));
        }
        return String();
    }
    else version (Windows)
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

@nogc nothrow @safe unittest
{
    version (linux)
    {
        assert(equal(indexToName(1)[], "lo"));
    }
    else version (Windows)
    {
        assert(equal(indexToName(1)[], "loopback_0"));
    }
    else
    {
        assert(equal(indexToName(1)[], "lo0"));
    }
    assert(indexToName(uint.max).empty);
}
