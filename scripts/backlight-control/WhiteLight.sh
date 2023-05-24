#!/bin/sh
#
# Majestic settinfs for HI3516EV300 board from XM vendor
#
# nightMode:
#   enabled: true     #должен быть включён
#   irCutPin1: 11     #должен быть корректно установлен
#   irCutPin2: 10     #должен быть корректно установлен
#   backlightPin: 52  #должен быть корректно установлен
#
# Доделать: 
# 1. Отслеживать режим nightMode камеры и соответсвенно устанавливать led_state (возможно с задержкой)
# или всегда устанавливать led_on за пределами диапазона гистерезис, а не единежды по фронту как сейчас?

again_high_target=17000 #уровень усиления камеры при котором необходимо включить подсветку
again_low_target=6000 #должен быть >, чем при включённой подсветки и недостаточном освещении &
                      #должен быть <, чем при включённой подсветки и достаточном освещении
pollingInterval=5     #задержка переключения, (секунд)
again_led_on=0
again_led_off=0

login=$(cat /etc/httpd.conf | grep cgi-bin | cut -d':' -f2)
pass=$(cat /etc/httpd.conf | grep cgi-bin | cut -d':' -f3)

led_on(){
#        curl -u $login:$pass http://localhost/night/on && \
        led_state=1 && \
        echo LIGHT IS ON
  echo 1 > /sys/class/gpio/gpio$(cli -g .nightMode.backlightPin)/value
}

led_off(){
        curl -u $login:$pass http://localhost/night/off && \
        led_state=0 && \
        echo LIGHT IS OFF
  echo 0 > /sys/class/gpio/gpio$(cli -g .nightMode.backlightPin)/value
}

main(){

        echo "...................."
        echo "Watching at isp_again > ${again_high_target} to LED ON"
        echo "Watching at isp_again < ${again_low_target} to LED OFF"
        echo "Polling interval: ${pollingInterval} sec"
        echo "...................."

        sleep 10
        led_off
        sleep ${pollingInterval}

        while true; do

                [ $led_state == 1 ] && \
                again_led_on=$(curl -s http://localhost/metrics | awk '/^isp_again/ {print $2}') && \
                again_led_off=0 || \
                again_led_off=$(curl -s http://localhost/metrics | awk '/^isp_again/ {print $2}')

                echo "again_led_off: "$again_led_off
                echo "again_led_on: "$again_led_on

                if [ $again_led_off -gt $again_high_target ] || [ $again_led_on -gt $again_low_target ];then

                        [ $led_state == 0 ] && \
                        led_on || \
                        echo "Light is still ON. Nothing changed. Continue"

                else

                        [ $led_state == 1 ] && \
                        led_off || \
                        echo "Light is still OFF. Nothing changed. Continue"
                fi

                sleep ${pollingInterval}
                echo "...................."
        done
}

main
