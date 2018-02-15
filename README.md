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
Tanya provides data structures and utilities to facilitate painless systems
programming in D.

* [API Documentation](https://docs.caraus.io/tanya)
* [Contribution guidelines](CONTRIBUTING.md)


## Overview

Tanya consists of the following packages and (top-level) modules:

* `algorithm`: Collection of generic algorithms.
* `async`: Event loop (epoll, kqueue and IOCP).
* `container`: Queue, Array, Singly and doubly linked lists, Buffers, UTF-8
string, Hash set.
* `conv`: This module provides functions for converting between different
types.
* `encoding`: This package provides tools to work with text encodings.
* `exception`: Common exceptions and errors.
* `format`: Formatting and conversion functions.
* `math`: Arbitrary precision integer and a set of functions.
* `memory`: Tools for manual memory management (allocators, smart pointers).
* `meta`: Template metaprogramming. This package contains utilities to acquire
type information at compile-time, to transform from one type to another. It has
also different algorithms for iterating, searching and modifying template
arguments.
* `net`: URL-Parsing, network programming.
* `network`: Socket implementation. `network` is currently under rework.
After finishing the new socket implementation will land in the `net` package and
`network` will be deprecated.
* `os`: Platform-independent interfaces to operating system functionality.
* `range`: Generic functions and templates for D ranges.
* `test`: Test suite for unittest-blocks.
* `typecons`: Templates that allow to build new types based on the available
ones.


## Basic usage

### Allocators

Memory management is done with allocators. Instead of using `new` to create an
instance of a class, an allocator is used:

```d
import tanya.memory;

class A
{
    this(int arg)
    {
    }
}

A a = defaultAllocator.make!A(5);

defaultAllocator.dispose(a);
```

As you can see, the user is responsible for deallocation, therefore `dispose`
is called at the end.

If you want to change the `defaultAllocator` to something different, you
probably want to do it at the program's beginning. Or you can invoke another
allocator directly. It is important to ensure that the object is destroyed
using the same allocator that was used to allocate it.

What if I get an allocated object from some function? The generic rule is: If
you haven't requested the memory yourself (with `make`), you don't need to free
it.

`tanya.memory.smartref` contains smart pointers, helpers that can take care of
a proper deallocation in some cases for you.

### Exceptions

Since exceptions are normal classes in D, they are allocated and dellocated the
same as described above, but:

1. The caller is **always** responsible for destroying a caught exception.
2. Exceptions are **always** allocated and should be always allocated with the
`defaultAllocator`.

```d
import tanya.memory;

void functionThatThrows()
{
    throw defaultAlocator.make!Exception("An error occurred");
}

try
{
    functionThatThrows()
}
catch (Exception e)
{
    defaultAllocator.dispose(e);
}
```

### Containers

Arrays are commonly used in programming. D's built-in arrays often rely on the
GC. It is inconvenient to change their size, reserve memory for future use and
so on. Containers can help here. The following example demonstrates how
`tanya.container.array.Array` can be used instead of `int[]`.

```d
import tanya.container.array;

Array!int arr;

// Reserve memory if I know that my container will contain approximately 15
// elements.
arr.reserve(15);

arr.insertBack(5); // Add one element.
arr.length = 10; // New elements are initialized to 0.

// Iterate over the first five elements.
foreach (el; arr[0 .. 5])
{
}

int i = arr[7]; // Access 8th element.
```

There are more containers in the `tanya.container` package.


## Development

### Supported compilers

| DMD     | GCC            |
|:-------:|:--------------:|
| 2.078.2 | *gdc-5* branch |
| 2.077.1 |                |
| 2.076.1 |                |

### Current status

Following modules are under development:

| Feature  | Branch    | Build status                                                                                                                                                                                                                                                                                  |
|----------|:---------:|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| BitArray | bitvector | [![bitvector](https://travis-ci.org/caraus-ecms/tanya.svg?branch=bitvector)](https://travis-ci.org/caraus-ecms/tanya) [![bitvector](https://ci.appveyor.com/api/projects/status/djkmverdfsylc7ti/branch/bitvector?svg=true)](https://ci.appveyor.com/project/belka-ew/tanya/branch/bitvector) |
| TLS      | crypto    | [![crypto](https://travis-ci.org/caraus-ecms/tanya.svg?branch=crypto)](https://travis-ci.org/caraus-ecms/tanya) [![crypto](https://ci.appveyor.com/api/projects/status/djkmverdfsylc7ti/branch/crypto?svg=true)](https://ci.appveyor.com/project/belka-ew/tanya/branch/crypto)                |

### Release management

Deprecated features are removed after one release that includes these deprecations.

## Further characteristics

* Tanya is a native D library without any external dependencies.

* Tanya is cross-platform. The development happens on a 64-bit Linux, but it
is being tested on Windows and FreeBSD as well.

* The library isn't thread-safe yet.


## Feedback

Any feedback about your experience with tanya would be greatly appreciated. Feel free to
[contact me](mailto:info@caraus.de).
