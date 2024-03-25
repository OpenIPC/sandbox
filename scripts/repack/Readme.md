### Firmware repacker

1. Downloads the specified firmware from the Builder repository
2. Downloads the current bootloader from the Firmware repository
3. Unpacks the file system and adds WiFi settings
4. Packs the file system and prepares a complete image

```
curl -s https://raw.githubusercontent.com/OpenIPC/sandbox/main/scripts/repack/repack.sh | sh -s -- ssc333_lite_tp-link-tapo-c110-v2-nor SSID PASSWORD
```

### Flashing

* https://t.me/openipc/109624
* https://github.com/OpenIPC/snander-mstar/releases/tag/latest

```
snander -p ch341a -e
snander -p ch341a -w openipc-ssc333-nor.bin
```
