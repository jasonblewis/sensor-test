#!/bin/bash -e
#
# Copyright (c) 2012 Tahsin Rahman <>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.
#

# This is simple linux script to read TSL2561 luminosity (light) sensor

unset line
unset infra
unset full
unset vis
unset lux
unset time_delay
unset data_save
unset data_location
unset gain

function user {
echo "Choose data time delay (s)"
read time_delay
#if [ "$(echo "if ($time_delay > 0) 1" | bc)" -eq 1 ] &>/dev/null; then
#   time_delay=$time_delay
#else
#   echo "Invalid data or time, setting to default 0.5s"
#   time_delay=0.5s
#fi

echo "Are you measuring in really low light enviroment? 
Type 1 for Yes, 0 for NO, all other set to 0"
read gain

echo "Want to save the data? 
Type 1 for YES, 0 for NO, all other keys will be set is 0"
read data_save
if [ "$data_save" = "1" ]; then
   data_save=$data_save
   echo "Where will be the data saved?"
   read data_location
   data_location=$data_location
   else
   data_save=0
fi
}

function setup {
echo "## Setting up the sensor ##"
# Turn on the device
i2cset -y 3 0x39 0x80 0x03 b
sleep 1
# Set the timers
if [ "$gain" = "1" ]; then
   i2cset -y 3 0x39 0x81 0x12 b # 16x Gain 402ms intergration time
else
   i2cset -y 3 0x39 0x81 0x02 b # 1x Gain 402ms intergration time
fi

sleep 2

#Status Messages
if [ "$(printf "%d\n" `i2cget -y 3 0x39 0x80 b`)" = "51" ]; then
   echo "The device is online"
else
   echo "The device is offline"
   cleanup 
fi

if [ "$(printf "%d\n" `i2cget -y 3 0x39 0x81 b`)" = "18" ]; then
   echo "Set to 16x Gain"
else
   echo "Set to 1x Gain"
fi

if [ "$data_save" = "1" ]; then
   echo "Data recording enabled"
else
   echo "Data recording disabled"
fi
echo "Time between data: $time_delay"
echo ## Done setting up ##
echo "Wait for ADC to setup"
sleep 4
} # End Setup

function cleanup {
 echo ""
 echo "Escape key dected"
 
 #Turn off the device
 echo ""
 echo "Attempting to turn off the device"
 i2cset -y 3 0x39 0x80 0x00 b #Turn sensor off
 sleep 2 #Wait for a bit
 
 #Display the status of the sensor
 if [ "$(printf "%d\n" `i2cget -y 3 0x39 0x00 b`)" = "0" ]; then
    echo "The sensor is off"
    if [ "$data_save" = "1" ]; then
       echo "################################"
       echo "Recording ended at $(date +"%r")" >> $data_location
       chmod 777 $data_location
    fi
 else
    echo "The script was unable to turn off the sensor"
 fi

 exit
} #End cleanup

function calc_lux {
 lux=UND
}

function print_data { 
 #Print out all the data
 printf "$(date +"%r")  Full: $full  Infra: $infra  Visible: $vis  Lux: $lux \n"

 #Clear lines when screen buffer full
 line=`expr $line + 1`
 if [ "$line" = "22" ]; then
    clear
    line=0
 fi
}

function save_data {
 printf "$(date +"%r")  Full: $full  Infra: $infra  Visible: $vis  Lux: $lux \n" >> $data_location 
}

function collect_data {
 while [ "1" = "1" ]; do

  full=$(printf "%d\n" `i2cget -y 3 0x39 0xac w`) #CH0
  infra=$(printf "%d\n" `i2cget -y 3 0x39 0xae w`) #CH1
  if [ "$full" = "0" ]; then
     vis=0
  else
     #vis=$(expr $full - $infra)
     vis=$(echo "$full - $infra" | bc)
  fi
  calc_lux
  print_data
  
  #Check to see if the user want to save the data
  if [ "$data_save" = "1" ]; then
     save_data
  fi
  
  #ammount of time to wait till the next data
  sleep $time_delay
 done
} # End collect_data

trap cleanup SIGTSTP SIGINT SIGTTIN SIGTTOU # call cleanup on Ctrl-C

user
setup
collect_data
cleanup
