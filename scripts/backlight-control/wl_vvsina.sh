#!/bin/sh

again_high_target=17000
again_low_target=1500
pollingInterval=4
led_state=0
again_led_on=0
again_led_off=0

led_on(){
        curl http://admin:123456@127.0.0.1/night/on && \
        led_state=1 && \
        echo LIGHT IS ON
}

led_off(){
        curl http://admin:123456@127.0.0.1/night/off && \
        led_state=0 && \
        echo LIGHT IS OFF
}

main(){

        echo "...................."
        echo "Watching at isp_again > ${again_high_target} to LED ON"
        echo "Watching at isp_again < ${again_low_target} to LED OFF"
        echo "Polling interval: ${pollingInterval} sec"
        echo "...................."

        sleep 10
        led_off

        while true; do

                [ $led_state == 1 ] && \
                again_led_on=$(curl -s http://localhost/metrics | grep ^isp_again | cut -d' ' -f2) && \
                again_led_off=0 || \
                again_led_off=$(curl -s http://localhost/metrics | grep ^isp_again | cut -d' ' -f2)

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
