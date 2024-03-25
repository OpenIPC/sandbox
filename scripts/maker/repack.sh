#!/bin/sh
openipc=https://github.com/openipc/firmware/releases/download/latest
builder=https://github.com/openipc/builder/releases/download/latest

if [ -z "$(dpkg -l | grep squashfs-tools)" ]; then
 echo Install the following package:
 echo sudo apt-get install squashfs-tools
 exit 0
fi

if [ -z "$1" ]; then
 echo "Usage: $0 [firmware] [ssid] [pass]"
 exit 0
fi

chipset=$(echo $1 | cut -d_ -f1)
release=openipc-$chipset-nor.bin

mkdir -p output
wget -q --show-progress $openipc/u-boot-$chipset-nor.bin -O output/uboot.bin
wget -q --show-progress $builder/$1.tgz -O output/builder.tgz
tar -xf output/builder.tgz -C output

if [ -n "$2" ] && [ -n "$3" ]; then
 file=output/squashfs/usr/share/openipc/wireless.sh
 unsquashfs -d output/squashfs output/rootfs.squashfs.$chipset > /dev/null
 echo "#!/bin/sh" >> $file
 echo "fw_setenv wlanssid $2" >> $file
 echo "fw_setenv wlanpass $3" >> $file
 chmod 755 $file
 mksquashfs output/squashfs output/rootfs.$chipset -comp xz > /dev/null
else
 mv output/rootfs.squashfs.$chipset output/rootfs.$chipset
fi

dd if=/dev/zero bs=1K count=5000 status=none | tr '\000' '\377' > $release
dd if=output/uboot.bin of=$release bs=1K seek=0 conv=notrunc status=none
dd if=output/uImage.$chipset of=$release bs=1K seek=320 conv=notrunc status=none
dd if=output/rootfs.$chipset of=$release bs=1K seek=2368 conv=notrunc status=none
rm -rf output

echo "Created: $release"
