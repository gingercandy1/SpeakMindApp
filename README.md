# speakmind

Pronunciation practice

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## F0: 关卡框架（大框已搭好，内容待填）

SpeakMind 的游戏化关卡按「先拉大框，再填细节」分阶段开发。F0 只搭结构，不填教学内容。

- **关卡图谱**：`assets/levels_es.json`，JSON 驱动，共 138 个节点 —— 主线 80（8 个世界 × 10 关）、分支 42（W2 起每世界 2 条支线 × 3 关）、隐藏 16（每世界 2 关）。每关字段见 `lib/levels.dart`：`id / kind / world / title / next / branches / hidden_trigger / pass_gop` 等。
- **数据模型**：`lib/levels.dart`（`WorldInfo`、`LevelNode`、`LevelBranch`、`HiddenTrigger`、`LevelGraph`）、`lib/progress.dart`（`ProgressStore`，SharedPreferences 持久化：解锁关卡 + 星星 + XP + 已发现隐藏关，默认只解锁 `1-1`）、`lib/theme.dart`（策划定稿配色：奶油底、深青主色、行动绿、琥珀、陶土红）。
- **世界地图**：`lib/pages/map_page.dart` —— 8 个世界沿路径排布，之字形主线节点、岔路口两条支线列、已发现的隐藏关（金星）、未解锁世界显示云雾；底部导航 4 个标签：地图、邮票册、练习场、我的（`lib/pages/home_page.dart`）。
- **占位关卡页**：`lib/pages/level_page.dart` —— 显示关卡编号/标题与单关六步大纲，「模拟通关 ★★★」按钮用于测试解锁逻辑。
- **原有功能不变**：练习场（`PracticePage`）与聊天页（`ChatPage`，含语音输入）仍在底部导航里正常使用。

### F0 验收标准（来自策划文档）

- 图结构与配置字段定稿；地图能渲染任意节点关系；
- 用假数据展示岔路口与隐藏节点；解锁集合逻辑正确；
- 杀掉进程后进度仍在（SharedPreferences）。

### 接下来（F2）

做分支引擎 + W3–W5 主线内容，再做 Brasa 的基础表情与邮票发放（F2）；隐藏关触发引擎是 F3。

## F1: W1–W2 主线内容与单关六步玩法

- **教学内容**：`assets/levels_es.json` 里 W1–W2 主线 20 关已填真实内容 —— 每关 5–8 个单词、2–3 句核心句、NPC 对话提示（`npc_prompt`）、开场白（`dialogue_opening`）、Brasa 剧情引入（`intro`）、挑战任务与评分标准、变式挑战句；`content_todo: false`。W1 过关线 GOP 60、对话 4 轮，W2 过关线 GOP 65、对话 5 轮；发音重点 W1 为重音位置与 ñ，W2 增加 r / rr 对比（只提示）。其余 118 个节点仍为 TODO。
- **单关六步**：`lib/pages/level_page.dart` —— ① 剧情引入（Brasa 中文引入 + NPC 开场白 TTS）→ ② 热身卡片（逐词录音，轻量 /assess 打勾，不评分，可跳过）→ ③ 跟读闯关（核心句 /assess 评分，3 句中 2 句达线过关）→ ④ 情境对话（语音优先，`es_ES` 语音输入进可改的输入框再发送；打字收在「打字」开关后；提示给整句，可填入输入框，W1–W2 不限次数；NPC 回复自动朗读）→ ⑤ 挑战任务（变式句录音评分，过关线达标，≥90 分判出色）→ ⑥ 结算（星星 + XP，经 `ProgressStore.completeLevel` 解锁下一关）。
- **星星规则**（`lib/level_scoring.dart`，纯函数可测）：1★ = 对话轮数够 + 挑战过关；2★ = 1★ + 发音平均分达过关线（跟读句 + 挑战句的平均分，未评分的算 0 分；对话轮次是自由说话，无法 GOP 评分，不计入平均分）；3★ = 2★ + 挑战句 ≥90 分。
- **新文件**：`lib/level_scoring.dart`（星星/平均分纯函数）、`lib/level_recorder.dart`（16 kHz 单声道 WAV 录音小封装）；`lib/api.dart` 的 `chat()` 增加可选 `levelId` / `npcPrompt` 参数（按策划文档 §8 的约定发给服务器）。
- **注意（诚实说明）**：服务器目前会忽略 `level_id` / `npc_prompt` 这两个字段（serde 默认忽略未知字段，`chat.rs` 只认 `messages` + `language`），所以 NPC 的完整人设要等服务端的小改动才生效；现阶段对话靠 `dialogue_opening` 作为第一条 NPC 消息 + 通用系统提示来撑。挑战的「任务完成」判定目前是客户端用 /assess 给变式句打分的代理，等服务端返回 `task_done` 后再换。关卡中途退出不保存进度（后续打磨再做）。
- **测试**：`test/level_content_test.dart` —— 20 关内容完整性（字段齐全、词句数量、"es — zh" 格式、过关线/轮数）+ 星星规则单元测试。

### F1 验收标准（来自策划文档 §9）

- W1–W2 20 关主线全是六步完整流程；真机上 1-1 → 2-10 全程可用语音打通；离线时关卡能打开（内容在本地 JSON 里），需要服务器的步骤在断网时显示明确错误 + 重试，不静默放行。
