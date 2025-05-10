# NOTES

## 2025-01-06

The setup directly uses `call-process-shell-command`.  It may be
better to switch to the `compile` machinery.


## 2025-03-13

After switching to the `compile` machinery, it may be worthwhile to
change to a more `defgeneric` based implementation.


## 2025-03-18

The build system depends on the platform `system-type` and on the
`build-system`, which can be `make`, `nmake`, or `cmake`.
The generic functions will therefore combine these at a minimum.


## 2025-04-01

Adding `CMake` commands.  Maybe I will have to byte the bullet and
make three ways generic functions taking into account the *sub
command* as well.


## 2025-04-17

Added `emc:craft-command` in order to make the `emc` *GUI* (using the
Emacs `widget` library) easier to write.


## 2025-05-10

The overall contraption works (for an appropriate definition of
"works".  In general, should we add somethong other than **make** and
**cmake** the code should be refactored to accomodate the actual
double dispatch *platform*/*build system* (or:
*platform*/*tool*/*build system*, as in `darwin/gcc/cmake`).  Not now.
