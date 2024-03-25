### Firmware repacker

```
sh repack.sh ssc333_lite_tp-link-tapo-c110-v2-nor SSID PASSWORD
```

### Flashing

* https://t.me/openipc/109624
* https://github.com/OpenIPC/snander-mstar/releases/tag/latest

```
snander -p ch341a -e
snander -p ch341a -w openipc-ssc333-nor.bin
```
