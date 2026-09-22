# kit-恢复套件（2026-09-21 建立）

本套件 = "虚拟屏技术链"全部成果的冷备份 + 一键恢复入口。
目标：Operit 更新 / 重装 / 设备重启后，最快速度恢复到当前生产状态。

> 本目录位于 /sdcard（卸载 Operit 不会丢）；仍建议再拷贝一份到电脑/网盘。
> App 安装包备份：/sdcard/Download/Operit/operit.apk（当前版本 1.12.2）

## 一、先记住两个口令
- 一键恢复（缺什么补什么，幂等安全）：
      sh /sdcard/Download/Operit/restore_chain.sh
- 全身体检（输出 PASS/FAIL 报告）：
      sh /data/local/tmp/hc.sh

## 二、目录内容
- jars/    ：shower-server 各版本（当前 v9.1=...e8c1b771...、历史版本、原始基线）
- scripts/ ：生产脚本全套（watchdog / 抢跑哨兵 / 哨兵守护 / 体检 / 恢复 / 抓帧…）
- tools/   ：补丁工具链（baksmali / smali / dexlib2 / guava / jcommander / util / antlr）
- build/   ：补丁生产线整包（tmp-full.tar = 工作区；root-full.tar = root 家目录；home-ubuntu.tar）
- packages/："包/技能"备份（*.toolpkg / *.js）
- docs/    ：全部记录文档（手册 / 机制解剖 / 系统保护清单 / 案例记录 / 阶段收口…）
- backup_20260920/ ：历史备份（jar 全版本 + 各版脚本 + 补丁进度记录）
- restore_from_kit.sh ：从本套件恢复脚本与 jar 的入口（标准恢复的前置保险）

## 三、场景操作

### A. 只是重启了设备
1) 跑 `sh /data/local/tmp/hc.sh` 看报告；
2) 有 FAIL → 跑 `sh /sdcard/Download/Operit/restore_chain.sh`。

### B. 更新了 Operit（覆盖安装）
1) watchdog 会自动夺回被覆盖的 jar（秒级）；
2) 跑 `hc.sh` 复核；仍未修 → 跑 `restore_chain.sh`；
3) 若大版本导致协议变化（虚拟屏黑屏 / 不出画面）→ 走下面"D. 重打补丁"。

### C. 重装了 Operit（数据清空）
1) 装回 Operit → 授权：Shizuku、无障碍、悬浮窗、电池白名单；
2) 恢复"包/技能"：把 `kit/packages/` 内容拷回
   `/sdcard/Android/data/com.ai.assistance.operit/files/packages/`
   后在 App 内刷新（或逐个安装 .toolpkg）；
3) 若 Ubuntu 环境也没了：在 App 内重建 Ubuntu 环境（apt 装 openjdk-17 等，见 D）；
4) 跑 `sh /sdcard/Download/Operit/kit/restore_from_kit.sh`；
5) 跑 `sh /sdcard/Download/Operit/restore_chain.sh`；
6) 跑 `hc.sh`，确认 PASS 数恢复（基线：PASS=19 FAIL=0）。

### D. 大版本更新后"重打补丁"（v9.1 基线不再兼容时）
1) 从新版 APK 提取原始 jar：`assets/shower-server.jar`；
2) 解包到 smali（工具在 kit/tools，命令示例：
   `java -cp 'bk252.jar:dexlib2.jar:guava.jar:jcommander.jar:util.jar:antlr-runtime.jar' org.jf.baksmali.Main d classes.dex -o out`）；
3) 用 build/ 工作区里的流水线依序套补丁：
   patch_v6_j.py → patch_v7_j.py → patch_v8_j.py → patch_v9_j.py → patch_v9_1_j.py（配合 v*_newb.smali / v9_helper.smali）
   然后用 make_jar_v9_1.py 打包出 jar；
4) 产物命名 **shower-server-v9.x-new.jar** → 放入 kit/jars/ 与 /sdcard/Download/Operit/；
5) 更新 watchdog.sh 与 restore_chain.sh 的 SRC 指向新 jar；更新 hc.sh 顶部 M_JAR 基线 md5；
6) 跑 restore_chain.sh + hc.sh；虚拟屏实机验证。
   ※ 类结构变化时需先小改 patch 脚本（参考 docs/PATCH_PROGRESS.md、docs/手册-虚拟屏自动化链-全流程.md）。

## 四、刷新本套件（每次大改动后）
在 Ubuntu 终端（proot）里执行：
    tar -cf /sdcard/Download/Operit/kit/build/tmp-full.tar -C /tmp .
    tar -cf /sdcard/Download/Operit/kit/build/root-full.tar -C /root .
    cp -f /data/local/tmp/*.sh /data/local/tmp/*.tsv /sdcard/Download/Operit/kit/scripts/
    cp -rf /sdcard/Android/data/com.ai.assistance.operit/files/packages/. /sdcard/Download/Operit/kit/packages/
    cp -f /sdcard/Download/Operit/*.md /sdcard/Download/Operit/kit/docs/

## 五、三道保险
1) watchdog 秒级守护两处 jar 副本（/sdcard 与 /data/local/tmp）；
2) /sdcard 主备份 + 本 kit 冷备份；
3) 定期把本 kit 整目录拷贝到设备外（电脑/网盘）。

## 六、注意
- 勿删 `/data/local/tmp` 与 `/sdcard/Download/Operit` 下的生产文件（见 docs/系统保护清单-勿删勿拆.md）。
- 本套装不包含系统镜像；Ubuntu 系统本身可用 App 功能重建，工具与脚本都在 kit 里。
## 七、日志监控（可选 · 2026-09-21 起默认撤下）
- 开关：sh /data/local/tmp/mon.sh up | down | status
- 说明：三项日志捕获（blackbox / shower专用 / logcat_mon）默认 OFF；需要取证 / 排查时 up 拉起，平时 down 撤下。撤下不影响看门狗、抢跑哨兵、恢复链（hc.sh 中监控项为可选，撤下时显示 INFO）。
