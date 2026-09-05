# Draft PR text for OpenIPC/sandbox

## Title

Add tiny LLDP advertiser experiment for OpenIPC cameras

## Description

This adds `openipc-lldp`, a small LLDP advertiser intended for resource-constrained OpenIPC cameras where a full LLDP daemon may be unnecessary.

The program builds LLDP frames directly through an `AF_PACKET` raw socket and advertises runtime camera identity, OpenIPC build information, IPv4 management address, and — where the kernel driver exposes it through legacy `ETHTOOL_GSET` — IEEE 802.3 MAC/PHY information.

Tested end-to-end on:

- OpenIPC GK7205V200 `lite`, Buildroot 2024.02.10
- Cisco Catalyst 2960 Plus, IOS 15.2(7)E14

The firmware-integrated dynamically linked ARM binary was 9,480 bytes. A Buildroot package example and init script are included.

The docs also record two unrelated findings encountered while reproducing the firmware build: a low-memory `sysupgrade --web` archive-retention issue and a current CachyOS/Arch host-tar/libacl build conflict. Those are kept in separate docs/patches and are not required by the LLDP utility itself.

## Tested behavior

After boot, the camera appeared automatically in Cisco LLDP neighbor detail with:

```text
System Name: openipc-gk7205v200
System Description:
OpenIPC 2.6.09.05 | gk7205v200_lite | local-20260904-build
Management Addresses:
    IP: 172.16.10.44
Auto Negotiation - supported, enabled
Media Attachment Unit type: 16
```

## Notes

- Source is portable in intent; binaries remain architecture/ABI-specific.
- PHY information is omitted if the driver does not support `ETHTOOL_GSET`.
- The historical unusual 100BASE-T2 capability requires a fresh packet capture; the current encoder does not set that bit.
