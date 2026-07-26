# Sudoku Game 交付说明

Sudoku Game 是 Godot 4.7.1 开发的离线优先数独游戏，支持 Android、iOS、
macOS、Windows 和 Linux。无需账号，无广告或追踪 SDK；网络仅用于可选
排行榜。

## 方式 A：直接使用 Build

进入仓库根目录的 `builds/`，选择对应平台。每个目录都有 `BUILD_INFO.md`
记录版本、时间、环境、SHA-256 和签名状态。

- Windows：解压 ZIP，运行 `SudokuGame.exe`。
- macOS：解压 ZIP，将 `Sudoku Game.app` 移至“应用程序”。
- Linux：解压 `tar.gz`，运行 `sudoku-game.x86_64`。
- Android：安装 debug APK；公开发布前必须用私有 release key 重签。
- iOS：仓库不提供可安装 IPA；参见 iOS 构建文档自行签名。

交付包从不含 `config/client.env` 的干净源码副本生成，因此默认完全离线，
也不会把真实 Supabase 配置提交到 Git。若需要在线排行榜，请选择方式 B。

## 方式 B：从源码构建

安装 Godot 4.7.1 和相同版本导出模板，然后运行：

```sh
./tests/run_all.sh
godot --path .
```

如需在线排行榜，复制 `config/client.env.example` 为被忽略的
`config/client.env`，仅填写项目 URL 和 publishable key，并先部署 migration。

完整资料：

- [构建总览](BUILD_GUIDE.md)
- [发布部署](DEPLOYMENT_GUIDE.md)
- [Supabase](SUPABASE_GUIDE.md)
- [安全说明](SECURITY_GUIDE.md)

英文版：[English documentation](../en-US/README.md)
