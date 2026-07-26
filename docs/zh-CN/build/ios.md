# iOS

## Prerequisites

macOS、Godot 4.7.1 iOS 模板、Xcode、可用 iOS SDK、Apple Developer Account、
Team ID、签名证书和 Provisioning Profile。

## Install Dependencies

安装 Xcode/Command Line Tools、接受许可并安装匹配设备/模拟器 runtime。

## Configuration

预设：`iOS`；bundle ID `io.github.xkaustin.sudokugame`；保持
`application/export_project_only=true`。在本地填写真实 Team ID；不得提交
证书、profile 或私钥。

## Build Command

```sh
godot --headless --path . --export-debug "iOS" build/ios/SudokuGame.ipa
open build/ios/SudokuGame.xcodeproj
```

## Output Location

Godot 生成 `build/ios/SudokuGame.xcodeproj` 及框架；Xcode Archive/Export
生成签名 IPA。

## Run Instructions

在 Xcode 选择 Signing Team 和目标设备，Build/Run；发布用
Product → Archive → Distribute App。

## Troubleshooting

空 Team ID 会阻止导出；仅生成项目时可在一次性副本使用 `CIUNSIGNED`，随后
必须在 Xcode 替换。`No eligible destination` 表示缺少匹配 runtime/设备。
最终必须在 iPhone/iPad 验证安全区、文件选择、触感和后台恢复。
