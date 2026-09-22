# Shower 虚拟屏触控补丁 — 工作状态备忘
更新时间：2026-09-20

## 任务目标
修复 Android 16 (SDK 37) 荣耀设备上 Operit Shower 服务虚拟屏"能显示但点击无效"的问题。

## 根因（已确认）
/data/local/tmp/shower.log 报错：
java.lang.NoSuchMethodException: android.hardware.input.InputManager.getInstance []
Android 16 删除了 InputManager.getInstance()，Operit shower-server.jar 的 InputController
（混淆类 Lu2/f;）还在反射调用它 → InputController 初始化失败 → 所有注入失效。

## 修复方案
新 API 路径：
  InputManagerGlobal.getInstance()  (public static, 无参, 存在)
    └─ mIm 字段 (IInputManager)
        └─ injectInputEventToTarget(InputEvent, int mode, int targetDisplayId)  (3参)
字节码修改（u2.f.<init> 与 u2.f.a）：
 1. 类名 "android.hardware.input.InputManager" -> "android.hardware.input.InputManagerGlobal" (string@4121 改指)
 2. 方法名 "injectInputEvent" -> "injectInputEventToTarget" (string@5051 改指)
 3. getInstance().invoke() 得到 InputManagerGlobal 实例后，新增：
    getDeclaredField("mIm") -> setAccessible(true) -> field.get(global) -> 存字段 l
 4. 用 Field.getType() 拿到 IInputManager.class，在其上 getDeclaredMethod("injectInputEventToTarget",
    {InputEvent.class, Integer.TYPE, Integer.TYPE}) -> 存字段 m
 5. 注入方法 a(InputEvent)：args 从 2 元素 {event, mode} 改为 3 元素 {event, mode, displayId}
    displayId = 字段 o (由方法 g 设置)
 6. setDisplayId 查找段删除（原代码本来就永远失败，n 保持 null）

## 已完成
- [x] patch_dex.py 运行通过，生成 patch_state.json：
      init_off=0xb2d40, a_off=0xb2e88
      new_init_b64 (305字节), new_a_b64 (451字节)
      new_method_id: Field.getType()Ljava/lang/Class; = {class:1029, proto:613, name:4966}
      repoint_strings: {4121: "android.hardware.input.InputManagerGlobal",
                        5051: "injectInputEventToTarget"}
      new_strings: ["mIm", "android.hardware.input.IInputManager"]
- [x] 新字节码 preview 通过（含 rev() 字节序反转）
- [x] map list 解析完成（17 区）：
      0x0 header(1)@0; 0x1 string_id(6314)@0x70; 0x2 type_id(2013)@0x6318;
      0x3 proto_id(2238)@0x828c; 0x4 field_id(4267)@0xeb74; 0x5 method_id(8581)@0x170cc;
      0x6 class_def(1447)@0x27cf4;
      data 区@0x331d4: string_data(6308)@0x331d4; encoded_array(253)@0xe04f4;
      type_list(1590)@0xe41a4; code_item(6314)@0xe82d8; debug_info(37)@0x1089af;
      class_data(1334)@0x108c33; annotation_set(4)@0x115c09;
      annotation_set_ref_list(34)@0x115c1c; annotations_directory(29)@0x115d40;
      map_list(1)@0x115ff8

## 进行中：rebuild_dex.py（上次写到一半，被中断）
正在重写完整版。关键设计：
- string_ids 表 +2 条（6314->6316）：新 string_id 6314="mIm", 6315="android.hardware.input.IInputManager"
- method_ids 表 +1 条（8581->8582）：Field.getType()Ljava/lang/Class;
- 表区扩展：string_ids +8 字节, method_ids +8 字节 => data 区起点 0x331d4 +16 = 0x331e4
- string_data 区尾部插入 4 条新 string_data（113 字节）：
  "mIm"(5B), "android.hardware.input.IInputManager"(41B),
  "android.hardware.input.InputManagerGlobal"(41B), "injectInputEventToTarget"(26B)
