# EMC

Invoking a C/C++ build tool-chain from Emacs.

Marco Antoniotti
See file COPYING for licensing and copyright information.


## DESCRIPTION

The standard `compile` machinery is mostly designed for interactive
use, but nowadays, for C/C++ at least, build systems and different
platforms make the process a bit complicated.

The goal of this library is to hide some of these details for Unix
(Linux), Mac OS and Windows.

The combinations supported are

| Unix/Linux         | Mac OS             | Windows (10/11)    |
|--------------------|--------------------|--------------------|
| make               | make               | nmake              |
| executable         | executable         | executable: .exe   |
| library: .a .so    | library: .a .dylib | library: .obj .dll |


On Windows `emc` assumes the installation of Microsoft Visual
Studio (Community -- provisions are made to handle the Enterprise
or other versions but they are untested).  `MSYS` will be added in the
future, but is will mostly look like UNIX.

All in all, the best way to use this library is to call the `emc:make`
function, which invokes the underlying build system (at the time of
this writing either `make` or `nmake`); e.g., the call:

```
    (emc:make)
```

calls `compile` after having constructed a platform dependent "make"
command.  On MacOS and Linux/UNIX system this defaults to:

```
    make -f Makefile
```

On Windows with MSVC this defaults to (assuming MSVC is installed on drive
`:C`)

```
    (C:\Path\To\MSVC\...\vcvars64.bat) & nmake /F Makefile
```

The `emc` package gives you several knobs to customize your environment,
especially on Windows, where things are more complicated.  Please refer to
the `emc:make` function for an initial set of arguments you can use.  E.g.,
on Linux/UNIX the call

```
    (emc:make :makefile "FooBar.mk" :build-dir "foobar-build")
```

will result in a call to "make" such as:

```
    cd foobar-build ; make -f Foobar.mk
```

as a result `compile` will do the right thing by intercepting the `cd` in
the string.


## A NOTE ON FORKING

Of course you are free to fork the project subject to the current
licensing scheme.  However, before you do so, I ask you to consider
plain old "cooperation" by asking me to become a developer.
It helps keeping the entropy level at an acceptable level.


Enjoy

Marco Antoniotti, Milan, Italy, (c) 2025
