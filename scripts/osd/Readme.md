Мини гайд для настройки внешнего OSD демона для GOKE v200-v300:
1) качаем бинарник демона в камеру, выполнив в консоли устройства: 
```
curl -s -L https://github.com/OpenIPC/osd/releases/download/latest/osd-goke -o /usr/sbin/osd_server
```
2) делаем исполняемым этот файл, выполнив следующую команду:
```
chmod 755 /usr/sbin/osd_server
```
3) далее в консоли устройства редактируем файл /etc/rc.local c помощью редактора vi, выполнив следующее:
```
vi /etc/rc.local
```
4) нажав i переходим в режим правки и вписываем перед строкой с "exit 0" следующее:
```
(sleep 10 ; osd_server > /dev/null 2>&1) &
```
5) нажимаем клавишу "ESC", потом наберем на клавитатуре :wq , тем самым запишем данные в файл и закроем его
6) создаем в директории /usr/sbin/ файл с именем ev_mqttsub, выполнив в консоли устройства следующую команду:
```
vi /usr/sbin/ev_mqttsub
```
7) вставляем из буфера обмена (нажав ПКМ в SSH клиенте) следующий текст (файл этот будет обнародаван в песочнице): 
```
#!/bin/sh
VER="EVIL DEVICES MQTT SUBSCRIBE AND OSD SCRIPT v.20241203-2100"
# MQTT SETTINGS
MQTT_SRV="SERVER_ADDRESS"
MQTT_P=1883
MQTT_USER="MQTT_USER"
MQTT_PASS="MQTT_PASS"
MQTT_TOPIC="MQTT_TOPIC"
# use %20 instead of spaces
MQTT_OSD_T1="Temp%20OSD1:%20"
MQTT_OSD_T2="Temp%20room:%20"
# OSD SETTINGS
FONT_SIZE=34
POSX=16
# - initial Y coordinates for 5M sensor
INITIAL_POSY=1166 
# VARS
VERBOSE=${1:-"-q"}
URI="http://127.0.0.1:9000/api/osd"
COMMAND="-C 1 -h ${MQTT_SRV} -p ${MQTT_P} -u ${MQTT_USER} -P ${MQTT_PASS} -t ${MQTT_TOPIC}"
CPU=$(cat /proc/loadavg | sed "s/ /%20/g")
SINCE=$(uptime -s | sed "s/ /%20/g")
SYS_FREE=$(free | awk '/Mem:/ {print $4}' | egrep '^[-+]?[0-9]*\.?[0-9]+$')
SYS_TOTAL=$(free | awk '/Mem:/ {print $2}' | egrep '^[-+]?[0-9]*\.?[0-9]+$')
TEMP=$(ipcinfo -t)
# VERBOSE OUT OR NOT
if [ "-verbose" = "$VERBOSE" ]; then
	VERBOSE=""
fi
# SHOW HELP
if [ "-h" = "$VERBOSE" ]; then
	echo $VER
	exit 0
fi
# CALCULATING OSD posy FOR EACH TEXT LINE
let "POSY1 = INITIAL_POSY + $FONT_SIZE"
let "POSY2 = $POSY1 + $FONT_SIZE"
let "POSY3 = $POSY2 + $FONT_SIZE"
let "POSY4 = $POSY3 + $FONT_SIZE"
let "POSY5 = $POSY4 + $FONT_SIZE"
let "POSY6 = $POSY5 + $FONT_SIZE"
let "POSY7 = $POSY6 + $FONT_SIZE"
# SUBSCRIBE AND SHOW OSD
WG_PARAM="-T1 $VERBOSE -O /dev/null"
# - CHIP TEMP
wget $WG_PARAM "$URI/3?posx=$POSX&posy=$POSY3&size=$FONT_SIZE&text=Temp%20chip:%20$TEMP%20C"
# - FREE MEMORY
wget $WG_PARAM "$URI/4?posx=$POSX&posy=$POSY4&size=$FONT_SIZE&text=Mem%20free:%20$SYS_FREE%20Kb"
# - CPU USAGE
wget $WG_PARAM "$URI/5?posx=$POSX&posy=$POSY5&size=$FONT_SIZE&text=CPU:%20$CPU"
# - BOOT TIME (uptime -s)
wget $WG_PARAM "$URI/6?posx=$POSX&posy=$POSY6&size=$FONT_SIZE&text=Boot:%20$SINCE"
# - ISP_AGAIN
OUT=$(wget -T1 -q -O - localhost/metrics/isp | grep ^isp_again | cut -d' ' -f2)
wget $WG_PARAM "$URI/7?posx=$POSX&posy=$POSY7&size=$FONT_SIZE&text=Isp_again:%20$OUT"
# - MQTT SUBSCRIPTION: can take some time
#  - OSD TEMP1 # any your MQTT topic with some value
OUT=$(mosquitto_sub ${COMMAND}/temp1)
wget $WG_PARAM "$URI/1?posx=$POSX&posy=$POSY1&size=$FONT_SIZE&text=$MQTT_OSD_T1$OUT%20C"
#  - OSD TEMP2 # any your MQTT topic with some value
OUT=$(mosquitto_sub ${COMMAND}/temp2)
wget $WG_PARAM "$URI/2?posx=$POSX&posy=$POSY2&size=$FONT_SIZE&text=$MQTT_OSD_T2$OUT%20C"
exit 0
```
8) Далее даем права на запуск этому файлу, выполнив в консоли устройства:
```
chmod 755 /usr/sbin/ev_mqttsub
```

9) пропишем в планировщик CRON наш скрипт для запуска каждую минуту, выполнив команду:
```
crontab -e
```

10) далее войдем в режим редактирования, нажав i на клавиатуре

11) в самый конец вставим (через ПКМ в SSH клиенте) следующее:
```
*/1   *     *     *     *    /usr/sbin/ev_mqttsub
```

12) Далее жмем клавишу "ESC", потом наберем на клавитатуре :wq , тем самым запишем данные в файл и закроем его

13) перезагружаем камеру:
```
reboot
```
14) Если все успешно - наслаждаемся :)
