# One Minute Movie

1. you need an sd card, or nfs share, mounted into `/mnt/mmcblk0p1/`

2. majestic settings to store one min movies:

```
cli -s .records.enabled true
cli -s .records.path /mnt/mmcblk0p1/recordings/%F-%H-%M.mp4
```

3. enable motion detection, select regions

4. check extensions -> telegram for correct settings

5. put the `telegram` script into `/usr/sbin/` (its based on current (2024-07-11) firmware's script, added comand line parameter `send_queue` and a small 'caption' refactoring)

6. put the `motion.sh` script into `/usr/sbin/`

7. `crontab -e`, add this line:

```
*  *  *  *  *  /usr/sbin/telegram send_queue
```
