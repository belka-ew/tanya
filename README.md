# Tanya

[![Build status](https://travis-ci.org/caraus-ecms/tanya.svg?branch=master)](https://travis-ci.org/caraus-ecms/tanya)
[![Build status](https://ci.appveyor.com/api/projects/status/djkmverdfsylc7ti/branch/master?svg=true)](https://ci.appveyor.com/project/belka-ew/tanya/branch/master)
[![codecov](https://codecov.io/gh/caraus-ecms/tanya/branch/master/graph/badge.svg)](https://codecov.io/gh/caraus-ecms/tanya)
[![Dub version](https://img.shields.io/dub/v/tanya.svg)](https://code.dlang.org/packages/tanya)
[![Dub downloads](https://img.shields.io/dub/dt/tanya.svg)](https://code.dlang.org/packages/tanya)
[![License](https://img.shields.io/badge/license-MPL_2.0-blue.svg)](https://raw.githubusercontent.com/caraus-ecms/tanya/master/LICENSE)

Tanya is a general purpose library for D programming language.

Its aim is to simplify the manual memory management in D and to provide a
guarantee with @nogc attribute that there are no hidden allocations on the
Garbage Collector heap. Everything in the library is usable in @nogc code.
Tanya extends Phobos functionality and provides alternative implementations for
data structures and utilities that depend on the Garbage Collector in Phobos.

* [Bug tracker](https://issues.caraus.io/projects/tanya/issues)
* [Documentation](https://docs.caraus.io/tanya)

## Overview

Tanya consists of the following packages:

* `async`: Event loop (epoll, kqueue and IOCP).
* `container`: Queue, Array, Singly and doubly linked lists, Buffers, UTF-8
string, Hash set.
* `format`: Formatting and conversion functions.
* `math`: Arbitrary precision integer and a set of functions.
* `memory`: Tools for manual memory management (allocators, smart pointers).
* `network`: URL-Parsing, sockets, utilities.
* `os`: Platform-independent interfaces to operating system functionality.

### Supported compilers

| dmd     |
|:-------:|
| 2.074.1 |
| 2.073.2 |
| 2.072.2 |
| 2.071.2 |

### Current status

Following modules are under development:

| Feature  | Branch    | Build status                                                                                                                                                                                                                                                                                  |
|----------|:---------:|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| BitArray | bitvector | [![bitvector](https://travis-ci.org/caraus-ecms/tanya.svg?branch=bitvector)](https://travis-ci.org/caraus-ecms/tanya) [![bitvector](https://ci.appveyor.com/api/projects/status/djkmverdfsylc7ti/branch/bitvector?svg=true)](https://ci.appveyor.com/project/belka-ew/tanya/branch/bitvector) |
| TLS      | crypto    | [![crypto](https://travis-ci.org/caraus-ecms/tanya.svg?branch=crypto)](https://travis-ci.org/caraus-ecms/tanya) [![crypto](https://ci.appveyor.com/api/projects/status/djkmverdfsylc7ti/branch/crypto?svg=true)](https://ci.appveyor.com/project/belka-ew/tanya/branch/crypto)                |
| File IO  | io        | [![io](https://travis-ci.org/caraus-ecms/tanya.svg?branch=io)](https://travis-ci.org/caraus-ecms/tanya) [![io](https://ci.appveyor.com/api/projects/status/djkmverdfsylc7ti/branch/io?svg=true)](https://ci.appveyor.com/project/belka-ew/tanya/branch/io)                                    |

### Further characteristics

* Tanya is a native D library without any external dependencies.

* Tanya is cross-platform. The development happens on a 64-bit Linux, but it
is being tested on Windows and FreeBSD as well.

* The library isn't thread-safe yet.

## Release management

3-week release cycle.

Deprecated features are removed after one release (in approximately 6 weeks after deprecating).
