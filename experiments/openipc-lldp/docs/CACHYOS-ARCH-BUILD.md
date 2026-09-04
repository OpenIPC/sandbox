# Building OpenIPC on CachyOS / Arch Linux

During the OpenIPC Buildroot build on a current CachyOS/Arch host, the Buildroot host package for GNU tar 1.34 conflicted with newer libacl headers. Both GNU tar and the host ACL API exposed helper names such as `acl_get_file_at`, `acl_set_file_at`, and `acl_delete_def_file_at`.

The included patch renames tar's private wrappers to avoid the collision:

```text
patches/0003-fix-acl-2.4-function-name-conflicts.patch
```

For an OpenIPC external tree, the patch was placed at:

```text
general/package/all-patches/tar/0003-fix-acl-2.4-function-name-conflicts.patch
```

Buildroot then applied it automatically when building the host tar package.

This is a host-build compatibility workaround and is unrelated to LLDP itself. It is included only because it was required to reproduce the firmware build on the tested CachyOS system.
