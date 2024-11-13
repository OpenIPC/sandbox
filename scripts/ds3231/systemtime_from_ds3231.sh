#!/bin/sh

# read in sec, min, etc from ds3231 and store in variable 
sec=$(i2cget -y 0 0x68 0x00) 
min=$(i2cget -y 0 0x68 0x01) 
hour=$(i2cget -y 0 0x68 0x02) 
day=$(i2cget -y 0 0x68 0x04) 
month=$(i2cget -y 0 0x68 0x05) 
year=$(i2cget -y 0 0x68 0x06) 

# output of i2cget is of form 0x00, save on last two characters 
sec=${sec: -2} 
min=${min: -2} 
hour=${hour: -2} 
day=${day: -2} 
month=${month: -2} 
year=${year: -2} 

# store all variables into strings to set time with 
datee="20${year}${month}${day}" 
timee="${hour}:${min}:${sec}" 

# set system time 
date -D %Y%m%d -s "$datee" 
date +%T -s "$timee"
