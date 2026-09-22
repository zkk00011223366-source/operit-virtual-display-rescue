#!/system/bin/sh
# ============================================================
# restore_chain.sh v6.1  (2026-09-21) — v9.1 基线版
# Operit 虚拟屏技术链 · 一键恢复/自检（幂等，可重复运行）
# v6.1 增量：日志监控改为可选（monitors_off.flag 存在则跳过；sh /data/local/tmp/mon.sh up 按需启用）
# 场景：重装/更新 Operit、设备重启、或怀疑组件被破坏时
# 用法：sh /sdcard/Download/Operit/restore_chain.sh
# ============================================================
B=/sdcard/Download/Operit
T=/data/local/tmp
BK=$B/backup_20260920
LOG=$B/restore_chain.log
V91=$B/shower-server-v9.1.jar
SIZE=1163846

echo "== restore_chain v6.1 $(date) ==" >> $LOG

# [1] v9.1 源文件（缺则从备份恢复）
if [ ! -s "$V91" ]; then
  cp -f $BK/shower-server-v9.1.jar "$V91" 2>/dev/null && echo "[1] v9.1 source: restored from backup" >> $LOG
fi
sz=$(stat -c %s "$V91" 2>/dev/null)
if [ "$sz" != "$SIZE" ]; then echo "[1] !! v9.1 source abnormal size=$sz" >> $LOG; else echo "[1] v9.1 source ok" >> $LOG; fi

# [2] 部署 jar 两副本（尺寸不符才覆盖）
for D in $B/shower-server.jar $T/shower-server.jar; do
  s=$(stat -c %s "$D" 2>/dev/null)
  if [ "$s" != "$SIZE" ]; then cp -f "$V91" "$D" 2>/dev/null && echo "[2] deployed -> $D (was=$s)" >> $LOG; fi
done

# [3] 脚本/配置（缺则从备份恢复）
for f in watchdog.sh prewarm_watcher.sh guard_prewarm.sh hc.sh autocap.sh trace_probe.sh prewarm_map.tsv; do
  if [ ! -f "$T/$f" ]; then cp -f "$BK/$f" "$T/$f" 2>/dev/null && echo "[3] $f restored" >> $LOG; fi
done
[ -f $T/prewarm_target.txt ] || { : > $T/prewarm_target.txt; echo "[3] prewarm_target.txt created (empty)" >> $LOG; }
[ -f $T/shower.log ] || touch $T/shower.log
[ -f $T/README_勿删系统组件.txt ] || cp -f $B/README_勿删系统组件.txt $T/README_勿删系统组件.txt 2>/dev/null
chmod 755 $T/watchdog.sh $T/prewarm_watcher.sh $T/guard_prewarm.sh 2>/dev/null

# [4] 启动缺岗的哨位
if ! ps -A -o ARGS 2>/dev/null | grep -aq "[s]h /data/local/tmp/watchdog.sh"; then
  (setsid nohup sh $T/watchdog.sh >/dev/null 2>&1 < /dev/null &)
  echo "[4] watchdog: started" >> $LOG
fi
if ! ps -A -o ARGS 2>/dev/null | grep -aq "[s]h /data/local/tmp/prewarm_watcher.sh"; then
  (setsid nohup sh $T/prewarm_watcher.sh >/dev/null 2>&1 < /dev/null &)
  echo "[4] prewarm_watcher: started" >> $LOG
fi
if ! ps -A -o ARGS 2>/dev/null | grep -aq "[g]uard_prewarm.sh"; then
  (setsid nohup sh $T/guard_prewarm.sh >/dev/null 2>&1 < /dev/null &)
  echo "[4] guard: started" >> $LOG
fi

# [4b] 日志监控（可选；monitors_off.flag 存在时跳过）
if [ -f $B/monitors_off.flag ]; then
  echo "[4b] logcat monitors: skipped (monitors_off.flag; run mon.sh up to enable)" >> $LOG
else
  if ! ps -A -o ARGS 2>/dev/null | grep -aq "[l]ogcat -b main"; then
    (setsid nohup logcat -b main -b system -b crash -b events -f $B/lc_cap.txt -r4096 -n4 >/dev/null 2>&1 < /dev/null &)
    echo "[4b] logcat blackbox: started" >> $LOG
  fi
  if ! ps -A -o ARGS 2>/dev/null | grep -aq "[l]ogcat -v time -s ShowerController"; then
    (setsid nohup sh -c 'logcat -v time -s ShowerController -s ShowerSurfaceView -s ShowerVideoRenderer -s ShowerBinderRegistry -s ShowerServerManager -s ShowerBinderReceiver -s ShowerEnvironment -s ActionHandler > /sdcard/Download/Operit/logcat_shower.log 2>&1' &)
    echo "[4b] shower logcat: started" >> $LOG
  fi
  if ! ps -A -o ARGS 2>/dev/null | grep -aq "[l]ogcat_mon.log"; then
    (setsid nohup sh -c 'logcat -v time 2>/dev/null | grep -aE "ActionHandler|Shower|shower|overlay|Overlay|takeScreenshot|screenshot|Screenshot|DisplayCapture|VirtualDisplay|VirtualScreen|canUseShower|ViaShower|PhoneAgent|UIAutomation|AutoGLM" | grep -avE "DeepseekProvider|reasoning mode request body" > /sdcard/Download/Operit/logcat_mon.log 2>&1' &)
    echo "[4b] logcat monitor: started" >> $LOG
  fi
fi

sleep 2

# [5] 自检报告
echo "---- report $(date +%H:%M:%S) ----" >> $LOG
echo "v9.1 md5 : $(md5sum $V91 2>/dev/null | awk '{print $1}')" >> $LOG
echo "copyA  : $(stat -c '%s' $B/shower-server.jar 2>/dev/null) $B/shower-server.jar" >> $LOG
echo "copyB  : $(stat -c '%s' $T/shower-server.jar 2>/dev/null) $T/shower-server.jar" >> $LOG
if ps -A -o ARGS 2>/dev/null | grep -aq "[s]hizuku_server"; then echo "[5] Shizuku: running (ok)" >> $LOG; else echo "[5] !! Shizuku NOT running - 请启动 Shizuku 并授权 Operit" >> $LOG; fi
echo "procs:" >> $LOG
ps -A -o PID,PPID,ARGS 2>/dev/null | grep -aE "[s]h /data/local/tmp/watchdog.sh|[s]h /data/local/tmp/prewarm_watcher.sh|[g]uard_prewarm.sh|[l]ogcat -v time|shower.Main" | grep -v grep >> $LOG
echo "[hint] 人工确认: 1)Shizuku已授权 2)Operit权限级别=DEBUGGER/ADB 3)实验性虚拟屏开关=开" >> $LOG
echo "== done ==" >> $LOG
echo "RESTORE-CHAIN v6.1 DONE. report -> $LOG"
tail -n 16 $LOG