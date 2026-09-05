# openipc-lldp

A tiny LLDP advertiser for resource-constrained OpenIPC cameras.

`openipc-lldp` lets a managed switch discover an OpenIPC camera and display useful identity, management, and Ethernet PHY information without pulling in a full LLDP daemon.

It was developed and tested on a GK7205V200 `lite` camera and a Cisco Catalyst 2960 Plus. The firmware-integrated ARM binary was **9,480 bytes**.

## What it advertises

- chassis ID derived from the interface MAC address
- port ID and port description from the interface name
- system name from the runtime hostname
- OpenIPC version, build platform, and build ID from `/etc/os-release`
- IPv4 management address
- station system capability
- IEEE 802.3 MAC/PHY Configuration/Status TLV when the driver supports legacy `ETHTOOL_GSET`
  - autonegotiation support and status
  - advertised 10/100/1000 copper capabilities
  - pause/asymmetric-pause capability bits when exposed by the driver
  - operational MAU type derived from link speed/duplex
- IEEE 802.3 Maximum Frame Size TLV from the interface MTU
- TTL=0 shutdown advertisement on SIGTERM, SIGINT, or SIGHUP

If PHY information is unavailable, the IEEE 802.3 PHY TLV is omitted rather than fabricated.

## Example Cisco output

```text
Local Intf: Fa0/38
Chassis id: 0012.332d.c6cd
Port id: eth0
Port Description: eth0
System Name: openipc-gk7205v200

System Description:
OpenIPC 2.6.09.05 | gk7205v200_lite | local-20260904-build

System Capabilities: S
Enabled Capabilities: S
Management Addresses:
    IP: 172.16.10.44
Auto Negotiation - supported, enabled
Physical media capabilities:
    100base-T2(FD)
    100base-TX(FD)
    100base-TX(HD)
    10base-T(FD)
    10base-T(HD)
Media Attachment Unit type: 16
```

The historical `100base-T2(FD)` entry has not been explained by a packet capture; the current encoder does not set that capability. See [docs/TESTED-HARDWARE.md](docs/TESTED-HARDWARE.md).

## Standalone cross-build

The supplied Makefile defaults to the ARMv7 hard-float musl cross compiler used during initial testing:

```sh
make
```

Equivalent command:

```sh
arm-linux-musleabihf-gcc -Os -Wall -Wextra -static -s \
    openipc-lldp.c -o openipc-lldp
```

For another OpenIPC architecture, override the compiler/toolchain as appropriate. The source is intended to be portable, but compiled binaries are architecture/ABI-specific.

Verify before copying to a camera:

```sh
file openipc-lldp
```

## Test from RAM first

```sh
scp openipc-lldp root@CAMERA_IP:/tmp/
ssh root@CAMERA_IP
chmod +x /tmp/openipc-lldp
/tmp/openipc-lldp -i eth0
```

On the switch:

```text
show lldp neighbors
show lldp neighbors detail
```

Running from `/tmp` is strongly recommended for initial testing because `lite` images can have very little persistent overlay space.

## Options

```text
-i iface        interface (default eth0)
-n name         override system name
-d desc         override system description
-t ttl          LLDP TTL (default 120 seconds)
-r sec          advertisement interval (default 30 seconds)
-q              quiet
-V              version
-h              help
```

## OpenIPC Buildroot integration

A working Buildroot package example is included under [`buildroot/`](buildroot/).

The tested target defconfig contained:

```text
BR2_PACKAGE_OPENIPC_LLDP=y
```

See [buildroot/README.md](buildroot/README.md) for layout and integration notes.

## Implementation notes

The program uses an `AF_PACKET` raw socket and sends LLDP frames to the standard nearest-bridge multicast address `01:80:c2:00:00:0e` with EtherType `0x88cc`.

It intentionally avoids heavyweight discovery loops. Runtime interface data is obtained through ioctls such as `SIOCGIFADDR`, `SIOCGIFHWADDR`, `SIOCGIFMTU`, and `SIOCETHTOOL`.

The PHY path currently uses legacy `ETHTOOL_GSET` because that is what the tested OpenIPC/GK7205 kernel driver exposes. A future version could add the modern link-settings API while retaining the legacy fallback.

## Related findings from the test build

Two unrelated issues were encountered while building and flashing the test firmware. They are documented separately so they do not get confused with the LLDP implementation:

- [Low-memory WebUI sysupgrade archive retention](docs/SYSUPGRADE-LOW-MEMORY.md)
- [CachyOS/Arch GNU tar vs libacl build conflict](docs/CACHYOS-ARCH-BUILD.md)

Corresponding patches are under [`patches/`](patches/).

## Version

Current experiment version: **0.2.2**

## License

MIT — see [LICENSE](LICENSE).

## Host regression checks

Run `make test` with a native C compiler. Tests capture frames in memory; no root privileges or network interface are needed. System name and description overrides are limited to 256 bytes.
