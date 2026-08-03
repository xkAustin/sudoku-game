# Sudoku Game 开源项目

Sudoku Game 是 Godot 4.7.1 开发的离线优先数独游戏，支持 Android、iOS、
macOS、Windows 和 Linux。无需账号，无广告或追踪 SDK；网络仅用于可选
排行榜。

本 GitHub 仓库保存源码、assets、测试、后端 migration、技术文档和可复现
构建流程；默认分支不追踪生成的应用程序或安装包。

## 方式 A：下载 Release

维护者发布预构建版本时，请从
[GitHub Releases](https://github.com/xkAustin/sudoku-game/releases) 下载。
Release 说明应标明平台、版本、校验值、签名状态和剩余 QA 限制。没有 Apple
签名时不提供可安装 iOS IPA。

## 方式 B：从源码构建

安装 Godot 4.7.1 和相同版本导出模板，然后运行：

```sh
./tests/run_all.sh
godot --path .
```

Debug 运行会进入开发快捷页；按 `F12` 可打开运行时调试面板。参数热重载、直接
打开设置/排行榜/测试棋盘及正式版本隔离方式见[开发模式指南](DEVELOPMENT_GUIDE.md)。

如需在线排行榜，复制 `config/client.env.example` 为被忽略的
`config/client.env`，仅填写项目 URL 和 publishable key，并先部署 migration。

本地导出写入被忽略的 `build/` 或 `builds/`；公开安装包应发布到 GitHub
Releases 或平台商店，不进入默认分支。

完整资料：

- [构建总览](BUILD_GUIDE.md)
- [开发模式](DEVELOPMENT_GUIDE.md)
- [发布部署](DEPLOYMENT_GUIDE.md)
- [Supabase](SUPABASE_GUIDE.md)
- [安全说明](SECURITY_GUIDE.md)

英文版：[English documentation](../en-US/README.md)
