### -*- Mode: Makefile -*-

### hellolib.make

HDRS = hellolib.h
SRCS = hellolib.c
OBJS = $(SRCS:.c=.o)
HLIB = $(SRCS:.c=.so)

all : hello

hello : hello.o $(HLIB)
	$(CC) -o hello $(HLIB)

$(HLIB) : $(OBJS) $(HDRS)
	$(CC) -shared -o $(HLIB) $(OBJS)

$(OBJ) : $(SRCS) $(HDRS)
	$(CC) -c -FPIC $<

### hellolib.make ends here.
