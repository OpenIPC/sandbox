# Low-memory WebUI sysupgrade finding

While testing the firmware-integrated LLDP package on a GK7205V200 camera with about 34 MiB of usable RAM, OpenIPC `sysupgrade` v1.0.62 repeatedly ran out of memory during a WebUI archive update.

## Reproduction

The WebUI invoked:

```text
/usr/sbin/sysupgrade --web --archive=/tmp/firmware.tgz -k -r
```

The uploaded archive was 7,004,490 bytes. `download_firmware()` unpacked the archive into `/tmp`, leaving all of these resident in tmpfs at the same time:

- compressed `.tgz` archive (~6.7 MiB)
- kernel image (~1.7 MiB)
- rootfs image (~5.0 MiB)
- sysupgrade RAM root (8 MiB tmpfs)
- Majestic, which intentionally remains alive for `--web` log streaming

The first attempt reached the RAM phase and died during rootfs verification. Kernel logs showed OOM kills. Read-only comparisons after the failure confirmed the staged kernel/rootfs differed from the flash partitions, so the failure occurred before flash writes.

## Functional test

For the test, the local archive was removed after extraction and MD5 validation but before `enter_ramfs()`. The next WebUI update printed:

```text
Local archive unpacked
Released archive from RAM

Moving the flash phase into RAM
Flashing from RAM
```

and completed kernel and rootfs erase/write/verify at 100% before rebooting successfully.

## Proposed upstream-safe change

The included patch only deletes archives under `/tmp/`. This preserves a user-supplied archive stored on persistent media while reclaiming WebUI tmpfs memory before the RAM pivot.

See:

```text
patches/sysupgrade-v1.0.62-release-tmp-archive.patch
```

The exact `/tmp/*` path guard is a conservative refinement of the tested runtime fix; the underlying memory-reclamation behavior was verified on hardware.
