# Contributing

感谢你改进 All Toast for Mac。这个项目的核心边界是：通用渲染器负责展示，业务项目负责采集、判断、去重和调度。

## 开始之前

- 不要把领域关键词、私人配置、token、cookie 或状态文件提交到仓库。
- 新的来源适配器必须输出统一 `monitor-result`，不要把采集逻辑写进 Swift 渲染器。
- UI 改动应同时检查 Single Toast 和 Digest Panel。
- 协议改动应同步 Schema、转换器、示例和 README。

## 本地验证

```bash
./renderer/build-app.sh
bash -n renderer/build-app.sh
python3 -m py_compile scripts/*.py
python3 scripts/all-toast.py --input examples/aihot-digest.json --dry-run
plutil -lint "renderer/dist/All Toast for Mac.app/Contents/Info.plist"
```

如果改动了 UI，请额外真实显示一次 Single Toast 和一次 Digest Panel。

## 提交范围

一个提交尽量只解决一类问题。提交前运行：

```bash
git diff --check
git status --short
```

构建缓存、App 产物、`.env` 和运行状态都不应进入 Git。
