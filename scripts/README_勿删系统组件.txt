【勿删勿拆！虚拟屏技术链 · 系统组件说明】2026-09-21 07:30 更新

本目录(/data/local/tmp)与 /sdcard/Download/Operit 下的以下文件是"生产组件"：
（已调好的虚拟屏自动化链，不是垃圾、不是残留——勿删勿杀勿覆盖！）

- shower-server.jar（1163819B，md5 038be08b890c430b9e032642898a84e9）
      = v9 补丁服务（触控修复 + 空白自愈v9：全NAL扫描 + SPS/PPS/IDR 缓存 + 60帧周期重发）；被覆盖时"看门狗"会自动还原
- watchdog.sh        = 看门狗：秒级夺回被 Operit 覆盖的 v9。勿杀！
- prewarm_watcher.sh = 抢跑哨兵 v5：自动把目标任务 APP 启动进新虚拟屏。勿杀！
- prewarm_map.tsv    = 预启动映射表（133 条全量，含中文口语别名）
- guard_prewarm.sh   = 哨兵守护（watcher 掉了会自动拉起）。勿杀！
- hc.sh              = 全资产体检（健康状态跑它就知道）
- restore_chain.sh   = 一键恢复（重装 Operit / 重启后先跑它）
- autocap.sh         = 会话自动截图（按需运行，约 2 小时自停）

完整说明（必读）：/sdcard/Download/Operit/系统保护清单-勿删勿拆.md
项目全记录 & 重装恢复指南：/sdcard/Download/Operit/手册-虚拟屏自动化链-全流程.md（v1.0）
一键恢复脚本（重装 Operit 后先跑它）：sh /sdcard/Download/Operit/restore_chain.sh

如需"清理"，先读上面这份清单，或先询问用户。动了这些，系统就白调了。
机制解剖（打开链全文）：/sdcard/Download/Operit/机制解剖-虚拟屏打开.md