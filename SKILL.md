---
name: operit-virtual-display-rescue
description: Operit 虚拟屏急救：虚拟屏"能显示但点击无效 / 黑屏 / 服务进程消失"时的一键体检与恢复。涵盖 shower-server.jar 触控补丁夺回、看门狗/抢跑哨兵拉起、虚拟屏会话重建与实机验收指纹。触发词：虚拟屏不能操作、虚拟屏点击无效、shower、hc.sh、restore_chain、虚拟屏急救、virtual display rescue。
---

# Operit 虚拟屏链 · 急救技能

> 让「虚拟屏技术链」在 Operit 更新 / 重装 / 重启 / 换会话后，最快速度恢复可用。
> 底线：只要 `/sdcard/Download/Operit/` 还在，就不会「回到解放前」。

## 适用症状

| 症状 | 常见根因 |
|------|----------|
| 虚拟屏能显示但点击/按键无效 | shower-server.jar 触控补丁被覆盖回原版（Android 16 移除 `InputManager.getInstance()`，补丁缺失即注入失效） |
| 虚拟屏黑屏 / 不出画面 | 会话未重建、帧保护缺失、服务进程被杀 |
| 打开变慢 / 抢跑失效 | prewarm_watcher / guard 进程消失 |
| Operit 更新后链全失效 | 两处 jar 副本被覆盖 + 守护进程被清 |

## 快速开始（两条命令）

```sh
# 1) 体检（PASS/FAIL 报告）
sh /data/local/tmp/hc.sh

# 2) 一键恢复（幂等，缺什么补什么）
sh /sdcard/Download/Operit/restore_chain.sh
```

体检基线（v9.1）：`PASS=16 FAIL=0 HEALTHY`。

## 部署（新设备 / kit 丢失时）

本技能自带全套资产。假设本目录位于 `/sdcard/Download/Operit/skills/operit-virtual-display-rescue/`：

```sh
sh /sdcard/Download/Operit/skills/operit-virtual-display-rescue/install.sh
```

install.sh：部署 jar 到三处（+ backup 副本）→ 部署脚本到 `/data/local/tmp` → 跑 `restore_chain.sh`。

## 验收指纹（必须看日志，别信"感觉"）

1. `/data/local/tmp/shower.log` 出现 `InputController initialized, setDisplayIdMethod=true`
2. 实机点击时出现 `Binder TAP injected: ... on <displayId>`
3. `hc.sh` 输出 `PASS=16 FAIL=0` + `VERDICT: HEALTHY`
4. `dumpsys input` 残留虚拟屏卡 = 0

## 目录结构

- `scripts/` — hc.sh / restore_chain.sh / watchdog.sh / prewarm_watcher.sh / guard_prewarm.sh / mon.sh / restore_from_kit.sh …
- `jars/` — shower-server-v9.1.jar（基线，md5 `e8c1b771e34aa523cde83af3139aa41a`）
- `tools/` — 补丁工具链（baksmali / smali / dexlib2 …，用于大版本升级后重打补丁）
- `docs/` — 急救卡、恢复说明、机制解剖、案例记录、PATCH_PROGRESS 等全套记录

## 按场景走流程

- **只是重启了设备**：跑 `hc.sh` → 有 FAIL → 跑 `restore_chain.sh`
- **更新/重装了 Operit**：`restore_chain.sh` → `hc.sh` → 实机验证
- **大版本不兼容（重打补丁）**：见 `docs/README-恢复说明.md` 场景 D 与 `docs/PATCH_PROGRESS.md`

## 纪律

- **不要删除** `/sdcard/Download/Operit/` 与 `/data/local/tmp/` 下的生产文件（见 `docs/系统保护清单-勿删勿拆.md`）
- 日志监控默认撤下（`sh /data/local/tmp/mon.sh up|down|status`）；需要取证时再拉起
- 建议把本目录（或原 kit/）再离线备份一份到电脑/网盘（第三道保险）
- 前置条件：Shizuku 运行并授权；Operit 权限级别 = DEBUGGER/ADB；实验性虚拟屏开关 = 开
