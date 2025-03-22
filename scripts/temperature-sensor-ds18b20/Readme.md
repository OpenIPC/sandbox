Мини гайд по подключению датчика температуры Dallas ds18b20 к камере на SoC GK7205V300 (плата G6S) с матрицой IMX335, используя прошивку OpenIPC.

1) создаем скрипт /usr/sbin/ev_dallas, он есть в этом репо.
```
vi /usr/sbin/ev_dallas
```
содержимое
```
#!/bin/sh
# EVOL DEVICES ev_dallas script ver. 2025022-1700
# It getting data from temperature sensor Dallas ds18b20
# Tested on SoC's - goke gk7205v300
#
# ds18b20 data pin connected to TX pin of G6S PCB (socket J2 pin #2)
# ds18b20 + pin connected to 3.3V pin of G6S PCB (socket J3 pin #12)
# ds18b20 - pin connected to GND pin of G6S PCB (socket J2 pin #3)
#
#     Sensor ds18b20 pinout
#        --------------
#        |  ds18b20   |
#        --------------
#        |     |      |
#       GND   DATA  +3.3V
#
# CONST
UNITS=${1}
#
ipctool gpio mux 2 GPIO0_2
if test "$UNITS" = "-u"; then
        w1-ds18b20 -base 0x120B0000 -gpio 2 2>&1 | awk '{print $3 " C"}'

else
        w1-ds18b20 -base 0x120B0000 -gpio 2 2>&1 | awk '{print $3}'
fi
ipctool gpio mux 2 UART0_TXD
```
2) делаем его исполняемым
```
chmod +x /usr/sbin/ev_dallas
```
3) создаем скрипт /usr/sbin/ev_mqtt_ds18b20, он есть в этом репо.
```
vi /usr/sbin/ev_mqtt_ds18b20
```
содержимое
```
#!/bin/sh
#
# EVOL DEVICES MQTT SENDER SCRIPT
# VER
VER="EVOL DEVICES MQTT SENDER SCRIPT v.20250322-1728"
# SETTINGS
MQTT_SRV=${1:-"YOUR_MQTT_SERVER"}
MQTT_P=1883
MQTT_USER=YOUR_MQTT_USERNAME
MQTT_PASS=YOUR_MQTT_PASSWORD
MQTT_TOPIC=${2:-"YOUR_MQTT_TOPIC"}
# VARS
#
UPTIME=$(uptime | sed -r 's/^.+ up ([^,]+), .+$/\1/')
SINCE=$(uptime -s)
SYS_FREE=$(free | awk '/Mem:/ {print $4}' | egrep '^[-+]?[0-9]*\.?[0-9]+$')
SYS_TOTAL=$(free | awk '/Mem:/ {print $2}' | egrep '^[-+]?[0-9]*\.?[0-9]+$')
TEMP=$(ipcinfo -t)
TEMPDALLAS0=$(ev_dallas)

if test "$MQTT_SRV" = "-h"; then
  echo "================================================" && echo $VER && echo "================================================"
  echo "Usage: [server] [topic]" && echo "Example: ./ev_mqtt_ds18b20 mymqtt.org my_root_topic" && echo "Example: ./ev_mqtt 192.168.0.5 my_2root_topic"
else
        # SEND
        #
        mosquitto_pub -h "${MQTT_SRV}" -p "${MQTT_P}" -u "${MQTT_USER}" -P "${MQTT_PASS}" -t "${MQTT_TOPIC}/uptime" -m "${UPTIME}" -i "${MQTT_TOPIC}"
        mosquitto_pub -h "${MQTT_SRV}" -p "${MQTT_P}" -u "${MQTT_USER}" -P "${MQTT_PASS}" -t "${MQTT_TOPIC}/since" -m "${SINCE}" -i "${MQTT_TOPIC}"
        mosquitto_pub -h "${MQTT_SRV}" -p "${MQTT_P}" -u "${MQTT_USER}" -P "${MQTT_PASS}" -t "${MQTT_TOPIC}/freeheapmemory" -m "${SYS_FREE}000" -i "${MQTT_TOPIC}"
        mosquitto_pub -h "${MQTT_SRV}" -p "${MQTT_P}" -u "${MQTT_USER}" -P "${MQTT_PASS}" -t "${MQTT_TOPIC}/maxheapmemory" -m "${SYS_TOTAL}000" -i "${MQTT_TOPIC}"
        mosquitto_pub -h "${MQTT_SRV}" -p "${MQTT_P}" -u "${MQTT_USER}" -P "${MQTT_PASS}" -t "${MQTT_TOPIC}/temp" -m "${TEMP}" -i "${MQTT_TOPIC}"
        mosquitto_pub -h "${MQTT_SRV}" -p "${MQTT_P}" -u "${MQTT_USER}" -P "${MQTT_PASS}" -t "${MQTT_TOPIC}/tempDallas0" -m "${TEMPDALLAS0}" -i "${MQTT_TOPIC}"

fi

exit 0
```
4) делаем его исполняемым
```
chmod +x /usr/sbin/ev_mqtt_ds18b20
```
5) подключаем сам датчик ds18b20 к плате
```
ds18b20 data pin connected to TX pin of G6S PCB (socket J2 pin #2)
ds18b20 + pin connected to 3.3V pin of G6S PCB (socket J3 pin #12)
ds18b20 - pin connected to GND pin of G6S PCB (socket J2 pin #3)
```
