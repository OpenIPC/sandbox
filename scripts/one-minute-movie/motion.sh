#!/bin/sh
mkdir -p /mnt/mmcblk0p1/queue
ln -s `lsof | awk '/\/mnt\/mmcblk0p1\/recordings/ {print $4}'` /mnt/mmcblk0p1/queue/
