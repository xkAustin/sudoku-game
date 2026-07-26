# 构建指南

项目版本为 `1.0.0`，Godot 版本为 `4.7.1.stable`，包名为
`io.github.xkaustin.sudokugame`。安装与 Godot 版本完全一致的导出模板。

源码构建输出统一写入被忽略的 `build/` 或 `builds/`。生成包不进入默认分支；
经过审核的公开包发布到 GitHub Releases 或平台商店。构建前：

```sh
./tests/run_all.sh
mkdir -p build/android build/ios build/macos build/windows build/linux
```

平台指南：

- [Windows](build/windows.md)
- [macOS](build/macos.md)
- [Linux](build/linux.md)
- [Android](build/android.md)
- [iOS](build/ios.md)

所有预设排除 `backend/`、`tests/` 和 `build/`。本地
`config/client.env` 可包含公开客户端配置，但不得包含 `service_role`、密码、
证书或签名密钥。正式发布前必须在目标系统执行启动、主菜单、生成、输入、
完成、上传和排行榜查看测试。

已提交的 CI 将第三方 Action 固定到不可变提交，并使用官方 SHA-512 清单
校验 Godot 4.7.1 下载。CI 仍只生成 unsigned/debug 包，不能替代平台签名和
目标设备 QA。
