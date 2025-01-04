# EMC

Invoking a C/C++ build toolchain from Emacs.

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
| library: .a .so    | lobrary: .a .dylib | library: .obj .dll |


On Windows `emc` assumes the installation of Microsoft Visual
Studio (Community -- provisions ar emade to handle the Enterprise
or other versions but they are untested).  `MSYS` will be added in the
future, but is will mostly look like UNIX.

Enjoy

Marco Antoniotti, Milan, Italy, (c) 2025
