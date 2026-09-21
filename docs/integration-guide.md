# 本地自动化路由

## 用途

根据用户目标选择本地自动化、云端自动化、信息采集和 macOS 展示路径。

## 什么时候用

用户提出“定时检查”“有更新提醒我”“每天生成简报”“使用 AIHOT 同款浮窗”或“复用本地自动化模板”时读取。

## 不适用场景

一次性信息查询不需要进入这里；直接使用对应的检索能力。

## 路由规则

| 用户目标 | 路径 |
| --- | --- |
| 在 Mac 上弹右下角提醒 | 本机 Codex 自动化 → 标准通知 JSON → `scripts/all-toast.py` |
| 每天展示多条情报面板 | 采集器 → 精选与去重 → `kind=digest` 通知 JSON |
| 只有一条紧急更新 | 采集器 → `kind=single` 通知 JSON |
| 复用 AIHOT 展示效果 | 读取 [`architecture.md`](architecture.md)，不要复制 AIHOT 采集脚本 |
| 搜索官网、公众号、社媒 | 先走 `web-research/routing.md`，再转换为标准通知 JSON |
| 查询 AIHOT 精选并接入提醒 | [`data-pipeline.md`](data-pipeline.md) → `scripts/aihot-selected.py` |
| 云端任务需要调用本机 App | 不直接调用；迁移或配对本机 Codex 自动化 |
| 飞书提醒或日程 | 走系统入口 `lark-router` |

## 操作流程

1. 明确任务运行环境；需要本机浮窗时必须在本机执行。
2. 采集原始信息并保留来源 URL、发布时间和来源类型。
3. 去重、核实、计算相关度和重要度。
4. 按 `schemas/monitor-result.schema.json` 生成领域监控结果。
5. 转换为 `schemas/toast-notification.schema.json` 通知 JSON。
6. 先用 `scripts/all-toast.py --dry-run` 验证，再实际展示。
7. 自动化只解释结构化状态，不重复浮窗正文。

## 常见错误

| 表现 | 原因 | 下一步 |
| --- | --- | --- |
| 云端任务没有 macOS 浮窗 | 云端无法运行本机程序 | 建立本机 Codex 自动化 |
| 图标或主题不符合预期 | 通知 JSON 没有传入主题字段 | 检查 `theme.symbol` 与 `theme.accent` |
| 同一条信息反复提醒 | 采集器没有稳定 ID 或状态文件 | 使用原文 URL、官方 ID 或内容哈希作为 ID |
| 社媒传闻被写成官方事实 | 精选层没有核实状态 | 标记 `pending`，并补查权威来源 |
| 自动化对话和浮窗重复正文 | 调度 prompt 职责过多 | 只返回 `shown` / `no_new` / 错误摘要 |

## 安全边界

- 对外发送消息、邮件、评论或发帖前必须确认。
- 不绕过验证码、登录限制或平台风控。
- 不在协议、配置和状态文件中保存 token、cookie 或密码。
- 暂停或替换现有自动化前，确认准确目标，避免两套任务重复提醒。

## 验证方式

- AIHOT 示例 JSON 能通过 `--dry-run`。
- 缺失标题、URL 或条目时能够返回明确错误。
- 单条通知和多条面板能分别路由到正确的渲染模式。
- 从根 `index.md` 可以找到本路由。
