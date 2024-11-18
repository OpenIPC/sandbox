#!/bin/sh
oldtype=9
oldres=`fw_printenv -n TP9950res`
sensorConfig='/etc/sensors/bt656_720p.ini'
ipctool gpio mux 69 gpio

function changeINI {

echo 'set W='$1'   H='$2 > /dev/console
sed -i "s/Timingblank_HsyncAct.*$/Timingblank_HsyncAct = $1/" $sensorConfig
sed -i "s/Timingblank_VsyncVact.*$/Timingblank_VsyncVact = $2/" $sensorConfig
sed -i "s/DevRect_w.*$/DevRect_w = $1/" $sensorConfig
sed -i "s/DevRect_h.*$/DevRect_h = $2/" $sensorConfig

}



while :
do

## no video detected
while [ $(((`ipctool2 i2cget 0x88 0x01` >> 7) & 0x1)) -eq 1 ] 
do
echo "no video" > /dev/console
gpio set 69               > /dev/null                             ##  led off
sleep 2
done



type=$((`ipctool2 i2cget 0x88 0x03` & 0x7))

status=`ipctool2 i2cget 0x88 0x01`
if [ $? -eq 0 ] ; then 
sleep 1
if [[ $type -eq $((`ipctool2 i2cget 0x88 0x03` & 0x7))  ]]; then    ## double check  video type
#echo $type > /dev/console


if [ $type -ne $oldtype  ] || [ $((($status >> 4) & 0x1)) -ne 1 ] ; then

ipctool2 i2cset 0x88 0x2a 0x3c   ## blue screen
gpio set 69                    > /dev/null                        ##  led off

case $type in
 7 )
status=`ipctool2 i2cget 0x88 0x01`

## 7 mean  other types.....tp9950 show 7 type always  with "tvi_1280x720"  mode  
echo "check other TVI" > /dev/console
[ $((($status >> 4) & 0x1)) -ne 1 ]  || [ $((($status ) & 0x1)) -ne 0 ]  && setType9950.sh tvi_1280x720_25fps  && fmt='tvi'
status=`ipctool2 i2cget 0x88 0x01`
[ $((($status >> 4) & 0x1)) -ne 1 ] || [ $((($status ) & 0x1)) -ne 0 ]   && echo " NOT tvi_1280x720_25fps " > /dev/console
sleep 2
status=`ipctool2 i2cget 0x88 0x01`
[ $((($status >> 4) & 0x1)) -ne 1 ]  || [ $((($status ) & 0x1)) -ne 0 ]  && setType9950.sh tvi_1280x720_30fps  && fmt='tvi'
status=`ipctool2 i2cget 0x88 0x01`
#### check and change i2c regs to another mode 
[ $((($status >> 4) & 0x1)) -ne 1 ] || [ $((($status ) & 0x1)) -ne 0 ]   && echo " NOT tvi_1280x720_30fps " > /dev/console && setType9950.sh ahd_1280x720_25fps && fmt='ahd'
echo $fmt > /dev/console
fw_setenv TP9950type $fmt


;;
 6 )

echo "CVBS" > /dev/console

sleep 2
status=`ipctool2 i2cget 0x88 0x01`
[ $((($status >> 4) & 0x1)) -ne 1 ] || [ $((($status ) & 0x1)) -ne 0 ]  && setType9950.sh pal_960x288_25fps && fmt='PAL'
sleep 2
status=`ipctool2 i2cget 0x88 0x01`
[ $((($status >> 4) & 0x1)) -ne 1 ] || [ $((($status ) & 0x1)) -ne 0 ]  && setType9950.sh ntsc_960x240_30fps && fmt='NTSC'
status=`ipctool2 i2cget 0x88 0x01`
[ $((($status >> 4) & 0x1)) -ne 1 ]  && echo "pechyaJl bka_lock" > /dev/console
[ $((($status ) & 0x1)) -ne 0 ]  && echo "pechyaJl bka_car" > /dev/console
echo $fmt > /dev/console
fw_setenv TP9950type $fmt

if [[ "$fmt" == "PAL"  ]]; then
fw_setenv TP9950res '960x288_25fps'
changeINI $(fw_printenv -n TP9950res | tr 'x_' ' ')
fi
if [[ "$fmt" == "NTSC"  ]]; then
fw_setenv TP9950res '960x240_30fps'
changeINI $(fw_printenv -n TP9950res | tr 'x_' ' ')
fi
 ;;
 5 )

echo "1280x720_25fps" > /dev/console

fw_setenv TP9950res '1280x720_25fps' 
changeINI $(fw_printenv -n TP9950res | tr 'x_' ' ')

sleep 2
status=`ipctool2 i2cget 0x88 0x01`
[ $((($status >> 4) & 0x1)) -ne 1 ] || [ $((($status ) & 0x1)) -ne 0 ]  && setType9950.sh ahd_1280x720_25fps  && fmt='ahd'
sleep 2
status=`ipctool2 i2cget 0x88 0x01`
[ $((($status >> 4) & 0x1)) -ne 1 ]  || [ $((($status ) & 0x1)) -ne 0 ]  && setType9950.sh cvi_1280x720_25fps  && fmt='cvi'
sleep 2
status=`ipctool2 i2cget 0x88 0x01`
[ $((($status >> 4) & 0x1)) -ne 1 ]  || [ $((($status ) & 0x1)) -ne 0 ]  && setType9950.sh tvi_1280x720_25fps  && fmt='tvi'
status=`ipctool2 i2cget 0x88 0x01`
[ $((($status >> 4) & 0x1)) -ne 1 ]  && echo "pechyaJl bka_lock" > /dev/console
[ $((($status ) & 0x1)) -ne 0 ]  && echo "pechyaJl bka_car" > /dev/console
echo $fmt > /dev/console
fw_setenv TP9950type $fmt
;;
 4 )