- 各数据区平移量：string_data +16；其后各区 +16+113=+129
- 两个 code_item 必须保持原大小（init=331B, a=487B），用等大 tries/handlers 结构凑：
  init: 3 条 try_item + 3 个 handler blob（总15B）
    (0x34,0x5b,E->0x82), (0x5b,0x65,NSME->0x82,E->0x82), (0x69,0x81,E->0x82)
  a: 5 条 try_item + 5 个 handler blob（总23B）
    (0x0c,0x2c,ITE->0x6b,E->0x3a), (0x2c,0x3a,E->0x3a), (0x3c,0x53,E->0x3a),
    (0x55,0xaf,E->0x3a), (0xaf,0xb0,E->0x3a)
  注：0x3a/0x3b 保留原 handler 指令（move-exception v9; goto 0xb0）
- 需要修复的跨区 off：
  1. string_ids[].string_data_off += +16（6314 条）；4121/5051 改指新字符串；6314/6315 赋新 off
  2. proto_ids[].parameters_off（非0）+= +129
  3. class_defs[].class_data_off/annotations_off/static_values_off（非0）+= +129
  4. 所有 code_item 的 debug_info_off（非0）+= +129（遍历 6314 个 code_item）
  5. 所有 class_data 里 encoded_method 的 code_off += +129（遍历 1334 个 class_data，
     uleb 重编码；若长度变化则把整个 class_data 重写到文件尾并更新 class_defs[].class_data_off）
  6. annotations_directory(29个) 内部 off += +129
  7. annotation_set_ref_list(34个) 内部 off += +129
  8. annotation_set_item(4个) 内部 off += +129
  9. 重建 map_list，更新 header（file_size/map_off/data_off/data_size/各 size）
  10. checksum = adler32(data[12:])；signature = sha1(data[32:])
- 类型索引：E=979, ITE/NSME 运行时查；InputEvent=241, Integer.TYPE field@07c0

## 验证步骤（完成后）
1. dexdump 反汇编 patched dex，检查 u2/f.<init> 和 u2/f.a 新字节码
2. 替换 jar 内 classes.dex：/storage/emulated/0/Download/Operit/shower-server.jar
   和 /data/local/tmp/shower-server.jar（备份：shower-server-original.jar / shower-server.jar.bak）
3. 杀掉旧 app_process(shower server)，让 Operit 重新拉起
4. run_subagent_virtual 建虚拟屏 -> am start --display 启动计算器 -> 点击验证
5. 观察 /data/local/tmp/shower.log 是否还报 getInstance NoSuchMethodException

## 回滚方案
shower-server.jar.bak 和 shower-server-original.jar 是原文件，覆盖回去即可。

## 最终状态（2026-09-21 00:21 收工）✅
- 触控修复已并入 v6 交付并部署：shower-server-v6.jar md5=43fd817e4f35b7914a0b7e92effa1642（4 副本一致；watchdog SRC=v6）
- 运行实证：InputController initialized（不再 NoSuchMethodException）；`Binder TAP injected (1151,208)/(714,208) on 70`、`Binder KEY injected 29/67/279 on 70`；`v6: cached SPS frame`
- 验收：测试2/3/4 全通过 + hc.sh PASS=18 FAIL=0（HEALTHY）——详见《夜班状态-20260921.md》《手册 v1.0》§6
- 回滚：sh /sdcard/Download/Operit/rollback_to_v5.sh（或原版覆盖）
- 注：本文件为过程档案；最终交付与验收口径以上述记录为准。

---

