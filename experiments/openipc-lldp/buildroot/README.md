# OpenIPC Buildroot integration

These files show the package layout used for the tested OpenIPC firmware build.

Copy the directory into the OpenIPC external tree as:

```text
general/package/openipc-lldp/
├── Config.in
├── openipc-lldp.mk
├── openipc-lldp.c
└── S55openipc-lldp
```

The source file in this repository is the same `openipc-lldp.c`; copy or symlink it into the package directory.

Enable the package in the target defconfig:

```text
BR2_PACKAGE_OPENIPC_LLDP=y
```

For the tested GK7205V200 lite build this was added to:

```text
br-ext-chip-goke/configs/gk7205v200_lite_defconfig
```

The Buildroot package uses `$(TARGET_CC)` and produces a dynamically linked target binary. On the tested build the installed binary was 9,480 bytes and used `/lib/ld-musl-arm.so.1`.

The init script starts the advertiser after networking as `S55openipc-lldp` and sends SIGTERM on stop via `killall`, allowing the program to transmit an LLDP TTL=0 shutdown advertisement.
