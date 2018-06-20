/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

/**
 * Definitions from winsock2.h, ws2def.h and MSWSock.h.
 *
 * Copyright: Eugene Wissner 2017-2018.
 * License: $(LINK2 https://www.mozilla.org/en-US/MPL/2.0/,
 *                  Mozilla Public License, v. 2.0).
 * Authors: $(LINK2 mailto:info@caraus.de, Eugene Wissner)
 * Source: $(LINK2 https://github.com/caraus-ecms/tanya/blob/master/source/tanya/sys/windows/winsock2.d,
 *                 tanya/sys/windows/winsock2.d)
 */
module tanya.sys.windows.winsock2;

version (Windows):

public import tanya.sys.windows.def;
public import tanya.sys.windows.winbase;

alias SOCKET = size_t;
enum SOCKET INVALID_SOCKET = ~0;
enum SOCKET_ERROR = -1;

enum
{
    IOC_UNIX     = 0x00000000,
    IOC_WS2      = 0x08000000,
    IOC_PROTOCOL = 0x10000000,
    IOC_VOID     = 0x20000000,         // No parameters.
    IOC_OUT      = 0x40000000,         // Copy parameters back.
    IOC_IN       = 0x80000000,         // Copy parameters into.
    IOC_VENDOR   = 0x18000000,
    IOC_WSK      = (IOC_WS2 | 0x07000000), // _WIN32_WINNT >= 0x0600.
    IOC_INOUT    = (IOC_IN | IOC_OUT), // Copy parameter into and get back.
}

template _WSAIO(int x, int y)
{
    enum _WSAIO = IOC_VOID | x | y;
}
template _WSAIOR(int x, int y)
{
    enum _WSAIOR = IOC_OUT | x | y;
}
template _WSAIOW(int x, int y)
{
    enum _WSAIOW = IOC_IN | x | y;
}
template _WSAIORW(int x, int y)
{
    enum _WSAIORW = IOC_INOUT | x | y;
}

alias SIO_ASSOCIATE_HANDLE               = _WSAIOW!(IOC_WS2, 1);
alias SIO_ENABLE_CIRCULAR_QUEUEING       = _WSAIO!(IOC_WS2, 2);
alias SIO_FIND_ROUTE                     = _WSAIOR!(IOC_WS2, 3);
alias SIO_FLUSH                          = _WSAIO!(IOC_WS2, 4);
alias SIO_GET_BROADCAST_ADDRESS          = _WSAIOR!(IOC_WS2, 5);
alias SIO_GET_EXTENSION_FUNCTION_POINTER = _WSAIORW!(IOC_WS2, 6);
alias SIO_GET_QOS                        = _WSAIORW!(IOC_WS2, 7);
alias SIO_GET_GROUP_QOS                  = _WSAIORW!(IOC_WS2, 8);
alias SIO_MULTIPOINT_LOOPBACK            = _WSAIOW!(IOC_WS2, 9);
alias SIO_MULTICAST_SCOPE                = _WSAIOW!(IOC_WS2, 10);
alias SIO_SET_QOS                        = _WSAIOW!(IOC_WS2, 11);
alias SIO_SET_GROUP_QOS                  = _WSAIOW!(IOC_WS2, 12);
alias SIO_TRANSLATE_HANDLE               = _WSAIORW!(IOC_WS2, 13);
alias SIO_ROUTING_INTERFACE_QUERY        = _WSAIORW!(IOC_WS2, 20);
alias SIO_ROUTING_INTERFACE_CHANGE       = _WSAIOW!(IOC_WS2, 21);
alias SIO_ADDRESS_LIST_QUERY             = _WSAIOR!(IOC_WS2, 22);
alias SIO_ADDRESS_LIST_CHANGE            = _WSAIO!(IOC_WS2, 23);
alias SIO_QUERY_TARGET_PNP_HANDLE        = _WSAIOR!(IOC_WS2, 24);
alias SIO_NSP_NOTIFY_CHANGE              = _WSAIOW!(IOC_WS2, 25);

alias GROUP = uint;

enum
{
    WSA_FLAG_OVERLAPPED = 0x01,
    WSA_FLAG_MULTIPOINT_C_ROOT = 0x02,
    WSA_FLAG_MULTIPOINT_C_LEAF = 0x04,
    WSA_FLAG_MULTIPOINT_D_ROOT = 0x08,
    WSA_FLAG_MULTIPOINT_D_LEAF = 0x10,
    WSA_FLAG_ACCESS_SYSTEM_SECURITY = 0x40,
    WSA_FLAG_NO_HANDLE_INHERIT = 0x80,
    WSA_FLAG_REGISTERED_IO = 0x100,
}