echo "1280x720_30fps" > /dev/console
fw_setenv TP9950res '1280x720_30fps'
changeINI $(fw_printenv -n TP9950res | tr 'x_' ' ')
sleep 2
status=`ipctool2 i2cget 0x88 0x01`
[ $((($status >> 4) & 0x1)) -ne 1 ]  ||  [ $((($status ) & 0x1)) -ne 0 ]  && setType9950.sh ahd_1280x720_30fps  && fmt='ahd'
sleep 2
status=`ipctool2 i2cget 0x88 0x01`
[ $((($status >> 4) & 0x1)) -ne 1 ]  ||  [ $((($status ) & 0x1)) -ne 0 ]  && setType9950.sh cvi_1280x720_30fps  && fmt='cvi'
sleep 2
status=`ipctool2 i2cget 0x88 0x01`
[ $((($status >> 4) & 0x1)) -ne 1 ]  ||  [ $((($status ) & 0x1)) -ne 0 ]  && setType9950.sh tvi_1280x720_30fps  && fmt='tvi'
status=`ipctool2 i2cget 0x88 0x01`
[ $((($status >> 4) & 0x1)) -ne 1 ]  && echo "pechyaJl bka_lock" > /dev/console
[ $((($status ) & 0x1)) -ne 0 ]  && echo "pechyaJl bka_car" > /dev/console
echo $fmt > /dev/console
fw_setenv TP9950type $fmt
;;
 3 )

echo "1920x1080_25fps" > /dev/console

fw_setenv TP9950res '1920x1080_25fps'
changeINI $(fw_printenv -n TP9950res | tr 'x_' ' ')

sleep 2
status=`ipctool2 i2cget 0x88 0x01`
[ $((($status >> 4) & 0x1)) -ne 1 ]  ||  [ $((($status ) & 0x1)) -ne 0 ]  && setType9950.sh ahd_1920x1080_25fps  && fmt='ahd'
sleep 2
status=`ipctool2 i2cget 0x88 0x01`
[ $((($status >> 4) & 0x1)) -ne 1 ]  ||  [ $((($status ) & 0x1)) -ne 0 ]  && setType9950.sh cvi_1920x1080_25fps  && fmt='cvi'
sleep 2
status=`ipctool2 i2cget 0x88 0x01`
[ $((($status >> 4) & 0x1)) -ne 1 ]  ||  [ $((($status ) & 0x1)) -ne 0 ]  && setType9950.sh tvi_1920x1080_25fps  && fmt='tvi'
status=`ipctool2 i2cget 0x88 0x01`
[ $((($status >> 4) & 0x1)) -ne 1 ]  && echo "pechyaJl bka_lock" > /dev/console
[ $((($status ) & 0x1)) -ne 0 ]  && echo "pechyaJl bka_car" > /dev/console
echo $fmt > /dev/console
fw_setenv TP9950type $fmt
;;
 2 )

echo "1920x1080_30fps" > /dev/console

fw_setenv TP9950res '1920x1080_30fps'
changeINI $(fw_printenv -n TP9950res | tr 'x_' ' ')

sleep 2
status=`ipctool2 i2cget 0x88 0x01`
[ $((($status >> 4) & 0x1)) -ne 1 ]  ||  [ $((($status ) & 0x1)) -ne 0 ]  && setType9950.sh ahd_1920x1080_30fps && fmt='ahd'
sleep 2
status=`ipctool2 i2cget 0x88 0x01`
[ $((($status >> 4) & 0x1)) -ne 1 ]  ||  [ $((($status ) & 0x1)) -ne 0 ]  && setType9950.sh cvi_1920x1080_30fps && fmt='cvi'
sleep 2
status=`ipctool2 i2cget 0x88 0x01`
[ $((($status >> 4) & 0x1)) -ne 1 ]  ||  [ $((($status ) & 0x1)) -ne 0 ]  && setType9950.sh tvi_1920x1080_30fps && fmt='tvi'
status=`ipctool2 i2cget 0x88 0x01`
[ $((($status >> 4) & 0x1)) -ne 1 ]  && echo "pechyaJl bka_lock" > /dev/console
[ $((($status ) & 0x1)) -ne 0 ]  && echo "pechyaJl bka_car" > /dev/console
echo $fmt > /dev/console
fw_setenv TP9950type $fmt
;;
 1 )
echo "ahd_1280x720_50fps" > /dev/console
;;
 0 )
echo "ahd_1280x720_60fps" > /dev/console
;;

esac

oldtype=$type
gpio clear 69       > /dev/null     ###  led on

if [[ "$oldres" != "$(fw_printenv -n TP9950res)" ]]; then
echo "new resolution, restart majestic" > /dev/console
killall -1 majestic
fi

else 
gpio clear 69          > /dev/null                            ##  led off
fi
fi
fi
sleep 1
done
