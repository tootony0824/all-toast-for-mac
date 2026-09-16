# 信息获取与精选接口

## 用途

为不同信息源提供统一的本地 JSON 接口，让采集、精选、通知转换和 macOS 展示可以独立组合。

## 什么时候用

- 将公开 API、官网或其他来源接入 All Toast for Mac。
- 替换采集脚本，同时保持通知层和 Swift 展示层不变。
- 测试时间窗、检索条件和标准输出字段。

## 不适用场景

- 单次临时搜索。
- 需要公开部署、多用户访问或跨设备调用的服务；当前接口是本地命令行 API。
- 需要绕过验证码、登录限制或平台风控的采集。

## 接口分层

```text
来源适配器                 监控结果                    通知转换                 展示
aihot-selected.py  →  monitor-result JSON  →  notification JSON  →  all-toast.py
```

来源适配器只负责把来源数据转换成统一监控结果。它不显示浮窗，也不向外部服务发送消息。

## 监控结果

Schema：[`schemas/monitor-result.schema.json`](schemas/monitor-result.schema.json)。

必需字段：

- `status`：`ok`、`no_new`、`partial` 或 `fetch_failed`。
- `monitor`：稳定的监控标识。
- `checkedAt`：实际检查时间。
- `windowStart`、`windowEnd`：数据窗口。
- `items`：标准化信息条目。
- `errors`：部分或全部来源失败信息。

每条 item 应有稳定 ID、标题、摘要、来源、发布时间和原始 URL。可信度、相关度、重要度和行动建议由来源适配器或后续精选器补充。

## AIHOT 公开适配器

```bash
python3 scripts/aihot-selected.py --since-hours 24 --take 50
```

支持：

- `--since-hours 1..168`：明确滚动时间窗。
- `--take 1..100`：返回条数上限。
- `--category`：模型、产品、行业、论文、技巧。
- `--query`：服务端关键词检索。

适配器使用 AIHOT 的公开匿名 API，并按 AIHOT 的推荐规则读取精选池。请求会携带浏览器 User-Agent，以符合该公开接口的访问要求。它不需要 API key，也不保存认证信息。

这个适配器面向“最近 AI 动态”一类滚动窗口。用户明确需要固定日报或全部条目时，应在独立适配器中使用相应接口，不应偷偷改变此脚本的精选语义。

## 监控结果转通知

```bash
python3 scripts/monitor-to-notification.py \
  --input result.json \
  --title "AIHOT 最近 24 小时精选"
```

条目为 1 条时默认生成 `single`，多条时生成 `digest`。可用 `--kind` 明确指定。

## 完整管道

```bash
python3 scripts/aihot-selected.py --since-hours 24 --take 10 \
  | python3 scripts/monitor-to-notification.py \
      --input - --title "AIHOT 最近 24 小时精选" \
      --symbol flame.fill --accent systemOrange \
  | python3 scripts/all-toast.py --input - --dry-run
```

去掉 `--dry-run` 才会实际展示 macOS 浮窗。

当监控状态为 `no_new` 时，转换器会拒绝生成空面板。是否静默、显示一条“暂无更新”短提醒或记录运行状态，应由监控编排器明确决定，不能伪造 item。

## 新适配器约定

新接入一个信息源时，只需遵守监控结果 Schema：

1. 为每条信息生成稳定 ID。
2. 保留原始来源、发布时间和 URL。
3. 明确区分 `verified` 与 `pending`。
4. 来源部分失败时返回 `partial` 并列出错误。
5. 不要在适配器中耦合 AppKit 展示代码。

网页、浏览器和 API 的采集方式可以不同。框架复用的是统一输出协议，不要求所有来源拥有相同的采集实现。领域私有适配器、关键词和状态文件应留在私有项目中，不提交到这个通用仓库。

## 常见错误

| 表现 | 原因 | 下一步 |
| --- | --- | --- |
| 返回空数组 | 时间窗内没有精选条目 | 返回 `no_new`，不要伪造摘要 |
| 关键词没有结果 | 关键词、时间窗或类别过窄 | 保留条件并允许调用方调整 |
| 摘要缺失 | 来源没有生成摘要 | 使用简短占位说明，不冒充原文 |
| 时间显示不正确 | 直接展示 UTC | 通知转换器统一转换为本地时间 |
| 管道中断后出现 Python 堆栈 | 下游提前关闭 | 调度层记录失败环节，不把堆栈展示给普通用户 |

## 安全边界

- 不保存 token、cookie 或密码。
- 不绕过验证码或访问控制。
- 来源失败时如实返回 `partial` 或 `fetch_failed`。
- 摘要是整理内容，不作为原文直接引用。

## 验证方式

1. AIHOT 适配器输出可以被 JSON 解析。
2. 输出满足监控结果 Schema 的必需字段。
3. 完整管道在 `--dry-run` 下返回 `validated`。
4. 无结果时转换器不生成空面板。
5. 网络失败时返回结构化 `fetch_failed`，而不是未处理异常。
