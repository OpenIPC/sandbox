Мини гайд по подключению датчика температуры Dallas ds18b20 к камере на SoC GK7205V300 (плата G6S) с матрицой IMX335, используя прошивку OpenIPC.
0) нам потребуется скомпилированный бинарник под нужное железо https://github.com/OpenIPC/firmware/tree/master/general/package/w1-ds18b20
Описание использования из репозитория:
![Описание использования из репозитория](https://github.com/dioxyde2023/sandbox/blob/main/scripts/temperature-sensor-ds18b20/ds1820binary.gif)


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
![pinout](https://github.com/dioxyde2023/sandbox/blob/main/scripts/temperature-sensor-ds18b20/g6s.gif)

Также необходимо припаять резистор - подтяжку номиналом 4,7 кОм (472) между средним выводом и выводом питания. Я припаял смд вариант прямо на ноги датчика.

![подтяжка](https://github.com/dioxyde2023/sandbox/blob/main/scripts/temperature-sensor-ds18b20/ds18b20.jpg)

Pinout ds18b20:

![ds18b20 pinout](https://github.com/dioxyde2023/sandbox/blob/main/scripts/temperature-sensor-ds18b20/ds18b20dtsh.GIF)

Я впаял колодку к пятакам UART, но пятаков 3, а колодка на 4 пина. Крайний 4й я загнул и припаял к нему провод и соединил с +3.3V.

![Вот такой комплект](https://github.com/dioxyde2023/sandbox/blob/main/scripts/temperature-sensor-ds18b20/mod_pcb.jpg)
![Вот такой комплект](https://github.com/dioxyde2023/sandbox/blob/main/scripts/temperature-sensor-ds18b20/mod_pcb1.jpg)
![Вот такой комплект](https://github.com/dioxyde2023/sandbox/blob/main/scripts/temperature-sensor-ds18b20/wiring.jpg)

![Вот такой комплект](https://github.com/dioxyde2023/sandbox/blob/main/scripts/temperature-sensor-ds18b20/ds18b20-1.jpg)
![Вот такой комплект](https://github.com/dioxyde2023/sandbox/blob/main/scripts/temperature-sensor-ds18b20/ds18b20-3.jpg)

![Камера](https://github.com/dioxyde2023/sandbox/blob/main/scripts/temperature-sensor-ds18b20/cam.jpg)
![Камера](https://github.com/dioxyde2023/sandbox/blob/main/scripts/temperature-sensor-ds18b20/cam2.jpg)
![Камера](https://github.com/dioxyde2023/sandbox/blob/main/scripts/temperature-sensor-ds18b20/cam3.jpg)
![Камера](https://github.com/dioxyde2023/sandbox/blob/main/scripts/temperature-sensor-ds18b20/cam4.jpg)



Немного о gpio:

```
0_2 = 0*8+2 = 2
8_2 = 8*8+2 = 66
```
С помощью ipctool reginfo

```
ipctool reginfo

muxctrl_reg0 0x100c0000 0x1 GPIO0_1 [UART0_RXD]
muxctrl_reg1 0x100c0004 0x1 GPIO0_2 [UART0_TXD]

```
 
можно посмотреть все доступные режимы на плате. Последний параметр - точное название.

![gpio](https://github.com/dioxyde2023/sandbox/blob/main/scripts/temperature-sensor-ds18b20/gpio.jpg)


Прочее:

Бинарный файл w1-ds18b20 для gk7205v200 - https://github.com/dioxyde2023/sandbox/blob/main/scripts/temperature-sensor-ds18b20/w1-ds18b20-gk7205v200



