#!/bin/sh

## set i2c init to TP9950  after majestic was started
killall test_type.sh
echo 'set '$(fw_printenv -n TP9950type)_$(fw_printenv -n TP9950res)' mode after majestic ' > /dev/console
setType9950.sh $(fw_printenv -n TP9950type)_$(fw_printenv -n TP9950res)
sleep 3 
test_type.sh &