# Standalone cross-build defaults for GK7205V200 / ARMv7 hard-float.
# Override CC/CFLAGS/LDFLAGS on the make command line for other targets.
CC = arm-linux-musleabihf-gcc
CFLAGS ?= -Os -Wall -Wextra
LDFLAGS ?= -static -s

all: openipc-lldp

openipc-lldp: openipc-lldp.c
	$(CC) $(CFLAGS) openipc-lldp.c $(LDFLAGS) -o $@

clean:
	rm -f openipc-lldp

.PHONY: all clean
