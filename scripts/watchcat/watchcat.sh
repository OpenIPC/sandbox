#!/bin/sh
# This is script is based on OpenWRT's watchcat idea. The key principel is that if the camera cannot connecto a WIFI it is worthless so it willl try by all means to connect. Depending on the configuration, it will first try to restart the network or connecto to alternative SSIDs. If all this fails, after a couple of tries, it will reboot the camera.

if [ -z "$1" ]; then
  echo "Usage: <host_to_ping> [<ssid> <psk>]"
  echo "If ssid and psk are provided, they will be added as a backup wifi"
  exit 1
fi

failure_period="120"
ping_hosts="$1"
ping_frequency_interval="30"

while true; do
    # account for the time ping took to return. With a ping time of 5s, ping might take more than that, so it is important to avoid even more delay.
    time_now="$(cat /proc/uptime)"
    time_now="${time_now%%.*}"
    time_diff="$((time_now - time_lastcheck))"

    [ "$time_diff" -lt "$ping_frequency_interval" ] && sleep "$((ping_frequency_interval - time_diff))"

    time_now="$(cat /proc/uptime)"
    time_now="${time_now%%.*}"
    time_lastcheck="$time_now"

    for host in $ping_hosts; do
        ping_result="$(
            ping -c 1 "$host" &> /dev/null
            echo $?
        )"

        if [ "$ping_result" -eq 0 ]; then
            # echo "watchcat[$$]" "Check ok"
            time_lastcheck_withinternet="$time_now"
        else
            echo "watchcat[$$]" "Could not reach $host for $((time_now - time_lastcheck_withinternet)). Rebooting after reaching $failure_period" > /dev/kmsg
            if [ $# -eq 3 ]; then
                # Try adding a backup access point
                /mnt/tf/tools/add_backup_wifi.sh "$2" "$3" > /dev/kmsg
            fi    
            # Restart wifi (only on OpenIPC)
            # /etc/init.d/S40network restart > /dev/kmsg        
        fi
    done

    [ "$((time_now - time_lastcheck_withinternet))" -ge "$failure_period" ] && reboot -f > /dev/kmsg
done