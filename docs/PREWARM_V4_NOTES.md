# 任务感知预启动 v4（2026-09-20 22:03 部署）

## 背景与变更
- 旧版预启动（v3 及服务器内置 auto-prewarm）只会照抄静态配置文件 prewarm_target.txt：
  - 配置老（修改超 5 分钟）时，每次开屏都会拉起配置里的 app；
  - 与任务目标不一致时（如任务要腾讯、配置是抖音），会在虚拟屏里多拉起一个无关 app，抢占视频输出通道，导致任务 app 画面异常（透明空白 / WS 截图 returned no data）。
- v4 改为“任务感知”：
  - 监听 shower.log 的 “Created virtual display id=” 行（新虚拟屏）；
  - 读取 PhoneAgent 任务启动行 “run: starting first step for task=...” 解析任务名；
  - 用映射表 prewarm_map.tsv 解析目标包名，写入 prewarm_target.txt（并把 mtime 冻龄到 2026-01-01 以绕过 5 分钟冷却、即时生效）；
  - 解析失败或非任务开屏时写入空文件（预启动自动跳过，宁缺毋滥）。
  - 实际拉起动作仍由服务器内置 auto-prewarm（x.smali，有系统权限）执行；外部脚本不再尝试 am start（v3 当年失败的原因）。

## 文件清单
- /data/local/tmp/prewarm_watcher.sh      v4 主脚本
- /data/local/tmp/prewarm_map.tsv         任务关键词 -> 包名映射表（可编辑）
- /data/local/tmp/guard_prewarm.sh        守护（每 20s 检查/拉起 watcher）
- /data/local/tmp/prewarm_target.txt      预热配置（运行时自动维护）
- 备份: /sdcard/Download/Operit/backup_20260920/ 下同名文件 + shower-server-v5.jar + restore_chain.sh
- 日志: /sdcard/Download/Operit/prewarm.log（watcher）、prewarm_guard.log（guard）

## 根因证据（本次修复对应）
- 21:10 / 21:33 / 21:42 会话（预启动=抖音）：任务每步均伴随 “W/ActionHandler: Shower WS screenshot returned no data” → 画面异常。
- 21:52 会话（配置刚改、5 分钟冷却生效→预启动静默跳过）：0 条 WS 截图失败，用户确认“挺顺利、画面会显示”。
- x.smali 分析：sleep2.5s 后检查“文件修改距今 >= 300000ms”，是静默跳过的原因。

## 回滚方法
- cp /data/local/tmp/prewarm_watcher_v3.bak.sh /data/local/tmp/prewarm_watcher.sh  （然后重启 watcher）
- 或恢复旧配置：printf %s 'com.tencent.qqlive' > /data/local/tmp/prewarm_target.txt

## 已知限制
- 任务名需包含映射表中的关键词（如“腾讯视频”“哔哩哔哩”“B站”“抖音”等）；
- 同时提及多个 app 的任务名按表顺序取第一个命中（罕见，后续可改“最早出现优先”）；
- 映射表可按需扩充（格式：每行“关键词 包名”）。

## 预期观测点
- prewarm.log: “display=NN created; analyzing task...” → “task='...' -> prewarm: <pkg>”
- shower.log: “auto-prewarm: read <pkg>” → “auto-prewarm: calling” → “auto-prewarm: launched <pkg> on display NN”

## v5 更新（2026-09-20 23:18）
- watcher v5：新增 pkg_installed 校验——写 target 前检查目标包仍安装；已卸载 → 日志 "target ... MISSING; skip"（自动跳过，防白拉/防过期映射）。
- 动机：映射表为静态手写文件，不会自动感知 app 被卸载；v5 使过期条目自动失效（无需维护）。
- 备份：/data/local/tmp/prewarm_watcher.sh.bak-20260920-2315；三副本已同步（tmp/main/backup）。
- 回滚：cp prewarm_watcher.sh.bak-20260920-2315 prewarm_watcher.sh 并重启 watcher。
