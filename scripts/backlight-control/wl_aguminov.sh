#!/bin/sh

# скрипт работает с автоматическим режимом экспозиции
# для контроля освещенности используется параметр усиления матрицы a_gain - чем он выше тем ниже освещенность
# соответсвенно задается верхний и нижний порог для включения/выключения подсветки - again_high_target и again_low_target
# again_high_target и again_low_target - подбираются опытным путем
# алгоритм: если подсветка выключена - мониторится a_gain и сравнивается с верхним порогом - again_high_target, если выше порога - включаем подсветку
# если подсветка включена, a_gain сравнивается с нижним порогом, при его достижении подсветка выключается

# скрипт скопировать в камеру и дать права на исполнения
# scp wl.sh root@IP_NUMBER:/FOLDER/
# chmod +x /FOLDER/wl.sh

again_high_target=14000
again_low_target=6000
pollingInterval=1
led_state=0
again_led_on=0
freq=${60000-400}                                                                                       
duty=${0-72} 

freq_hex=$(expr 24000000 / ${freq} | xargs printf '%x\n')                                            
duty_hex=$(expr 24000000 / ${freq} \* ${duty} / 100 | xargs printf '%x\n') 

PWM_MODE="0x00001001"
NORMAL_MODE="0x00001000" 

get_gpio_mode(){
	GPIO_MODE=$(devmem 0x100c0010 32)
}

get_pwm_duty(){
    PWM_DUTY=$(devmem 0x12080024 32)
}

set_gpio_to_normal_mode(){
	get_gpio_mode
	[ $GPIO_MODE != NORMAL ] && \
        devmem 0x100c0010 32 $NORMAL_MODE && \
        echo "switch GPIO mode to NORMAL" || \
        echo Error: cant set normal mode
}

set_gpio_to_pwm_mode(){
	get_gpio_mode                             
    [ $GPIO_MODE != PWM_MODE ] && \
        devmem 0x100c0010 32 $PWM_MODE && \
        echo "set GPIO mode to PWM" || \
        echo Error: cant set pwm mode
}

set_gpio_clock(){
	devmem 0x120101bc 32 0x282 && \
    echo "set GPIO clock to 24MHz" || \
    echo Error: cant set clock
}

set_pwm_frequncy(){
	freq=${1:-400}                                                                                       
	freq_hex=$(expr 24000000 / ${freq} | xargs printf '%x\n')
	devmem 0x12080020 32 0x${freq_hex} && echo "set Frequency: ${freq} = ${freq_hex}"
}

set_pwm_duty(){
	duty=${1:-72}
	duty_hex=$(expr 24000000 / ${freq} \* ${duty} / 100 | xargs printf '%x\n')
    get_pwm_duty
	devmem 0x12080024 32 0x${duty_hex} && echo "set Duty: ${duty} = ${duty_hex} = ${PWM_DUTY}" 
}

apply_settings(){
	devmem 0x1208002c 32 0x5 && \
	echo "Apply setting" || \
    echo Error: cant apply setting
}

led_on(){                                                                           
	set_pwm_duty 100 && \
	apply_settings && \
    led_state=1 && \
	echo LIGHT IS ON                                                                         
}                                                                                        
                                                                                         
led_off(){
	set_pwm_duty 0 && \
    apply_settings && \
    led_state=0 && \
    echo LIGHT IS OFF                                                        
}

get_led_status(){
    [ $(devmem 0x12080024 32) == "0x0000EA60" ] && \
        led_state=1 || \
        led_state=0 
}


deinit(){
    echo "Deinit setup"
    set_gpio_to_normal_mode
}

init(){
    echo "Setup GPIO"
	set_gpio_to_pwm_mode && \
	set_gpio_clock && \
	set_pwm_frequncy && \
	set_pwm_duty && \
	apply_settings || \
    echo Error: cant init

    echo Measuring a_gain

    led_off
    sleep 2
    again_led_off=$(curl -s http://localhost/metrics | grep ^isp_again | cut -d' ' -f2)
    echo "A_GAIN with led off: ${again_led_off}"

    led_on
    sleep 2
    again_led_on=$(curl -s http://localhost/metrics | grep ^isp_again | cut -d' ' -f2)
    echo "A_GAIN with led on: ${again_led_on}"


}

main(){
    clear
    init


    echo "...................."
    echo "Watching at isp_again > ${again_high_target} to LED ON"
    echo "Watching at isp_again < ${again_low_target} to LED OFF"
    echo "Polling interval: ${pollingInterval} sec"
    echo "...................."



    while true; do

            get_led_status && \
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
