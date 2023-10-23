#!/bin/sh

plugin="motion"
source /usr/sbin/common-plugins
singleton

UNSUPPORTED="hi3516cv100 hi3516av100"
[ -n "$(echo $UNSUPPORTED | sed -n "/\b$(ipcinfo --family)\b/p")" ] &&
	log "Motion detection is not supported on your camera!" && quit_clean 1

[ "true" != "$motion_enabled" ] &&
	log "Motion detection is disabled in config!" && quit_clean 3

STOP_FILE=/tmp/motion.stop
TEMPLATE="Motion detected"
echo Starting to read metrics ... 
while [ 1 ]; do
    metrics=$(curl -s -o - http://127.0.0.1/metrics | grep md_)
    md_rects_recv_total=$(echo "$metrics" | grep -v ^# | grep md_rects_recv_total | cut -d' ' -f2)
    md_rects_acc_total=$(echo "$metrics" | grep -v ^# | grep md_rects_acc_total | cut -d' ' -f2)
    md_status=$(echo "$metrics" | grep -v ^# | grep md_status | cut -d' ' -f2)

   if [ $md_status -eq 0 ]; then
        continue
  fi
  echo "$TEMPLATE"

  # throttle execution
  [ -f "$STOP_FILE" ] && [ "$(date -r "$STOP_FILE" +%s)" -ge "$(($(date +%s) - $motion_throttle))" ] && continue
  touch "$STOP_FILE"

  # get a fresh snapshot
  snapshot4cron.sh -f
  [ $? -ne 0 ] && echo "Cannot get a snapshot" && quit_clean 2

  # send alerts
  [ "true" = "$motion_send2email" ] && send2email.sh
  [ "true" = "$motion_send2ftp" ] && send2ftp.sh
  [ "true" = "$motion_send2mqtt" ] && send2mqtt.sh
  [ "true" = "$motion_send2telegram" ] && send2telegram.sh
  [ "true" = "$motion_send2webhook" ] && send2webhook.sh
  [ "true" = "$motion_send2yadisk" ] && send2yadisk.sh
  [ "true" = "$motion_playonspeaker" ] && playonspeaker.sh
done
