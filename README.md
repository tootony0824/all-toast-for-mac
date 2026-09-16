# All Toast for Mac

一个原生、轻量、可脚本化的 macOS Toast 与信息摘要框架。使用 Swift + AppKit 构建，不依赖 Electron，不要求通知中心权限，适合接入自动化、监控脚本、CLI 工具和本地 Agent。

> Native and scriptable toast notifications for macOS, with single-card alerts, multi-item digests, themes, clickable links, and JSON-first automation APIs.

## 为什么做这个项目

许多自动化任务可以找到信息，却缺少一个克制、可点击、不会淹没通知中心的本地展示层。All Toast for Mac 把“信息从哪里来”和“提醒怎么展示”彻底分开：

```text
任意数据源
  ↓
monitor-result JSON
  ↓
notification JSON
  ↓
All Toast for Mac
```

渲染器不理解新闻、招聘或其他具体业务；它只负责把标准数据展示成好用的 macOS 浮窗。

## 功能

- 原生 AppKit 界面，支持 macOS 12 及以上版本。
- 右下角单条 Toast：标题、摘要、详情、原文链接、自动关闭。
- 右侧 Digest 面板：多条卡片、来源、时间、核实状态、滚动浏览。
- 点击 Toast 或卡片直接打开目标 URL。
- 支持 SF Symbols、自定义图标和系统主题色。
- 支持系统提示音、静音、定时关闭和常驻模式。
- 支持 JSON 文件与 stdin 管道输入。
- 通知协议与监控结果协议分离，便于替换采集器或渲染器。
- 不申请 Accessibility、Screen Recording 或 Automation 权限。
- 自带可分享的 AIHOT 适配器作为真实示例。

## 快速开始

环境要求：

- macOS 12+
- Xcode Command Line Tools
- Python 3.10+

构建原生 App：

```bash
./renderer/build-app.sh
```

产物：

```text
renderer/dist/All Toast for Mac.app
```

验证 AIHOT 多条通知，不显示界面：

```bash
python3 scripts/aihot-selected.py --since-hours 24 --take 10 \
  | python3 scripts/monitor-to-notification.py \
      --input - --title "AIHOT 最近 24 小时精选" \
      --symbol flame.fill --accent systemOrange \
  | python3 scripts/all-toast.py --input - --dry-run
```

去掉 `--dry-run` 即可真实显示。

## 单条 Toast

```json
{
  "schemaVersion": 1,
  "kind": "single",
  "title": "构建完成",
  "message": "All Toast for Mac 已经可以使用。",
  "detail": "点击打开项目主页。",
  "url": "https://github.com/tootony0824/all-toast-for-mac",
  "duration": 8,
  "sound": "Glass",
  "theme": {
    "symbol": "checkmark.seal.fill",
    "accent": "systemGreen"
  }
}
```

```bash
python3 scripts/all-toast.py --input single.json
```

## 多条 Digest

```json
{
  "schemaVersion": 1,
  "kind": "digest",
  "title": "每日情报",
  "subtitle": "最近 24 小时 · 1 条",
  "sticky": true,
  "theme": {
    "symbol": "newspaper.fill",
    "accent": "systemBlue"
  },
  "items": [
    {
      "id": "item-1",
      "title": "第一条更新",
      "time": "今天 09:12",
      "summary": "说明发生了什么，以及用户是否需要行动。",
      "source": "Official Source",
      "verification": "verified",
      "url": "https://example.com"
    }
  ]
}
```

完整协议见 [toast-notification.schema.json](schemas/toast-notification.schema.json)。

## 直接调用 Swift 可执行文件

```bash
"renderer/dist/All Toast for Mac.app/Contents/MacOS/all-toast-for-mac" \
  --title "New update" \
  --message "A new item is ready." \
  --detail "Click to open the original page." \
  --url "https://example.com" \
  --symbol "sparkles" \
  --accent "systemPurple" \
  --duration 12 \
  --sound Glass
```

也可以传入多条面板 JSON：

```bash
"renderer/dist/All Toast for Mac.app/Contents/MacOS/all-toast-for-mac" \
  --digest-json /path/to/digest.json \
  --sticky
```

## AIHOT 适配器

AIHOT 适配器会读取公开精选接口，输出统一 `monitor-result`，再交给通知转换器和 Swift 渲染器。支持：

- 1～168 小时滚动窗口。
- 1～100 条精选。
- 模型、产品、行业、论文和技巧分类。
- 服务端关键词检索。

```bash
python3 scripts/aihot-selected.py --since-hours 24 --take 20
```

AIHOT 只是适配器示例。新的监控任务只要输出 [monitor-result.schema.json](schemas/monitor-result.schema.json)，就可以复用同一套通知转换和展示层。

## 自定义渲染器路径

默认使用仓库构建的 App。也可以覆盖可执行文件路径：

```bash
export ALL_TOAST_RENDERER="/absolute/path/to/all-toast-for-mac"
```

旧的 `INFO_TOAST_RENDERER` 环境变量暂时保持兼容。

## 项目结构

```text
renderer/                           Swift + AppKit 原生渲染器
schemas/                            监控结果与通知 JSON Schema
scripts/all-toast.py                通知校验与渲染入口
scripts/monitor-to-notification.py  监控结果转通知
scripts/aihot-selected.py           AIHOT 来源适配器示例
examples/                           通知数据示例
templates/                          自动化 prompt 模板
```

## 设计边界

- All Toast for Mac 是本地展示框架，不负责绕过登录、验证码或平台限制。
- 来源采集、事实核实和相关度判断属于适配器职责。
- 社交平台线索应标记为 `pending`，不能冒充官方事实。
- 摘要不是原文引用，每条信息应保留可追溯 URL。
- 对外发送消息、邮件、评论或发帖不属于默认功能。

## 隐私

- 仓库不包含 token、cookie、密码、个人状态文件或本机用户名路径。
- `.env`、编译缓存、App 构建产物和运行状态默认忽略。
- 领域私有配置不应提交到通用框架仓库。

## License

[MIT](LICENSE)

## 进一步阅读

- [macOS 提醒框架](macos-info-monitor.md)
- [信息获取与精选接口](information-api.md)
- [目标路由](routing.md)
- [自动化提示词模板](templates/automation-prompt.md)
