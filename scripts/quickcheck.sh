#!/system/bin/sh
# ============================================================
# quickcheck.sh — 三件套 3 秒自检（虚拟屏链）
# ① jar md5（两副本） ② InputController 初始化 ③ 最近注入证据 + 哨位进程
# 用法： sh /data/local/tmp/quickcheck.sh
# 判读：F=0 → READY；F>0 → 跑 restore_chain.sh
# ============================================================
B=/sdcard/Download/Operit; T=/data/local/tmp
M=e8c1b771e34aa523cde83af3139aa41a
P=0; F=0
ok(){ echo "PASS|$1"; P=$((P+1)); }
bad(){ echo "FAIL|$1"; F=$((F+1)); }

echo "== quickcheck $(date) =="

# [1] jar 两副本
m1=$(md5sum $T/shower-server.jar 2>/dev/null | awk '{print $1}')
m2=$(md5sum $B/shower-server.jar 2>/dev/null | awk '{print $1}')
[ "$m1" = "$M" ] && ok "jar tmp == v9.1" || bad "jar tmp md5=$m1"
[ "$m2" = "$M" ] && ok "jar sdcard == v9.1" || bad "jar sdcard md5=$m2"

# [2] InputController 初始化（近期日志）
if tail -600 $T/shower.log 2>/dev/null | grep -aq 'InputController initialized'; then
  ok "InputController initialized (recent)"
else
  bad "InputController initialized MISSING (recent)"
fi

# [3] 最近注入证据（无点击测试时不算失败）
tap=$(tail -600 $T/shower.log 2>/dev/null | grep -a 'Binder TAP injected' | tail -1)
if [ -n "$tap" ]; then echo "INFO| last TAP: $tap"; else echo "INFO| no recent TAP (run a tap test)"; fi

# [4] 哨位进程
ps -A -o ARGS 2>/dev/null | grep -aq '[s]h /data/local/tmp/watchdog.sh' && ok "watchdog running" || bad "watchdog MISSING"
ps -A -o ARGS 2>/dev/null | grep -aq '[g]uard_prewarm.sh' && ok "guard running" || bad "guard MISSING"
ps -A -o ARGS 2>/dev/null | grep -aq '[s]h /data/local/tmp/prewarm_watcher.sh' && ok "prewarm_watcher running" || bad "prewarm_watcher MISSING"

echo "=== RESULT: PASS=$P FAIL=$F ==="
[ "$F" = 0 ] && echo "VERDICT: READY" || echo "VERDICT: DEGRADED — run restore_chain.sh"