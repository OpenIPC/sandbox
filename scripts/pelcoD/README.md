## Edition by @sansarus

add  18x motorized lense support.  pelcoD commands. Port and baud config at btzoom script   

change motor.cgi at /var/www/cgi-bin/p/

add btzoom to /usr/bin

fw_setenv  ptz true   (need full reboot)

## Edition by @FlyRouter

Run the commands in the console for some fun:

```
curl -o /var/www/cgi-bin/p/motor.cgi https://raw.githubusercontent.com/OpenIPC/sandbox/refs/heads/main/scripts/pelcoD/motor.cgi
curl -o /usr/bin/btzoom https://raw.githubusercontent.com/OpenIPC/sandbox/refs/heads/main/scripts/pelcoD/btzoom
chmod +x /usr/bin/btzoom
fw_setenv ptz true
reboot
```
