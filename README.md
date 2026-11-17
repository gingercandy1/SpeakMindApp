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

### 接下来（F1）

填 W1–W2 主线 20 关的真实内容（单词、句型、NPC 对话提示、挑战任务），实现单关六步玩法与发音评分接入；再做 Brasa 的基础表情与邮票发放（F2）。
