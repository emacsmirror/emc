### -*- Mode: Makefile -*-

### hellolib.make

HDRS = hellolib.h
SRCS = hellolib.c
OBJS = $(SRCS:.c=.o)
HLIB = $(SRCS:.c=.dylib)

all : hello

hello : hello.o $(HLIB)
	$(CC) -o hello $< $(HLIB)

$(HLIB) : $(OBJS) $(HDRS)
	$(CC) -shared -o $(HLIB) $(OBJS)

$(OBJS) : $(SRCS) $(HDRS)
	$(CC) -c -FPIC $<


.PHONY : clean
clean :
	$(RM) $(OBJS) $(HLIB) hello.o hello

### hellolib.make ends here.
