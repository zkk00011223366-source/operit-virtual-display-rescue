# 📕 案例记录 —— “空白竞态”实锤：replaying 120 → 丢头 → 丢 csd → 解码器永眠

**日期**：2026-09-20 22:55（取证完成） ｜ **性质**：任务C（虚拟屏空白）终审定案 · 竞态
**关联**：《机制解剖-虚拟屏打开》《机制血缘鉴定-打开与预启动》《案例记录-网易云空白案结案》《防退化守则》

## 一句话结论

预启动“抢跑”提前拉起的 app，在客户端面板 surface 建立前产出 **>120 帧**视频流，把客户端 120 帧环形缓冲撑满；**环形缓冲丢头**把流开头的 **SPS/PPS（csd-0/csd-1）帧**挤掉。surface 建立后回放 120 帧时 csd 永久缺失，`ShowerVideoRenderer` 解码器**永远无法初始化** → 整场空白（悬浮球空白＋AI 截图退化为看主屏）。

## 一、全样本对照（客户端日志 logcat_mon.log 实据）

| 场次 | display | 预启动 | 回放帧数 | decoder | 结果 |
|---|---|---|---|---|---|
| 18:59:32 | 35 | — | **120** | ❌ | （未回访） |
| 19:31:15 | 37 | — | 0 | ✅ | 正常 |
| 19:32 / 19:46 / 20:31~ | — | — | — | ✅ | 正常 |
| 21:10:28 | — | — | **120** | ❌ | （未回访） |
| 21:34:01 | — | — | **120** | ❌ | （未回访） |
| 21:42:27/52 | — | 命中 | **120 ×2** | ❌ | 空白（错拉抖音场） |
| 22:17:03 | 61 | 命中(微信) | 11 | ✅ +92ms | 正常 |
| 22:17:45 | 62 | 跳过 | 0 | ✅ +183ms | 正常 |
| **22:22:44** | **63** | **命中(汽水)** | **120** | **❌** | **空白** |

**规律：回放=120帧 → decoder 100% 不初始化；≤11 帧 → decoder 100% 正常。**

## 二、22:22 会话完整时间线（双端拼图）

```
22:22:37.769 客户端 ensureDisplay failed (DeadObjectException) → 自动重启服务器
22:22:38.783 客户端 ensureDisplay complete, displayId=63（服务器：38.754 建屏 id=63）
22:22:41.284 服务器 auto-prewarm: launched com.luna.music on display 63   ← 抢跑起点
22:22:41.3~44.3 汽水渲染 → 编码器出帧 → 全部堆入 earlyBinaryFrames
              （约 40fps × 3.06s ≈ 120 帧，缓冲撑满，开始丢头）
22:22:44.316 客户端 ensureDisplay reuse displayId=63（任务链二次拉起 44.316/44.323）
22:22:44.338 surfaceCreated
22:22:44.343 setBinaryHandler: id=63 handlerSet=true, bufferedFrames=120
22:22:44.343 setBinaryHandler: replaying 120 buffered frames
22:22:44.343 之后 ❌ 无 MediaCodec decoder initialized、无任何解码活动
22:23:28.343 shutdown → 释放 display 63
```
（对照 22:17:45 正常场：bufferedFrames=0 → 无回放 → +183ms 即 decoder 初始化 ✅）

## 三、代码级机制（坐标）

1. **队列满=丢头**：`ShowerController$videoSink$1.smali:84-109` —— `if (size>=120) removeFirst()` + `addLast(new)`（环形缓冲，最老的帧被挤掉）。
2. **csd 依赖帧内提取、不进则不活**：`ShowerVideoRenderer.smali:930-1100 onFrame` —— 每帧 `maybeAvccToAnnexb → findNalUnitType`，提取 SPS/PPS 存入 csd0/csd1；**csd0+csd1+surface 齐备才 `initDecoderLocked()`（:226-310）**。
3. **服务器=裸转发、csd 只在流开头发一次**：`androidx/lifecycle/w.smali` 三个发送点（:205/:263/:349）编码器 ByteBuffer 原样 `session.b([B)`；无配置帧重发机制。
4. **u2/j.b（:451-520）**：异常一次 → 静默清空 sink（h=）→ 永久停发、无日志（次要隐患）。
5. **竞态触发器**：预启动（v5）建屏后 ~2.5s 拉 app；面板 surfaceCreated 要等任务链 ensureDisplay（~5.5s）。这 ~3 秒的帧量决定生死（<120 活 / ≥120 死）。

## 四、为什么“有时正常、有时不正常”

- 微信首屏帧少（11 帧）→ 未丢头 → 正常 ✅
- 汽水（视频流内容丰富，~40fps）3 秒即 ≥120 帧 → 丢头丢 csd → 空白 ❌
- 即：空白概率 ≈ f（预启动→surface 之间的帧产量），与内容动态性正相关。

