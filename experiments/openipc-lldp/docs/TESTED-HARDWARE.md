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

## Unverified historical capability

The `100base-T2(FD)` entry above is historical output. The current encoder maps supported ethtool flags explicitly and never sets the LLDP 100BASE-T2 capability bits. Attributing this entry to the driver alone was unsupported. A fresh packet capture and matching binary version are needed to distinguish an older encoder issue from switch decoding behavior.

The capability bit ordering follows [IEEE interpretation 8](https://www.ieee802.org/1/pages/int-8.html).
