# All Toast for Mac 架构

## 用途

把信息采集、精选判断和 macOS 展示拆开，让新闻、招聘、服务状态等不同监控共享同一套原生提醒资产。

## 什么时候用

- 将已有监控接入 macOS 原生浮窗。
- 新建“每天一份简报”或“重要变化即时提醒”。
- 复用状态去重、来源核实、错误状态和展示模板。

## 不适用场景

- 单次检索或临时总结。
- 数据没有原始来源链接，且无法追溯真实性。
- 只能在云端运行、又没有本机接力任务的自动化。

## 架构

```text
来源适配器
    ↓
标准化、去重、核实、精选
    ↓
monitor-result JSON（领域数据）
    ↓
toast-notification JSON（single / digest）
    ↓
All Toast for Mac
    ↓
macOS 单条浮窗或多条面板
```

职责边界：

- 来源适配器只负责读取原始信息。
- 精选层判断可信度、相关度、重要度和行动建议。
- 通知协议只描述要展示什么。
- Swift 渲染器只负责界面、链接、持续时间和提示音。
- 自动化只负责定时运行、解释状态和报告失败。

## 通知协议

协议文件：[`toast-notification.schema.json`](../schemas/toast-notification.schema.json)。

### 单条提醒

用于紧急或直接相关的更新：

```json
{
  "schemaVersion": 1,
  "kind": "single",
  "title": "重要更新",
  "message": "一句话说明变化和影响。",
  "detail": "展开后显示证据、影响和行动。",
  "url": "https://example.com",
  "duration": 30
}
```

### 多条简报

用于固定时间的摘要：

```json
{
  "schemaVersion": 1,
  "kind": "digest",
  "title": "每日情报",
  "subtitle": "最近 24 小时 · 1 条",
  "items": [
    {
      "id": "stable-id",
      "title": "信息标题",
      "time": "今天 09:12",
      "summary": "变化、影响与必要行动。",
      "source": "Official Source",
      "verification": "verified",
      "url": "https://example.com"
    }
  ]
}
```

`source`、`verification`、`action` 等字段属于长期协议。渲染器展示这些字段，但不自行判断事实是否可靠。

## 监控结果协议

采集器不要直接拼浮窗命令，应先输出领域结果：

```json
{
  "status": "ok",
  "monitor": "example-monitor",
  "checkedAt": "2026-09-16T10:00:00+08:00",
  "windowStart": "2026-09-15T10:00:00+08:00",
  "windowEnd": "2026-09-16T10:00:00+08:00",
  "items": [],
  "errors": []
}
```

长期状态集合：

- `ok`：完成采集和精选。
- `no_new`：没有未展示的新内容。
- `partial`：部分来源失败，其他来源已完成。
- `fetch_failed`：主要来源不可用，无法形成可信结果。
- `invalid_output`：输出不满足协议。
- `shown`：已经调用本地渲染器。
- `render_failed`：通知数据正确，但渲染失败。

## 精选规则

每条领域信息至少保留：

```text
id / title / summary / source / sourceType / publishedAt / url
verification / relevance / importance / action / deadline
```

通用判断顺序：

1. 先判断来源是否可信。
2. 再判断是否与用户目标直接相关。
3. 再判断是否存在明确变化或时间节点。
4. 去除重复、转载和没有新增事实的内容。
5. 保留原始链接，摘要不得冒充原文引用。

社交平台内容默认是线索。只有找到官网、政府或明确的官方账号证据后，才能标记 `verified`；否则使用 `pending`。

## 操作流程

### 构建原生渲染器

```bash
./renderer/build-app.sh
```

构建产物位于：

```text
renderer/dist/All Toast for Mac.app
```

`scripts/all-toast.py` 默认调用这个 App 内的可执行文件，也可通过 `ALL_TOAST_RENDERER` 指定其他构建位置。

### 新接入一个监控

1. 写来源清单和可信度顺序。
2. 确定稳定 ID 与本地状态文件。
3. 输出 `monitor-result` JSON。
4. 将精选结果转换为通知协议。
5. 先运行：

```bash
python3 scripts/all-toast.py \
  --input examples/aihot-digest.json \
  --dry-run
```

6. 取消 `--dry-run` 后进行一次真实展示。
7. 自动化 prompt 只调用统一入口并解析状态。

### AIHOT 示例

公开示例保留 AIHOT 的 API、时间窗和精选语义，只把最终结果转换成通用协议：

```bash
python3 scripts/aihot-selected.py --since-hours 24 --take 10 \
  | python3 scripts/monitor-to-notification.py \
      --input - --title "AIHOT 最近 24 小时精选" \
  | python3 scripts/all-toast.py --input - --dry-run
```

接入真实自动化时，应保证相同窗口的条目稳定、已展示内容不会重复提醒、无新内容不会生成空面板。

## 常见错误

### 把搜索和展示写在同一个脚本

来源变化会影响 UI，UI 升级也会影响采集。应先生成标准 JSON，再调用渲染器。

### 把本地接口过早做成公网 API

单机自动化阶段优先使用稳定的命令行 JSON 接口。只有出现多设备或多人调用需求时，再包装 HTTP API。

### 为每个领域复制一套 App

这会产生多套 Swift UI、状态工具和错误协议。应共享渲染器与公共协议，只在私有项目中新增领域适配器。

## 安全边界

- 不保存认证秘密。
- 不绕过平台限制抓取内容。
- 不把待核实线索写成确定事实。
- 自动化产生外发消息前必须确认；本地浮窗不属于对外发送。
- 私人监控的来源、关键词、状态和配置不进入通用框架仓库。

## 验证方式

```bash
python3 scripts/all-toast.py \
  --input examples/aihot-digest.json \
  --dry-run
```

随后至少验证一次单条真实浮窗和一次多条真实面板。自动化接入后，再验证去重、无新内容、部分来源失败和渲染器缺失四种状态。
