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

