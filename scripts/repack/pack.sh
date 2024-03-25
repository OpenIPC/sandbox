#!/bin/sh

hw=$1
fw=openipc-$hw-nor.bin
dl=https://github.com/openipc/firmware/releases/download/latest

if [ -z "$hw" ]; then
 echo "Usage: $0 [chipset]"
 exit 0
fi

mkdir -p output
wget -q --show-progress $dl/u-boot-$hw-nor.bin -P output
wget -q --show-progress $dl/openipc.$hw-nor-ultimate.tgz -P output
tar -xf output/openipc.$hw-nor-ultimate.tgz -C output

dd if=/dev/zero bs=1K count=5000 status=none | tr '\000' '\377' > $fw
dd if=output/u-boot-$hw-nor.bin of=$fw bs=1K seek=0 conv=notrunc status=none
dd if=output/uImage.$hw of=$fw bs=1K seek=320 conv=notrunc status=none
dd if=output/rootfs.squashfs.$hw of=$fw bs=1K seek=2368 conv=notrunc status=none
rm -rf output

echo "Created: $fw"
