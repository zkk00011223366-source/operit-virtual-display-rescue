#!/system/bin/sh
# ============================================================
# install.sh — 虚拟屏链一键部署（技能版）
# 从本技能目录部署全套资产到运行位置，并触发标准恢复链。
# 用法：sh /sdcard/Download/Operit/skills/operit-virtual-display-rescue/install.sh
# 适用：新设备 / kit 目录丢失 / 手动部署
# 幂等：重复执行安全（缺什么补什么）
# ============================================================
S="$(cd "$(dirname "$0")" && pwd)"
[ -f "$S/jars/shower-server-v9.1.jar" ] || S=/sdcard/Download/Operit/skills/operit-virtual-display-rescue
T=/data/local/tmp
B=/sdcard/Download/Operit
J="$S/jars/shower-server-v9.1.jar"

echo "== install $(date) =="
echo "source: $S"

# [1] jar 三处部署 + backup 副本
mkdir -p "$B/backup_20260920"
cp -f "$J" "$B/shower-server-v9.1.jar"
cp -f "$J" "$B/shower-server.jar"
cp -f "$J" "$T/shower-server.jar"
[ -f "$B/backup_20260920/shower-server-v9.1.jar" ] || cp -f "$J" "$B/backup_20260920/shower-server-v9.1.jar"
echo "[1] jar deployed x4 (md5: $(md5sum "$J" 2>/dev/null | awk '{print $1}'))"

# [2] 脚本与配置
cp -f "$S/scripts/"*.sh "$T/" 2>/dev/null
cp -f "$S/scripts/prewarm_map.tsv" "$T/prewarm_map.tsv" 2>/dev/null
cp -f "$S/scripts/README_勿删系统组件.txt" "$T/README_勿删系统组件.txt" 2>/dev/null
chmod 755 "$T/watchdog.sh" "$T/prewarm_watcher.sh" "$T/guard_prewarm.sh" "$T/restore_chain.sh" "$T/hc.sh" 2>/dev/null
[ -f "$T/prewarm_target.txt" ] || : > "$T/prewarm_target.txt"
[ -f "$T/shower.log" ] || touch "$T/shower.log"
echo "[2] scripts deployed"

# [3] 交给标准恢复脚本（启动哨位 + 出报告）
sh "$T/restore_chain.sh"
echo "INSTALL DONE"
