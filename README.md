# operit-virtual-display-rescue

Operit 虚拟屏链 · 急救技能：**一键体检 + 一键恢复 + 实机验收指纹**。

适用于 Android 16（SDK 37）等设备上 Operit 虚拟屏「能显示但点击无效」、黑屏、或守护进程被清空后，快速把整条虚拟屏自动化链恢复到可用状态。

## 亮点

- **二段式根因已解剖**：jar 被官方覆盖回原版 + 交互通道未重建
- **幂等恢复**：`restore_chain.sh` 缺什么补什么，重复执行安全
- **硬性验收指纹**：`InputController initialized` + `Binder TAP injected` + `hc.sh PASS=16 FAIL=0`
- **全套资产冷备份**：jar / 脚本 / 工具链 / 文档，随包携带

## 快速开始

```sh
sh /data/local/tmp/hc.sh                     # 体检
sh /sdcard/Download/Operit/restore_chain.sh  # 恢复（幂等）
```

新设备部署：`sh install.sh`（详见 `SKILL.md`）。

## 内容

| 目录 | 内容 |
|------|------|
| `scripts/` | hc.sh、restore_chain.sh、watchdog.sh、prewarm_watcher.sh、guard_prewarm.sh、mon.sh、restore_from_kit.sh 等 |
| `jars/` | shower-server-v9.1.jar（基线 md5 `e8c1b771e34aa523cde83af3139aa41a`） |
| `tools/` | 补丁工具链（baksmali / smali / dexlib2 / guava / jcommander / util / antlr） |
| `docs/` | 急救卡、恢复说明、机制解剖、案例记录、PATCH_PROGRESS、防退化守则等 |

## 验收指纹（必须亲眼看日志）

1. `InputController initialized, setDisplayIdMethod=true`
2. `Binder TAP injected: ... on <displayId>`
3. `hc.sh` → `PASS=16 FAIL=0` / `VERDICT: HEALTHY`
4. `dumpsys input` 残留虚拟屏卡 = 0

## 纪律

- 不要删除 `/sdcard/Download/Operit/` 与 `/data/local/tmp/` 下的生产文件
- 本包由 Operit GitHub Publisher 发布；欢迎随 issue 反馈失真点

## License

MIT
