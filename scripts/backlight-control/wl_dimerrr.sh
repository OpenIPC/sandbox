#!/bin/sh

# EV200
# PWM1 base 0x12080020 | iocfg 0x100c0010
# PWM3 base 0x12080060 | iocfg 0x120c020
# EV300
# PWM1 base 0x12080020 | iocfg 0x100c0010
# PWM3 base 0x12080060 | iocfg 0x120c020
devmem 0x100c0010 32 0x1001 # iocfg_reg4 switch pin to PWM mode
devmem 0x120101bc 32 0x282 # Write 0x2 to PERI_CRG111 bit[9:8] to select the 24 MHz clock as the PWM clock source,and enable the PWM clock.

warmlight() {
freq=${1:-400}
duty=${2:-72}
freq_hex=$(expr 24000000 / ${freq} | xargs printf '%x\n')
duty_hex=$(expr 24000000 / ${freq} \* ${duty} / 100 | xargs printf '%x\n')
echo "FREQ: ${freq}"
echo "DUTY: ${duty}"

# Disable output before init. (PWM1_CTRL)
# Later tests showed this isn't needed ?!
# devmem 0x1208002c 32 0x0

# Frequency
# Cycle = 24 MHz/0.4 kHz = 60000 (0x000EA60)
# (400kHz, static, as XM uses) . Write to PWM0_CFG0
devmem 0x12080020 32 0x${freq_hex}

# Duty Cycle
# Number of high levels = Cycle x Duty ratio = 43500 x 72.5% = 43500 (0x00016A8) 
# Write to PWM0_CFG1.
devmem 0x12080024 32 0x${duty_hex}

# Number of square waves output by PWM, not needed if PWM1_CTRL=0x5
# devmem 0x12080028 32 0xA

# Enable and always output, setting number above is not needed. PWM1_CTRL 
devmem 0x1208002c 32 0x5

}

vir() {
# Variable IR
# GPIO 2_0
devmem 0x120c0020 32 0x432
devmem 0x120b2400 32 0x1
devmem 0x120b23fc 32 0xF1 # GPIO HIGH, shoud be OR'ed to change first bit
# devmem 0x120b23fc 32 0xF0 # GPIO LOW, shoud be OR'ed to change first bit

# GPIO 6_4
devmem 0x112C0074 32 0x432
devmem 0x120b6400 32 0x1
devmem 0x120b63fc 32 0xF1 # GPIO HIGH, shoud be OR'ed to change first bit
# devmem 0x120b23fc 32 0xF0 # GPIO LOW, shoud be OR'ed to change first bit
}


while true; do

if [ $# -lt 2 ]; then
exp=$(curl -s http://localhost/metrics | grep ^isp_exptime | cut -d' ' -f2)
bri=`expr $exp / 1000`
echo $bri

    if [ $bri -gt 50 ];then
    warmlight 400 ${bri}
    else
    warmlight 400 0
    fi

else
warmlight $1 $2
exit 0
fi

sleep 5
done
