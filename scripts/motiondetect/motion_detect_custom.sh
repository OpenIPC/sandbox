#!/bin/sh
#[object count] [x coordinate] [y coordinate] [region width] [region height]
# ======================================================================================================================
# Min and max dimentions of area to trigger
MIN_HEIGHT=300
MAX_HEIGHT=2000
MIN_WIDTH=300
MAX_WIDTH=2000
# delay between triggering
DELAY=2
#script parameters
objcount=$1
xcoord=$2
ycoord=$3
regionwith=$4
regionheight=$5
# ======================================================================================================================
#logger "width is $regionwith, height is $regionheight"
# check for width and height
if [ "$regionheight" -ge "$MIN_HEIGHT" -a "$regionheight" -le "$MAX_HEIGHT" -a "$regionwith" -le "$MAX_WIDTH" ] ;then
  send2telegram.sh
  logger "Sending to Telegram, width is $regionwith, height is $regionheight. Found $objcount object(s)!"
  send2ftp.sh
fi

if [ "$regionheight" -le "$MIN_HEIGHT"  ] ;then
  if [ "$LOGGING" -eq 1 ] ;then
    logger "small object"
  fi
fi

sleep ${DELAY}
