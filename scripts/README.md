# Scripts

`scripts/` 是通用 JSON 管道和示例适配器。它们不包含 Swift UI。

| 脚本 | 输入 | 输出 | 职责 |
| --- | --- | --- | --- |
| [`all-toast.py`](all-toast.py) | `toast-notification` JSON | `validated`、`shown` 或结构化错误 | 校验通知并调用 Swift 渲染器 |
| [`monitor-to-notification.py`](monitor-to-notification.py) | `monitor-result` JSON | `toast-notification` JSON | 将领域结果转换成 Single 或 Digest |
| [`aihot-selected.py`](aihot-selected.py) | CLI 时间窗、分类和关键词 | `monitor-result` JSON | 公开 AIHOT API 的无密钥示例适配器 |

## 最小验证

```bash
python3 scripts/all-toast.py \
  --input examples/aihot-digest.json \
  --dry-run
```

## 管道调用

```bash
python3 scripts/aihot-selected.py --since-hours 24 --take 10 \
  | python3 scripts/monitor-to-notification.py \
      --input - --title "AIHOT 最近 24 小时精选" \
  | python3 scripts/all-toast.py --input - --dry-run
```

脚本必须把机器可读 JSON 写到 stdout；诊断信息应写到 stderr，避免破坏管道。
