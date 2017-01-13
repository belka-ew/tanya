# Tanya

[![Build Status](https://travis-ci.org/caraus-ecms/tanya.svg?branch=master)](https://travis-ci.org/caraus-ecms/tanya)
[![Dub version](https://img.shields.io/dub/v/tanya.svg)](https://code.dlang.org/packages/tanya)
[![Dub downloads](https://img.shields.io/dub/dt/tanya.svg)](https://code.dlang.org/packages/tanya)
[![License](https://img.shields.io/badge/license-MPL_2.0-blue.svg)](https://raw.githubusercontent.com/caraus-ecms/tanya/master/LICENSE)

Tanya is a general purpose library for D programming language.

Its aim is to simplify the manual memory management in D and to provide a
guarantee with @nogc attribute that there are no hidden allocations on the
Garbage Collector heap. Everything in the library is usable in @nogc code.
Tanya extends Phobos functionality and provides alternative implementations for
data structures and utilities that depend on the Garbage Collector in Phobos.

## Overview

Tanya consists of the following packages:

* `async`: Event loop (epoll, kqueue and IOCP).
* `container`: Queue, Vector, Singly linked list, buffers.
* `crypto`: Work in progress TLS implementation.
* `math`: Multiple precision integer and a set of functions.
* `memory`: Tools for manual memory management (allocator, reference counting,
helper functions).
* `network`: URL-Parsing, sockets.

### Supported compilers

* dmd 2.072.2
* dmd 2.071.2

### Current status

The library is currently under development, but some parts of it can already be
used.

`network` and `async` exist for quite some time and are better tested than
other components.

`container`s were newly reworked and the API won't change significantly, but
will be only extended. The same is true for the `memory` package.

`math` package contains an arbitrary precision integer implementation that has
a stable API (that mostly consists of operator overloads), but still needs
testing and work on its performance.

I'm currently mostly working on `crypto` that is not a complete cryptographic
suite, but contains (will contain) algorithm implementations required by TLS.

### Further characteristics

* Tanya is a native D library.

* Documentation and usage examples can be found in the source code.
Online documentation will be published soon.

* Tanya is cross-platform. The development happens on a 64-bit Linux, but it
is being tested on Windows and FreeBSD as well.

* The library isn't thread-safe. Thread-safity should be added later.

## Contributing

Since I'm mostly busy writing new code and implementing new features I would
appreciate, if anyone uses the library. It would help me to improve the
codebase and fix issues.

Feel free to contact me if you have any questions.
