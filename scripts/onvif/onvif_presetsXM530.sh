#!/bin/ash

# This script is designed for use on an XM530 camera running the OpenIPC software (with 
# onvif_simple_server as part of the build) to provide the required information back to 
# the ptz_service.c application, which when compiled is part of the onvif_simple_server executable

# OnvifSimpleServer is designed to execute a specific command through a lookup in onvif.conf file
# when the onvif client sends a specific xml request e.g. get_presets. This script has the  
# functions required to respond to these requests. 

# The options to handle are get_position, move_preset, goto_home_position, set_preset, 
# set_home_position, remove_preset, get_presets.

# All settings are using absolute x,y,z values not degrees

# Not designed to be run direct from the cmd line however by 
# specifying the correct function can be for testing e.g. onvif_presetsXm530 get_position
# 
# More work is required to make this portable to other models when integrated into the OpenIPC
# camera firmware and web build 
#
# ** ToDo **
# - Add including zoom values when on a camera that supports it
# - Check how to apply this to other cameras e.g. Hikvision series
# - Investigate the build process for OpenIPC to determine 
#   where the custom files like onvif.conf should go.

# for testing make conf file local as it is tricky to debug this on the camera
# the files do not need to exist on initial use as will be built in the function if required

# PTZ_PRESETS=ptz_presets.conf #ptz presets
# PTZ_HOME=ptz_home.conf #home settings
PTZ_PRESETS=/etc/ptz_presets.conf
PTZ_HOME=/etc/ptz_home.conf

# Check if the first argument is provided as should always be used from onvif simple server scripts 
if [ -z "$1" ]; then 
    echo "This script is designed to be run from onvif simple server with arguments defined in the onvif.conf file" 
    exit 1
fi

# simple function to get json status string from XM camera
# and extract status, x and y position
getXMstatus() {
    # echo "xmstatus function"
    result=$(eval "xm-kmotor -j")    
    # result='{"status":"65535","xpos":"500","ypos":"751","unknown":"16","unknown":"0","unknown":"0"}'
    if [ -n "$result" ] ; then    #check for non empty string
        # Use IFS to parse the JSON string and extract the "status and x,y" values which we know is the 4th, 8th and 12th item
        # We could have built a for loop to check through each item but we know this will be static format
        old_IFS=$IFS 
        IFS='"' set -- $result
        IFS=$old_IFS
        # Extract the status value
        status=$(echo "$result" | awk -F'\"' '{print $4}')
        if [ "65535" = $status ] ; then
            #not moving
            moving_status="0"
        else
            moving_status="1"
        fi
        
        # Extract the x,y values"    
        xpos=$(echo "$result" | awk -F'\"' '{print $8}')
        ypos=$(echo "$result" | awk -F'\"' '{print $12}')
                
    else
        # if failed set everything to 0 values
        moving_status="0"
        xpos="0"
        ypos="0"
    fi
}

# Get command line arguments
if  [ "$1" = "get_presets" ] ; then
    # list out presets to onvif simple server

    # Check if the file exists
    if [ -f "$PTZ_PRESETS" ]; then
        # Just output the file contents to stdout i.e. response to onvif_simple_server 
        cat "$PTZ_PRESETS"
    else
        # fail silently as onvif is looking for simple list of presets as the response
        exit 1
    fi

