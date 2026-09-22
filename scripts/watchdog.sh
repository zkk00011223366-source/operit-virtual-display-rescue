#!/system/bin/sh
# watchdog v6: DL/TMP auto-aligned to SRC size (upgrade-friendly)
SRC=/sdcard/Download/Operit/shower-server-v9.1.jar
DL=/sdcard/Download/Operit/shower-server.jar
TMP=/data/local/tmp/shower-server.jar
LOG=/sdcard/Download/Operit/wd_guard.log
while true; do
  SZ=$(stat -c %s "$SRC" 2>/dev/null); if [ -n "$SZ" ]; then
    sz=$(stat -c %s "$DL" 2>/dev/null); if [ "$sz" != "$SZ" ]; then cp -f "$SRC" "$DL.tmp" 2>/dev/null && mv -f "$DL.tmp" "$DL" 2>/dev/null && echo "A fix DL(sz:$sz->$SZ) $(date +%H:%M:%S)" >> "$LOG" 2>/dev/null; fi
    sz2=$(stat -c %s "$TMP" 2>/dev/null); if [ "$sz2" != "$SZ" ]; then cp -f "$SRC" "$TMP.tmp" 2>/dev/null && mv -f "$TMP.tmp" "$TMP" 2>/dev/null && echo "A fix TMP(sz:$sz2->$SZ) $(date +%H:%M:%S)" >> "$LOG" 2>/dev/null; fi
  fi
  sleep 0.05; done
