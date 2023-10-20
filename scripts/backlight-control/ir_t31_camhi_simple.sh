#!/bin/sh

again_high_target=120
again_low_target=50
pollingInterval=4
led_state=0
again_led=0

led_on(){
	curl http://localhost/night/on && \
	echo LIGHT IS ON
}

led_off(){
	curl http://localhost/night/off && \
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

		led_state=$(curl -s http://localhost/metrics | grep ^night_enabled  | cut -d' ' -f2)
		again_led=$(curl -s http://localhost/metrics | grep ^isp_again | cut -d' ' -f2)

		echo "again_led: "$again_led

		if [ $again_led -lt $again_low_target -a $led_state -eq 1 ] ;then
			led_off
		fi

		if [ $again_led -gt $again_high_target -a $led_state -eq 0 ] ;then
			led_on
		fi

		sleep ${pollingInterval}
		echo "...................."
        done
}

main
