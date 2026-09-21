# JSON Schemas

`schemas/` 定义数据源、转换器和 Swift 渲染器之间的稳定协议。

| Schema | 生产者 | 消费者 | 用途 |
| --- | --- | --- | --- |
| [`monitor-result.schema.json`](monitor-result.schema.json) | 来源适配器 | `monitor-to-notification.py` | 表示一次采集、标准化和精选的结果 |
| [`toast-notification.schema.json`](toast-notification.schema.json) | 通知转换器或调用方 | `all-toast.py` | 描述最终要展示的 Single 或 Digest |

标准管道：

```text
source adapter
    ↓
monitor-result JSON
    ↓
monitor-to-notification.py
    ↓
toast-notification JSON
    ↓
all-toast.py
    ↓
All Toast for Mac.app
```

新增字段时应保持向后兼容；破坏性变更需要提升 `schemaVersion` 并同步更新示例、转换器和渲染入口。
