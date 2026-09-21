# Examples

`examples/` 存放可以直接交给 `scripts/all-toast.py` 的通知数据。示例用于理解协议和验证渲染，不代表实时资讯。

| 文件 | 类型 | 说明 |
| --- | --- | --- |
| [`single-toast.json`](single-toast.json) | Single | 构建完成示例，用于验证标题、详情、链接、声音和主题 |
| [`aihot-digest.json`](aihot-digest.json) | Digest | 两条虚构 AIHOT 数据，用于验证卡片、来源、时间、主题和链接 |

运行：

```bash
python3 scripts/all-toast.py \
  --input examples/single-toast.json \
  --dry-run
```

去掉 `--dry-run` 会显示真实面板。
