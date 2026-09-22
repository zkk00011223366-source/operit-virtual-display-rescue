#!/system/bin/sh
BASE=/sdcard/Download/Operit/autocap
mkdir -p $BASE
LAST=""
i=0
while [ $i -lt 3600 ]; do
  CUR=$(dumpsys display 2>/dev/null | /system/bin/grep -oE 'ShowerVirtualDisplay-[0-9]+' | sort -u | head -1)
  if [ -n "$CUR" ] && [ "$CUR" != "$LAST" ]; then
    LAST=$CUR
    TS=$(date '+%m%d_%H%M%S')
    D=$BASE/run_$TS
    mkdir -p $D
    echo "=== new display $CUR at $TS ===" >> $BASE/summary.log
    n=1
    while [ $n -le 10 ]; do
      P=$(date '+%H%M%S')
      screencap -p $D/main_$P.png 2>/dev/null
      ID=$(dumpsys SurfaceFlinger --display-id 2>/dev/null | /system/bin/grep -m1 'ShowerVirtualDisplay' | awk '{print $2}')
      [ -n "$ID" ] && screencap -p -d $ID $D/vd_$P.png 2>/dev/null
      {
        echo "--- $P ---"
        dumpsys window windows 2>/dev/null | /system/bin/grep -F -A3 'u0 com.ai.assistance.operit}' | /system/bin/grep -E 'Window #|mAttrs=' | head -4
        dumpsys meminfo com.ai.assistance.operit 2>/dev/null | awk '/Dalvik Heap/{print "dalvik",$8,$9}'
        logcat -d -t 1500 2>/dev/null | /system/bin/grep -E 'W TraceLog: on[A-Za-z]+\(c2\.' | /system/bin/grep -vE 'AIService|ToolPkg|Debugger' | tail -6
        tail -3 /data/local/tmp/shower.log 2>/dev/null
      } >> $D/state.txt
      n=$((n+1))
      sleep 8
    done
    echo "=== capture done for $CUR ===" >> $BASE/summary.log
  fi
  [ -z "$CUR" ] && LAST=""
  i=$((i+1))
  sleep 2
done
