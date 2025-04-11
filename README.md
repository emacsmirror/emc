# EMC

Invoking a C/C++ (and other) build tool-chain from Emacs.

Marco Antoniotti
See file COPYING for licensing and copyright information.


## DESCRIPTION

The standard `compile` machinery is mostly designed for interactive
use, but nowadays, for C/C++ at least, build systems and different
platforms make the process a bit complicated.

The goal of this library is to hide some of these details for Unix
(Linux), Mac OS and Windows.   The `emc` library interfaces to
`make` and `nmake` building setup and to
[`cmake`](https://www.cmake.org).

The supported `Makefile` combinations are:

| Unix/Linux         | Mac OS             | Windows (10/11)    |
|--------------------|--------------------|--------------------|
| make               | make               | nmake              |
| executable         | executable         | executable: .exe   |
| library: .a .so    | library: .a .dylib | library: .obj .dll |


On Windows `emc` assumes the installation of Microsoft Visual
Studio (Community -- provisions are made to handle the Enterprise
or other versions but they are untested).  `MSYS` will be added in the
future, but is will mostly look like UNIX.

 There are three main `emc` commands: `emc:run`, `emc:make`, and
`emc:cmake`.  `emc:run` is the most generic command and allows to
select the build system.  `emc:make` and `emc:cmake` assume instead
`make` or `nmake`, and `cmake` respectively.

Invoking the command `emc:run` will use the
`emc:*default-build-system*` (defaulting to `:make`) on the current
platform supplying hopefully reasonable defaults.  E.g.,
```
    (emc:run)
```
will usually result in a call to
```
    make -f Makefile
```
on UN\*X platforms.

All in all, the easiest way to use this library is to call the `emc:make`
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

To invoke `cmake` the relevant function is `emc:cmake` which takes
the following "sub-commands" (the `<bindir>` below is to be
interpreted in the `cmake` sense).
1. `:setup`: which is equivalent to `cmake <srcdir>` issued in a
    `binary` directory.
2. `:build`: which is equivalent to `cmake --build <bindir>`.
3. `:install`: which is equivalent to `cmake --install <bindir>`.
4. `:uninstall`: which currently has no `cmake` equivalent.
5. `:clean`: equivalent to `cmake --build <bindir> -t clean`.
5. `:fresh`: equivalent to `cmake --fresh <bindir>`.

Finally, you can use the `emc:run` command which will ask you which
*sub-command* to use.  If you prefix it with `C-u`, it will ask you for
several other variables, including the choice of *build system*
(which, for the time being, is either `:make`, or `:cmake`).



## A NOTE ON FORKING

Of course you are free to fork the project subject to the current
licensing scheme.  However, before you do so, I ask you to consider
plain old "cooperation" by asking me to become a developer.
It helps keeping the entropy level at an acceptable level.


Enjoy

Marco Antoniotti, Milan, Italy, (c) 2025
