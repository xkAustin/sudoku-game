# Windows

## Prerequisites

Godot 4.7.1、Windows x86_64 导出模板；正式发布可准备 Authenticode 证书。

## Install Dependencies

安装 Godot 和匹配模板。最终 QA 需要 Windows 10/11。

## Configuration

预设：`Windows`；架构：x86_64；包名：
`io.github.xkaustin.sudokugame`。

## Build Command

```sh
godot --headless --path . --export-debug "Windows" build/windows/SudokuGame.exe
godot --headless --path . --export-release "Windows" build/windows/SudokuGame.exe
```

## Output Location

`build/windows/SudokuGame.exe`、`SudokuGame.pck` 和 console wrapper。

## Run Instructions

将 EXE、PCK 和 wrapper 放在同一目录，双击 `SudokuGame.exe`。

## Troubleshooting

若缺 PCK，重新导出整个目录。SmartScreen 警告需要 Authenticode 签名。请在
125%–200% DPI 下验证窗口、快捷键和文件选择器。
