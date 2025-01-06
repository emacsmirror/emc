/* -*- Mode: C -*- */

/* hellolib.c --
 *
 * A tiny library for testing.
 */

#ifndef _HELLOLIB_C
#define _HELLOLIB_C

#include <stdio.h>
#include "hellolib.h"

void hellolib_say_hello(const char * to) {
    printf("Hello %s!\n", to);
}


#endif /* _HELLOLIB_C */

/* hellolib.c ends here. */
