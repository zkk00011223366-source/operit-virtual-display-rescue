#!/system/bin/sh
# hc.sh — 全资产健康体检（防退化总控）v7.1  2026-09-21
# 基线：shower-server v9.1 = e8c1b771e34aa523cde83af3139aa41a
# v4 增量：基线升 v7（四副本 + watchdog SRC 检查）
# v5 增量：基线升 v8
# v6 增量：基线升 v9
# v7 增量：基线升 v9.1
# v7.1 增量：日志监控三项改为“可选”（默认 OFF；sh /data/local/tmp/mon.sh up|down|status 开关）
# 用法： sh /data/local/tmp/hc.sh
M_JAR=e8c1b771e34aa523cde83af3139aa41a
P=0; F=0
ok(){ echo "PASS|$1"; P=$((P+1)); }
bad(){ echo "FAIL|$1"; F=$((F+1)); }
chk(){ ps -A -o ARGS 2>/dev/null | /system/bin/grep -aq "$1" && ok "proc $2" || bad "proc $2 MISSING"; }
chk_opt(){ ps -A -o ARGS 2>/dev/null | /system/bin/grep -aq "$1" && ok "proc $2" || echo "INFO| proc $2 off (optional; mon.sh up to enable)"; }

echo "=== hc.sh $(date) ==="
echo "--- [1] jar four copies ---"
for f in /sdcard/Download/Operit/shower-server-v9.1.jar /sdcard/Download/Operit/shower-server.jar /data/local/tmp/shower-server.jar /sdcard/Download/Operit/backup_20260920/shower-server-v9.1.jar; do
  if [ -f "$f" ]; then m=$(md5sum "$f" 2>/dev/null | awk '{print $1}'); [ "$m" = "$M_JAR" ] && ok "jar $f" || bad "jar $f md5=$m"; else bad "jar $f MISSING"; fi
done
echo "--- [2] watcher consistency ---"
if [ -f /data/local/tmp/prewarm_watcher.sh ] && [ -f /sdcard/Download/Operit/prewarm_watcher.sh ]; then
 a=$(md5sum /data/local/tmp/prewarm_watcher.sh | awk '{print $1}'); b=$(md5sum /sdcard/Download/Operit/prewarm_watcher.sh | awk '{print $1}')
 [ "$a" = "$b" ] && ok "watcher tmp==main" || bad "watcher mismatch $a/$b"
else bad "watcher file missing"; fi
echo "--- [2b] watchdog SRC ---"
if /system/bin/grep -q 'shower-server-v9[.]1[.]jar' /data/local/tmp/watchdog.sh; then ok "watchdog SRC=v9.1"; else bad "watchdog SRC not v9.1"; fi
echo "--- [3] core files ---"
for f in /data/local/tmp/guard_prewarm.sh /data/local/tmp/prewarm_map.tsv /data/local/tmp/restore_chain.sh /data/local/tmp/watchdog.sh /data/local/tmp/trace_probe.sh /data/local/tmp/autocap.sh /sdcard/Download/Operit/logcat_shower.log; do [ -f "$f" ] && ok "file $f" || bad "file $f MISSING"; done
echo "--- [4] processes ---"
W=$(ps -A -o ARGS 2>/dev/null | /system/bin/grep -c '^sh /data/local/tmp/prewarm_watcher.sh$')
[ "$W" = "1" ] && ok "proc prewarm_watcher (single instance)" || bad "proc prewarm_watcher instances=$W"
chk "[g]uard_prewarm.sh" guard
chk "[w]atchdog.sh" watchdog
if ps -A -o ARGS 2>/dev/null | /system/bin/grep -aq "[a]utocap.sh"; then ok "proc autocap (running)"; else echo "INFO| autocap not running (on-demand capture script)"; fi
chk_opt "[l]ogcat -b main" logcat_blackbox
chk_opt "[l]ogcat -v time -s ShowerController" shower_dedicated_monitor
chk_opt "[l]ogcat -v time" logcat_any_stream
if ps -A -o ARGS 2>/dev/null | /system/bin/grep -aq "[t]race_probe.sh"; then ok "proc trace_probe (on-demand)"; else echo "INFO| trace_probe not running (on-demand probe)"; fi
echo "--- [5] info ---"
echo "INFO| target=[$(head -1 /data/local/tmp/prewarm_target.txt 2>/dev/null)] size=$(stat -c %s /data/local/tmp/prewarm_target.txt 2>/dev/null)"
echo "INFO| shower_log=$(wc -l < /sdcard/Download/Operit/logcat_shower.log 2>/dev/null) lines"
ST=""; for pkg in $(awk 'NF>0{print $NF}' /data/local/tmp/prewarm_map.tsv 2>/dev/null | sort -u); do pm list packages "$pkg" 2>/dev/null | /system/bin/grep -qxF "package:$pkg" || ST="$ST $pkg"; done
[ -z "$ST" ] && echo "INFO| map packages: all installed" || echo "INFO| map stale:$ST"
echo "=== RESULT: PASS=$P FAIL=$F ==="
[ "$F" = 0 ] && echo "VERDICT: HEALTHY" || echo "VERDICT: ATTENTION"