## 后续版本记录（空白自愈线 v7→v9 · 2026-09-21）
- v7（1163916B，md5 `5b8ed720f1446ffc206352b422e31dd9`）：首版 SPS/PPS/IDR 缓存+重发补丁 —— **失败**（扫描器坏件 + 跳转错位，零日志）
- v8（1163914B，md5 `3940e19b9ccbf95b0dbacb2b311879f1`）：修正跳转方向 —— **仍失败**（独立字节级实验证明：NAL 扫描器自 v6 起即为坏件）
- v9（1163819B，md5 `038be08b890c430b9e032642898a84e9`）：重写 v9NalMask 扫描器 + 缓存守卫/重发判定修正 —— **成功**
  - 实机验收（07:28，display81 单会话）：`v9: cached SPS/PPS/IDR` + `v9: periodic resend done` ×4；画面渲染正常；测后无残留
  - 部署：`sh /sdcard/Download/Operit/deploy_v9.sh`；回滚：`rollback_to_v8.sh`；恢复：`restore_chain_v5.sh`；构建套件：`v9_build_kit.tar.gz`
- **关键教训**：判定补丁是否生效，禁止只看“日志标记”（v6 `cached SPS frame` 为错位假象）；必须①独立小程序字节级实验 ②实机全链路日志 ③hc.sh 全绿。
- v9.1（1163846B，md5 `e8c1b771e34aa523cde83af3139aa41a`）：**黑闪修复**（窗口化重发）—— v9 上线后发现“约 1.5 秒一黑闪”（节奏与 v9 每 60 帧永久重发完全吻合）；v9.1 将重发改为「前 6 次（60~360 帧）保护 + 360 帧后永久静默」（相对 v9 仅改两处：重发判定块 `rem-int`/`0x168` + 日志串 `v9.1:`）
  - 构建四层复核全绿：构建链 / dex 指纹同源 / 字符串指纹 / 环回反编译
  - 实机双场景验证：美团（~4fps）6 次 ≈1 分钟跑完 + 静默 ≥5 分钟；腾讯视频（60fps）6 次仅 5.16 秒 + 静默；用户确认“不闪了”
  - 部署：`sh /sdcard/Download/Operit/deploy_v9_1.sh`（含 hc v7 / 恢复链 v6 升版）；回滚：`rollback_to_v9.sh`；恢复：`restore_chain_v6.sh`；构建套件：`v9_1_build_kit.tar.gz`
- 2026-09-21 11:01 抢跑哨兵 v5.1：`find_task` 正则 `\[[0-9a-f]+\]` → `\[[0-9A-Za-z_]+\]`（数字/下划线开头 token 不再漏判）；备份 `.bak-v5-hexfix-20260921`；双副本 md5 `6310d34b128e9eb3ad4bcb2a6a040442`；`--resolve` 验证通过（美团→com.sankuai.meituan）；仿真对照：新正则命中 `[mt_2]`，旧正则 NO_MATCH。
- 2026-09-21 11:12 哨兵复验：kill 旧进程（旧代码）→ 看护 `11:12:44` 自动拉起（`restarted prewarm_watcher`），新 PID 16302 加载 v5.1（`started 11:12:44`）；hc.sh PASS=19 FAIL=0。
- 2026-09-21 11:20 功能对账报告落地：`功能对账-改动在用清单-20260921.md`；现场无残留（卡/窗口/虚拟屏层=0）。- 2026-09-21 11:35 重生路线文档落地：重生路线-从原版到虚拟屏可用-20260921.md（全故事+从零重建路线；已同步 kit/docs 与 Download 根目录）
- 2026-09-21 14:55 日志监控三项（blackbox / shower专用 / logcat_mon）按用户要求撤下（默认 OFF，可选恢复）。新增开关脚本 mon.sh（up/down/status）；hc.sh 升 v7.1（监控项改为可选，撤下时显示 INFO）；restore_chain.sh 升 v6.1（monitors_off.flag 存在则不拉起监控）；备份 hc.sh.bak-v7-20260921 / restore_chain.sh.bak-v6-20260921。
- 2026-09-21 14:53 实机验证：hc.sh PASS=16 FAIL=0 HEALTHY（监控三项 INFO）；restore_chain v6.1 空跑通过（4b skipped）；mon.sh status=OFF-by-user。
