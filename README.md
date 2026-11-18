# MacroSeek

一款免 Xcode、纯 AppKit + Swift 手写构建的 macOS 全局文件搜索工具。菜单栏常驻、热键唤出，支持文件名与文件内容双模式检索，并可按修改时间排序。

## 功能

- 全局搜索文档、图片、PDF 等几乎所有格式（自动跳过缓存、`.git`、`node_modules` 等目录）
- 搜索模式：文件名 / 文件内容（txt、md、csv、json 等纯文本，以及 `.docx` 正文抽取）
- 结果按**修改时间降序**排列，近期修改的排在最前
- Spotlight 秒出首屏 + 后台遍历补全（含已挂载的 SMB / WebDAV 网络卷，断开重连后自动恢复）
- 查询结果缓存，重复搜索瞬时返回
- 右侧 Quick Look 预览 + 文件信息（路径、创建/修改时间、大小、格式、匹配片段）
- 自定义全局热键（默认 `⌃⌥空格`）唤出/隐藏面板，点击外部或 Esc 关闭
- 菜单栏常驻、不显示 Dock 图标；支持开机自启动与静默启动
- 底部工具栏：打开、复制、在访达显示、复制路径、移动到、复制到、隔空投送、显示简介

## 构建

无需 Xcode，仅需 Command Line Tools（提供 `swiftc`、`iconutil`）：

```bash
./build.sh
```

产物为 `build/MacroSeek.app`。图标由 `Resources/render_icons.swift` 矢量生成：

```bash
cd Resources && swiftc render_icons.swift -o /tmp/render_icons && /tmp/render_icons "$(pwd)" && iconutil -c icns icon.iconset -o AppIcon.icns
```

## 安装

- 直接运行 `build/MacroSeek.app`，或使用发布页的 `MacroSeek.dmg` 拖拽安装到「应用程序」。
- 若需开机自启，建议把 App 放入 `/Applications` 后在设置中开启。

## 快捷键与设置

点击菜单栏图标 →「设置」，可录制自定义热键（必须含修饰键）、开关开机自启与静默启动。

## 已知限制

- PDF 仅支持文件名搜索，正文检索暂未支持
- 旧版 `.doc` 不支持内容检索
- 「显示简介」首次使用可能需要授予 Finder 自动化权限

## 许可

MIT
