# Tested hardware and observed output

## Camera

Tested on an OpenIPC GK7205V200 camera:

```text
OpenIPC 2.6.09.05
Buildroot 2024.02.10
gk7205v200_lite
Linux 4.9.37, ARMv7
```

The firmware-integrated binary was 9,480 bytes and started automatically as:

```text
/usr/bin/openipc-lldp -i eth0
```

## Switch

Verified against a Cisco Catalyst 2960 Plus (`WS-C2960+48PST-S`) running IOS 15.2(7)E14 with LLDP enabled.

Observed neighbor output:

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
Vlan ID: - not advertised
```

## Driver caveat

The `100base-T2(FD)` capability above is unusual. `openipc-lldp` deliberately relays the legacy `ETHTOOL_GSET` capability bitmap reported by the kernel driver rather than attempting to correct or invent PHY capabilities. Drivers may therefore expose odd or stale capability bits.