elif  [ "$1" = "goto_home_position" ] ; then
    # get home position from ptzhome.conf in form of x,y
    # and use xm-kmotor module to goto x y

    # Check if the file exists
    if [ -f "$PTZ_HOME" ] ; then
        # get x,y values from file, it should only contain one line for the 
        # Home pos
        value=$(head -n 1 "$PTZ_HOME")
        # now get xand y values
        xpos=${value%%,*} #this leaves us with x,y[,z]
        value=${value#*,}
        ypos=${value%%,*}
        # value=${value#*,}
        # zpos=value

        #now we need to fire off the xm-kmotor command with the required goto settings
        eval "xm-kmotor -dt -x $xpos -y $ypos"
        exit 0
    else
        # fail silently as nothing built in to send back an error
        exit 1
    fi

elif  [ "$1" = "set_home_position" ] ; then
    # first we need to get the current x and y from the camera status
    # then just overwrite the file containing the homepos as this is separate to the presets.
    # We could make preset 0 home and filter it out when responding to get_presets
    # but this seems the simplest approach

    # get x,y[,z] values using our function above
    getXMstatus    
    result="$xpos,$ypos"
    # plus z here if we have zoom
    # now simply overwrite the existing file
    echo $result > "$PTZ_HOME"
    exit 0

elif [ "$1" = "move_preset" ] ; then
    # expect $2 to be the preset number passed out by onvifsimpleserver code.
    # we need to get the x,y co-ordinates out of the presets file by reading 
    # them line by line until we get to the required entry presets are stored as 1=name,x,y,z
    # there is no zoom on my XM530 and so ignored but allow being able to re-use this code with z value

    # Check if the file exists
    if [ -f "$PTZ_PRESETS" ]; then
        # Could use grep etc but looping through is easier to debug
        while IFS= read -r line
        do
            # get the preset number
            value=${line%%=*}
            if [ $2 = $value ] ; then
                # now get x,y,z values which are after the = sign and first comma after the name value
                value=${line#*,} #this leaves us with x,y,z
                xpos=${value%%,*} #this leaves us with x,y,z
                value=${value#*,}
                ypos=${value%%,*}
                # value=${value#*,}
                # zpos=value

                #now we need to fire off the xm-kmotor command with the required goto settings   
                eval "xm-kmotor -dt -x $xpos -y $ypos"
                exit 0
            fi
        done < "$PTZ_PRESETS"

    else
        # fail silently
        exit 1
    fi

elif [ $1 = "set_preset" ] ; then
    # we are passed a name for the preset and so need to get x,y,z from the camera and add to our presets file
    presetname=$2 
    
    # get x,y values using our function above
    getXMstatus
    
    #now we need to get the last row number in the presets file as the format is #=name,x,y,z
    #simplest way is to iterate through the existing lines and use the counter value for the next one

    counter=1

    #check file exists
     if [ -f "$PTZ_PRESETS" ]; then
        # looping through entries until eof last entry should be terminated with a cr
        while IFS= read -r line
        do
          counter=$((counter + 1))
        done < "$PTZ_PRESETS"
    else
        # we need to create the file to add our entry to
        > $PTZ_PRESETS
    fi
    
    #and add our new entry syntax is counter=name,x,y,z and \r
    eval "echo $counter=$presetname,$xpos,$ypos >> $PTZ_PRESETS"

    exit 0

elif [ $1 = "remove_preset" ] ; then
    # loop through preset entries to find one to remove and save rest back to the presets file. 
    # No character arrays in ash so need to use dynamic variable names
    counter=1
    preset=$2

    #check file exists
     if [ -f "$PTZ_PRESETS" ]; then
        # looping through entries until eof last entry should be terminated with a cr
        while IFS= read -r line
        do
            value=${line%%=*}
            #keep the ones that dont match the one to be deleted
            if [ $preset != $value ] ; then
                #loose the existing line number= part as we will need to renumber writing back out to the file
                presetvalue=${line#*=}
                # Assign the line to a variable with a dynamic name
                eval "ptzpreset_$counter=\"$presetvalue\""
                # for debug
                # eval "echo ptzpreset[\$counter] = \$ptzpreset_$counter"
               
                #need to remember how many values there are to be able to write them back out again
                counter=$((counter + 1))
            fi
        done < "$PTZ_PRESETS"

        # now write each one back to the file
       
       if [ $counter -gt 1 ] ; then
            counterout=1
            # Simply overwrite the existing file with the first entry
            eval "echo $counterout=\$ptzpreset_$counterout > $PTZ_PRESETS"
            counterout=$((counterout + 1))
    
            while [ "$counterout" -lt "$counter" ]
            do
                # and add the rest
                eval "echo $counterout=\$ptzpreset_$counterout >> $PTZ_PRESETS"
                counterout=$((counterout + 1))
            done
          else
            #write an empty file if we have deleted all entries
           > $PTZ_PRESETS
        fi

    else
        # fail silently
        exit 1
    fi

elif [ $1 = "get_position" ] ; then
    # needs to simply return x,y[,z]
 
    #call the function we have to get the values
    getXMstatus
    
    echo "$xpos,$ypos"
    exit 0
    
elif [ $1 = "is_moving" ] ; then
    # onvif code requires either a 0 or 1 response for moving or not
    # xm-kmotor sends 65535 for idle and other numbers for moving in get status response
    # so in the getXMStatus function above we will convert to 1 or 0 and assign to a moving_status variable
    
    #get values from camera using a common function at top of file
    getXMstatus
    
    echo "$moving_status"
    exit 0

fi
exit 0
