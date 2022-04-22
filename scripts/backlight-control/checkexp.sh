#!/bin/sh
login=$(cat /etc/httpd.conf | grep cgi-bin | cut -d':' -f2)
pass=$(cat /etc/httpd.conf | grep cgi-bin | cut -d':' -f3)
chtime=10 #change time to check exptime
chexp=50 #change exptime threshold (40-80)
day=1

while true; do

exp=$(curl -s http://localhost/metrics | grep ^isp_exptime | cut -d' ' -f2)
bri=`expr $exp / 1000`
echo $bri

    if [ $bri -gt $chexp -a $day -eq 1 ] ;then
	day=0
	curl -u $login:$pass http://localhost/night/on
    fi
	
	if [ $bri -le $chexp -a $day -eq 0 ] ;then
	day=1
	curl -u $login:$pass http://localhost/night/off
    fi

sleep $chtime
done