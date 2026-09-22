#!/system/bin/sh
# ============================================================
# restore_from_kit.sh — 从 kit 恢复生产链（v1, 2026-09-21）
# 用途：重装/更新后，或 backup_20260920 缺失时，把 kit 里的
#       脚本与 jar 重新放回运行位置，并触发标准恢复脚本。
# 用法： sh /sdcard/Download/Operit/kit/restore_from_kit.sh
# ============================================================
K=/sdcard/Download/Operit/kit
T=/data/local/tmp
B=/sdcard/Download/Operit
echo "== restore_from_kit $(date) =="
# 1) jar 三处部署（以 kit 里的 v9.1 为准）
cp -f $K/jars/shower-server-v9.1.jar $B/shower-server-v9.1.jar
cp -f $K/jars/shower-server-v9.1.jar $B/shower-server.jar
cp -f $K/jars/shower-server-v9.1.jar $T/shower-server.jar
# 2) 脚本与配置
cp -f $K/scripts/*.sh $T/ 2>/dev/null
cp -f $K/scripts/prewarm_map.tsv $T/prewarm_map.tsv 2>/dev/null
cp -f "$K/scripts/README_勿删系统组件.txt" "$T/README_勿删系统组件.txt" 2>/dev/null
chmod 755 $T/watchdog.sh $T/prewarm_watcher.sh $T/guard_prewarm.sh $T/restore_chain.sh $T/hc.sh 2>/dev/null
[ -f $T/prewarm_target.txt ] || : > $T/prewarm_target.txt
[ -f $T/shower.log ] || touch $T/shower.log
# 3) 交给标准恢复脚本（启动哨位 + 出报告）
sh $T/restore_chain.sh
echo "RESTORE-FROM-KIT DONE"