## 五、修复方向（v6 设计草案 · 待决策）

- **A. 服务器侧“配置帧周期性重发”（首选）**：在 `u2/j.b([B)` 缓存含 SPS/PPS 的帧（扫描 NAL type 7/8），每 ≥N 帧（如 2s）重发一份 → 客户端无论丢多少头，1-2 秒内解码器自愈。副作用：解码器接受重复 SPS/PPS 属标准行为，风险低。
- **B. 异常处理加固**：`u2/j.b` catch 不再静默清 sink（加日志/保留），便于定位。
- **C. 客户端建议（反馈官方）**：缓冲策略改“保头”或扩容；此为根治但动不了正版 app。
- **D. 工作流规避（不推荐）**：预启动延时至 ~6s 等 surface —— 牺牲提速收益且不稳定。

## 六、取证通道（本次新增资产）

- `logcat_shower.log`（22:42 起 · **专用监控**）：只抓 Shower*/ActionHandler，自动落盘、无污染。**【下次复现随跑随查】**
- `logcat_mon.log`（18:49 起）：宽过滤，含历史全部会话客户端日志。
- `lc_cap.txt*`：覆盖窗口仅 ~2-3 分钟（AI 推理日志洪流），勿单独依赖。
- `/data/local/tmp/shower.log`：服务器侧会话日志。

## 七、待办

1. [用户决策] 是否开发 v6（A+B）
2. [复现验收] 下次任务后查 `logcat_shower.log` 的 replaying/decoder 组合
3. [官方反馈] 客户端缓冲策略 + “不存在的 app 不报错”（合并网易云案）

*本记录与《机制解剖-虚拟屏打开》《机制血缘鉴定-打开与预启动》交叉引用。*

---

## 八、追加记录（22:50–22:57 · 四连样本实测）

**①汽水#2（display64）— 竞态复现#2 · 全链同构**
预启动命中 → bufferedFrames=120 → replaying120 → 无 decoder；AI侧 `W/ActionHandler: Shower WS screenshot returned no data` ×12 → 看主屏乱点 → 用户终止（52:44.826）。

**② WPS（display65）— “未拉起型空屏”（非竞态）**
任务='打开wps，找到垃圾吊考试题'（实际包 cn.wps.moffice_eng）；预启动 no map match；0帧、8张空屏截图（18870B）、no data×5、无 launch → 虚拟屏里什么都没有＝AI未找到/未拉起目标（类网易云案）。
※区分：竞态型（有画面但解码断） vs 未拉起型（根本没有画面可解码）＝两个不同故障类。

**③设置（display66）— “未拉起 · 未到 launch 步骤”**
任务全名='打开设置，找到键盘设置'（用户补充：AI当时在说“打开系统设置”之类）；watcher 因重试窗口错过 PhoneAgent 日志 → `no fresh task; skip (empty conf)`；0帧、no data×3；用户终止（54:58.993）。
※37秒对“AI完成打开动作”偏短（长城用了71秒）——此案本质是“慢＋用户提前终止”，非故障。

**④长城汽车（display67）— 慢但成功 · 打开之谜实锤**
- 55:35 建屏 → 71秒空屏期（no data×8：AI看主屏乱点，注入 TAP/KEY 无效）
- **22:56:46.808 `launchPackageOnVirtualDisplay: com.gwm.fusion` → started** ← 这就是“它说在框里输入长城汽车然后就打开了”的真相：**AI的“打开应用”工具动作**（指定 app 名 → 服务器 API 直拉）。不是巧合、不是其他东西；“输入长城汽车”与“打开”是同一动作的两面。
- +318ms decoder 初始化（56:47.171）→ 画面出现 → 后续 TAP 锁车操作成功；截图 vd_225651 = App 界面“已闭锁”。

**新指纹入库**
- **18870 字节 = 空屏 PNG**（无内容）；大图＝有画面。
- **`Shower WS screenshot returned no data` = 空白故障的 AI 侧信号**（出现即代表 AI 眼睛退化看主屏）。

**对 v6 的输入**
1. csd 重发修复后汽水类竞态根治；预启动价值兑现（免去 71 秒瞎忙）。
2. 任务侧改进（v6 之外）：映射扩展（wps→cn.wps.moffice_eng、长城→com.gwm.fusion、设置→com.android.settings，v6 后启用）；找不到 app 快速失败（官方反馈）。
3. watcher v4 边界：`-t3000`+3×0.5s 重试窗口在日志洪流下偶发错过 "starting first step"（后果仅“不预启动”，安全侧）——列优化项。

*追加：2026-09-20 23:12*