enum MAX_PROTOCOL_CHAIN = 7;
enum BASE_PROTOCOL = 1;
enum LAYERED_PROTOCOL = 0;
enum WSAPROTOCOL_LEN = 255;

struct WSAPROTOCOLCHAIN
{
    int ChainLen;
    DWORD[MAX_PROTOCOL_CHAIN] ChainEntries;
}

struct WSABUF
{
    ULONG len;
    CHAR* buf;
}

struct WSAPROTOCOL_INFO
{
    DWORD                      dwServiceFlags1;
    DWORD                      dwServiceFlags2;
    DWORD                      dwServiceFlags3;
    DWORD                      dwServiceFlags4;
    DWORD                      dwProviderFlags;
    GUID                       ProviderId;
    DWORD                      dwCatalogEntryId;
    WSAPROTOCOLCHAIN           ProtocolChain;
    int                        iVersion;
    int                        iAddressFamily;
    int                        iMaxSockAddr;
    int                        iMinSockAddr;
    int                        iSocketType;
    int                        iProtocol;
    int                        iProtocolMaxOffset;
    int                        iNetworkByteOrder;
    int                        iSecurityScheme;
    DWORD                      dwMessageSize;
    DWORD                      dwProviderReserved;
    TCHAR[WSAPROTOCOL_LEN + 1] szProtocol;
}

const GUID WSAID_GETACCEPTEXSOCKADDRS = {
    0xb5367df2, 0xcbac, 0x11cf,
    [0x95, 0xca, 0x00, 0x80, 0x5f, 0x48, 0xa1, 0x92],
};

const GUID WSAID_ACCEPTEX = {
    0xb5367df1, 0xcbac, 0x11cf,
    [0x95, 0xca, 0x00, 0x80, 0x5f, 0x48, 0xa1, 0x92],
};

alias LPWSAOVERLAPPED_COMPLETION_ROUTINE = void function(DWORD dwError,
                                                         DWORD cbTransferred,
                                                         OVERLAPPED* lpOverlapped,
                                                         DWORD dwFlags) nothrow @nogc;

extern(Windows)
SOCKET WSASocket(int af,
                 int type,
                 int protocol,
                 WSAPROTOCOL_INFO* lpProtocolInfo,
                 GROUP g,
                 DWORD dwFlags) nothrow @system @nogc;

extern(Windows)
int WSARecv(SOCKET s,
            WSABUF* lpBuffers,
            DWORD dwBufferCount,
            DWORD* lpNumberOfBytesRecvd,
            DWORD* lpFlags,
            OVERLAPPED* lpOverlapped,
            LPWSAOVERLAPPED_COMPLETION_ROUTINE lpCompletionRoutine)
nothrow @system @nogc;

extern(Windows)
int WSASend(SOCKET s,
            WSABUF* lpBuffers,
            DWORD dwBufferCount,
            DWORD* lpNumberOfBytesRecvd,
            DWORD lpFlags,
            OVERLAPPED* lpOverlapped,
            LPWSAOVERLAPPED_COMPLETION_ROUTINE lpCompletionRoutine)
nothrow @system @nogc;

extern(Windows)
int WSAIoctl(SOCKET s,
             uint dwIoControlCode,
             void* lpvInBuffer,
             uint cbInBuffer,
             void* lpvOutBuffer,
             uint cbOutBuffer,
             uint* lpcbBytesReturned,
             OVERLAPPED* lpOverlapped,
             LPWSAOVERLAPPED_COMPLETION_ROUTINE lpCompletionRoutine)             
nothrow @system @nogc;

alias ADDRESS_FAMILY = USHORT;

struct SOCKADDR
{
    ADDRESS_FAMILY sa_family;           // Address family.
    CHAR[14] sa_data;                   // Up to 14 bytes of direct address.
}

alias LPFN_GETACCEPTEXSOCKADDRS = void function(void*,
                                                DWORD,
                                                DWORD,
                                                DWORD,
                                                SOCKADDR**,
                                                INT*,
                                                SOCKADDR**,
                                                INT*) nothrow @nogc;

alias LPFN_ACCEPTEX = extern(Windows) BOOL function(SOCKET,
                                                    SOCKET,
                                                    void*,
                                                    DWORD,
                                                    DWORD,
                                                    DWORD,
                                                    DWORD*,
                                                    OVERLAPPED*) @nogc nothrow;

enum
{
    SO_MAXDG = 0x7009,
    SO_MAXPATHDG = 0x700A,
    SO_UPDATE_ACCEPT_CONTEXT = 0x700B,
    SO_CONNECT_TIME = 0x700C,
    SO_UPDATE_CONNECT_CONTEXT = 0x7010,
}
