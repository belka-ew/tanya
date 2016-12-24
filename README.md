# Tanya

[![Build Status](https://travis-ci.org/caraus-ecms/tanya.svg?branch=master)](https://travis-ci.org/caraus-ecms/tanya)
[![Dub Version](https://img.shields.io/dub/v/tanya.svg)](https://code.dlang.org/packages/tanya)
[![License](https://img.shields.io/badge/license-MPL_2.0-blue.svg)](https://raw.githubusercontent.com/caraus-ecms/tanya/master/LICENSE)

Tanya is a general purpose library for D programming language that doesn't
rely on the Garbage Collector.

Its aim is to simplify the manual memory management in D and to provide a
guarantee with @nogc attribute that there are no hidden allocations on the
Garbage Collector heap. Everything in the library is usable in @nogc code.
Tanya extends Phobos functionality and provides alternative implementations for
data structures and utilities that depend on the Garbage Collector in Phobos.

## Overview

Tanya consists of the following packages:

* `async`: Event loop.
* `container`: Queue, Vector, Singly linked list.
* `crypto`: Work in progress TLS implementation.
* `math`: Multiple precision integer and a set of functions.
* `memory`: Tools for manual memory management (allocator, reference counting, helper functions).
* `network`: URL-Parsing, sockets.

### Current status

The library is currently under development, but some parts of it can already be
used.

Containers were newly reworked and the API won't change significantly, but will
be only extended. The same is true for the `memory` package.

`network` and `async` packages should be reviewed in the future and the API may
change.

`math` package contains an arbitrary precision integer implementation that has
a stable API (that mostly consists of operator overloads), but still needs
testing and work on its performance.

I'm currently mostly working on `crypto` that is not a complete cryptographic
suite, but contains (will contain) algorithm implementations required by TLS.

### Other properties

* Tanya is a native D library (only D and Assembler are tolerated).

* It is important for me to document the code and attach at least a few unit
tests where possible. So the documentation and usage examples can be found in
the source code.

* Tanya is mostly tested on a 64-bit Linux and some features are
platform-dependant, but not because it is a Linux-only library. Therefore any
help to bring better support for Windows and BSD systems would be accepted.

* The library isn't thread-safe. Thread-safity should be added later.

* I'm working with the latest dmd version, but will be looking to support other
D compilers and keep compatibility with the elder dmd versions in the future.

## Contributing

Since I'm mostly busy writing new code and implementing new features I would
appreciate, if anyone uses the library. It would help me to improve the
codebase and fix issues.

Feel free to contact me if you have any questions.
