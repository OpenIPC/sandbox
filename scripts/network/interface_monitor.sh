#!/bin/sh

monitor_interface () {
        local fileoperstate=/sys/class/net/"$1"/operstate
        local state oldstate=$(cat "$fileoperstate")

        while sleep 2; do
                state=$(cat "$fileoperstate")
                if [ "$oldstate" = "$state" ]; then
                        continue
                fi
                oldstate="$state"
                echo "interface $1 is $state"
                case "$state" in
                        down | lowerlayerdown)
                                kill -s SIGUSR2 `cat /var/run/udhcpc.$1.pid`
                                ;;
                        up)
                        kill -s SIGUSR1 `cat /var/run/udhcpc.$1.pid`
                                ;;
                        esac
        done
}

monitor_interface "$1"
