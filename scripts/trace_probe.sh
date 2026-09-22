#!/system/bin/sh
OUT=/sdcard/Download/Operit/trace_probe.log
echo "=== probe start $(date '+%F %T') ===" >> $OUT
i=0
while [ $i -lt 260 ]; do
  T=$(date '+%H:%M:%S')
  D=$(dumpsys display 2>/dev/null | /system/bin/grep -c ShowerVirtual)
  WD=$(dumpsys window windows 2>/dev/null)
  W=$(echo "$WD" | /system/bin/grep -cE 'u0 com.ai.assistance.operit')
  V=$(echo "$WD" | /system/bin/grep -m1 -A3 'u0 com.ai.assistance.operit}' | /system/bin/grep -m1 'mAttrs=' | cut -c1-110)
  A=$(dumpsys meminfo com.ai.assistance.operit 2>/dev/null | awk '/Dalvik Heap/{print $8"/"$9}')
  P=$(ps -ef 2>/dev/null | /system/bin/grep -c '[a]pp_process')
  echo "$T disp=$D win=$W dalvik=$A proc=$P" >> $OUT
  echo "   $V" >> $OUT
  i=$((i+1))
  sleep 4
done
echo "=== probe end $(date '+%F %T') ===" >> $OUT
