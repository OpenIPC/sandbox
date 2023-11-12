
## Packer/Unpacker for .PKG camera firmwares

CamHi based cameras use .pkg files to update firmware.

For example [http://www.ipcam.xin/]

## File format

0x0000: signature 'PIHC'

0x0004: file format version, currently 0x1002. May be 0x1001

0x0008: lengths of parts. 4 bytes LE for each (boot.img, kernel.img, rootfs.img, ipc.img, update.zip). If part is absent the length is zero.

0x001C: 'IPCAM' string

0x0044: start of array of md5 hashes for each part. Length of each element is 40 bytes, unused is zero filled

0x0200: parts data, one by one in sequence

## MD5 calculation

Salt 'IPCAM' is used. Salt is added after data

You can use next command to calculate hash of a file:

echo -n IPCAM | cat %f - | md5sum -

## Hardware version

Version is encoded in the file name, so it must match your HW

## Troubleshooting

tmp filesystem is accesible through the web UI: http://192.168.1.100/web/tmpfs/boot.img

It will download boot.img after failed check. Files are not deleted after upload.
