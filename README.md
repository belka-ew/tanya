# Tanya

[![Dub version](https://img.shields.io/dub/v/tanya.svg)](https://code.dlang.org/packages/tanya)
[![Dub downloads](https://img.shields.io/dub/dt/tanya.svg)](https://code.dlang.org/packages/tanya)
[![License: MPL 2.0](https://img.shields.io/badge/license-MPL_2.0-blue.svg)](https://opensource.org/licenses/MPL-2.0)

Tanya is a general purpose library for D programming language.

Its aim is to simplify the manual memory management in D and to provide a
guarantee with @nogc attribute that there are no hidden allocations on the
Garbage Collector heap. Everything in the library is usable in @nogc code.
Tanya provides data structures and utilities to facilitate painless systems
programming in D.

- [API Documentation](https://docs.caraus.tech/tanya)

## Overview

Tanya consists of the following packages and (top-level) modules:

* `algorithm`: Collection of generic algorithms.
* `bitmanip`: Bit manipulation.
* `container`: Queue, Array, Singly and doubly linked lists, Buffers, UTF-8
string, Set, Hash table.
* `conv`: This module provides functions for converting between different
types.
* `format`: Formatting and conversion functions.
* `hash`: Hash algorithms.
* `math`: Arbitrary precision integer and a set of functions.
* `memory`: Tools for manual memory management (allocators, smart pointers).
* `meta`: Template metaprogramming. This package contains utilities to acquire
type information at compile-time, to transform from one type to another. It has
also different algorithms for iterating, searching and modifying template
arguments.
* `net`: URL-Parsing, network programming.
* `os`: Platform-independent interfaces to operating system functionality.
* `range`: Generic functions and templates for D ranges.
* `test`: Test suite for unittest-blocks.
* `typecons`: Templates that allow to build new types based on the available
ones.


## NogcD

To achieve programming without the Garbage Collection tanya uses a subset of D:
NogcD.

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

### Built-in array operations and containers

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


### Immutability

Immutability doesn't play nice with manual memory management since the
allocated storage should be initialized (mutated) and then released (mutated).
`immutable` is used only for non-local immutable declarations (that are
evaluated at compile time), static immutable data, strings (`immutable(char)[]`,
`immutable(wchar)[]` and `immutable(dchar)[]`).


### Unsupported features

The following features depend on GC and aren't supported:

- `lazy` parameters (allocate a closure which is evaluated when then the
parameter is used)

- `synchronized` blocks


## Development

### Supported compilers

| DMD     | GCC       |
|:-------:|:---------:|
| 2.100.0 | 12.1      |

## Further characteristics

- Tanya is a native D library

- Tanya is cross-platform. The development happens on a 64-bit Linux, but it
is being tested on Windows and FreeBSD as well

- Tanya favours generic algorithms therefore there is no auto-decoding. Char
arrays are handled as any other array type

- The library isn't thread-safe yet

- Complex numbers (`cfloat`, `cdouble`, `creal`, `ifloat`, `idouble`, `ireal`)
aren't supported


## Feedback

Any feedback about your experience with tanya would be greatly appreciated. Feel free to
[contact me](mailto:belka@caraus.de).
