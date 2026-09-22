#!/system/bin/sh
# mon.sh — 日志监控 开关/状态（2026-09-21）
# 用法: sh /data/local/tmp/mon.sh up | down | status
# 监控三项: blackbox(lc_cap) + shower专用 + logcat_mon
# 默认 OFF（monitors_off.flag）；up=拉起并清除flag；down=撤下并设置flag
B=/sdcard/Download/Operit; T=/data/local/tmp; L=$B/monitors_status.log
case "$1" in
up)
  rm -f $B/monitors_off.flag
  if ! ps -A -o ARGS 2>/dev/null | /system/bin/grep -aq "[l]ogcat -b main"; then
    (setsid nohup logcat -b main -b system -b crash -b events -f $B/lc_cap.txt -r4096 -n4 >/dev/null 2>&1 < /dev/null &)
    echo "[$(date '+%m-%d %H:%M')] UP blackbox" >> $L
  fi
  if ! ps -A -o ARGS 2>/dev/null | /system/bin/grep -aq "[l]ogcat -v time -s ShowerController"; then
    (setsid nohup sh -c 'logcat -v time -s ShowerController -s ShowerSurfaceView -s ShowerVideoRenderer -s ShowerBinderRegistry -s ShowerServerManager -s ShowerBinderReceiver -s ShowerEnvironment -s ActionHandler > /sdcard/Download/Operit/logcat_shower.log 2>&1' &)
    echo "[$(date '+%m-%d %H:%M')] UP shower" >> $L
  fi
  if ! ps -A -o ARGS 2>/dev/null | /system/bin/grep -aq "[l]ogcat_mon.log"; then
    (setsid nohup sh -c 'logcat -v time 2>/dev/null | grep -aE "ActionHandler|Shower|shower|overlay|Overlay|takeScreenshot|screenshot|Screenshot|DisplayCapture|VirtualDisplay|VirtualScreen|canUseShower|ViaShower|PhoneAgent|UIAutomation|AutoGLM" | grep -avE "DeepseekProvider|reasoning mode request body" > /sdcard/Download/Operit/logcat_mon.log 2>&1' &)
    echo "[$(date '+%m-%d %H:%M')] UP monitor" >> $L
  fi
  sleep 2
  echo "== mon.sh status =="
  ps -A -o PID,ARGS 2>/dev/null | grep -aE 'lc_cap|ShowerController|logcat_mon' | grep -av grep
  ;;
down)
  touch $B/monitors_off.flag
  for p in $(ps -A -o PID,ARGS 2>/dev/null | grep -aE 'lc_cap|logcat_shower|logcat_mon|ShowerController' | grep -avE 'grep|mon.sh' | awk '{print $1}'); do kill $p 2>/dev/null; done
  for p in $(ps -A -o PID,ARGS 2>/dev/null | grep -aE '[l]ogcat -v time *$' | grep -avE 'grep|mon.sh' | awk '{print $1}'); do kill $p 2>/dev/null; done
  echo "[$(date '+%m-%d %H:%M')] DOWN (flag set)" >> $L
  sleep 1
  echo "== mon.sh status =="
  ps -A -o PID,ARGS 2>/dev/null | grep -aE 'lc_cap|ShowerController|logcat_mon|logcat -v time' | grep -av grep
  ;;
status)
  if [ -f $B/monitors_off.flag ]; then echo "flag: OFF-by-user (monitors_off.flag present)"; else echo "flag: ON (no flag)"; fi
  ps -A -o PID,ARGS 2>/dev/null | grep -aE 'lc_cap|ShowerController|logcat_mon' | grep -av grep
  echo "--"
  ;;
*)
  echo "usage: sh $0 up | down | status"
  ;;
esac
