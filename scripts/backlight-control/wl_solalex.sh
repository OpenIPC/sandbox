#!/bin/sh
login=$(cat /etc/httpd.conf | grep cgi-bin | cut -d':' -f2)
pass=$(cat /etc/httpd.conf | grep cgi-bin | cut -d':' -f3)
chtime=300 #change time to check isp_again, default 300 sec
chexp=20 #change isp_again threshold (15-30)
day=1

while true; do

exp=$(curl -s http://localhost/metrics | grep ^isp_again | cut -d' ' -f2)
bri=`expr $exp / 1000`
logger "Analog gain $bri"

    if [ $bri -gt $chexp -a $day -eq 1 ] ;then
	day=0
	curl -u $login:$pass http://localhost/night/on
	logger "Night mode ON"
    fi
	
	if [ $bri -le $chexp -a $day -eq 0 ] ;then
	day=1
	curl -u $login:$pass http://localhost/night/off
	logger "Night mode OFF"
    fi

sleep $chtime
done
