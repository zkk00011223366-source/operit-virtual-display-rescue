#!/system/bin/sh
# guard: keep prewarm_watcher alive (task-aware prewarm v4)
LOG=/sdcard/Download/Operit/prewarm_guard.log
while true; do
  if ! ps -A -o ARGS 2>/dev/null | /system/bin/grep -aq "[s]h /data/local/tmp/prewarm_watcher.sh"; then
    (setsid nohup sh /data/local/tmp/prewarm_watcher.sh >/dev/null 2>&1 < /dev/null &)
    echo "[$(date +%H:%M:%S)] restarted prewarm_watcher" >> $LOG
  fi
  sleep 20
done
