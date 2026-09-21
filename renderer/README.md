# Renderer

`renderer/` 是 All Toast for Mac 的 Swift + AppKit 展示层，只负责窗口、交互和 App 构建，不包含领域采集或业务筛选逻辑。

## 内容

| 路径 | 作用 |
| --- | --- |
| `Package.swift` | Swift Package、平台版本和可执行 Target 声明 |
| `Sources/AllToastForMac/main.swift` | Single Toast、Digest Panel、CLI 参数和 App 生命周期 |
| `build-app.sh` | 将 Swift 源码编译并封装为 `.app` |
| `.build/` | 本地编译缓存，已被 Git 忽略 |
| `dist/` | 本地 App 构建产物，已被 Git 忽略 |

## 构建

从仓库根目录运行：

```bash
./renderer/build-app.sh
```

产物：

```text
renderer/dist/All Toast for Mac.app
```

## 直接调用

```bash
"renderer/dist/All Toast for Mac.app/Contents/MacOS/all-toast-for-mac" --help
```

业务调用方应优先使用 [`scripts/all-toast.py`](../scripts/README.md)，由它负责通知数据校验和 Digest 临时文件管理。
