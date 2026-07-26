# 发布部署指南

1. 确认版本在 `project.godot`、`config/app_config.gd` 和
   `export_presets.cfg` 中一致。
2. 运行快速、压力、UI 和需要时的 Supabase 测试。
3. 从干净源码生成产物，扫描包内是否存在密钥或签名材料。
4. 使用平台私有凭据签名；凭据不得进入仓库。
5. 在目标设备执行完整 QA，记录 SHA-256。
6. 上传 GitHub Release 或应用商店，而不是把私钥交给普通 CI。

当前发布产物状态：

| 平台 | 生成结果与发布要求 |
|---|---|
| Windows | CI debug 产物；公开发布前需 Windows QA，可选 Authenticode |
| macOS | CI ad-hoc debug 应用；公开发布前需 Developer ID、公证和 stapling |
| Linux | CI x86_64 debug 产物；公开发布前需 X11/Wayland QA |
| Android | CI debug 签名 APK；公开发布需私有 keystore 的 APK/AAB |
| iOS | CI unsigned Xcode 项目；分发需 Team ID、证书、profile、Archive/Export |

生成产物仅保留在本地或短期 CI artifact 中。选定的发布包应上传 GitHub
Releases 或平台商店，不进入默认分支。

Supabase 独立部署，见 [Supabase 指南](SUPABASE_GUIDE.md)。发布构建可以完全
离线；若启用排行榜，客户端只允许包含 publishable key。
