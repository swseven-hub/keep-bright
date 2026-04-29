# Keep Bright（保持亮屏）

一个原生 macOS 菜单栏小工具。启动后默认开启保持亮屏，防止 Mac 屏幕因为长时间闲置而自动变暗或息屏。

它的目标很简单：像 One Switch 里的“保持屏幕常亮”一样，只做一件事，并且尽量符合 macOS 的原生使用习惯。

## 下载

前往 GitHub Releases 下载最新版本：

[下载 Keep Bright 最新版](https://github.com/swseven-hub/keep-bright/releases/latest)

当前发布包为 macOS Universal 版本，文件名类似：

```text
KeepBright-1.6.1-macOS-universal.dmg
```

下载后打开 DMG，将 `KeepBright.app` 拖到 `Applications` 文件夹，双击运行即可。Release 中也会保留 zip 包作为备用下载。

## 功能

- 启动后自动开启保持亮屏
- 支持永久、15 分钟、30 分钟、1 小时、2 小时定时模式
- 定时模式下在菜单栏显示剩余时间
- 支持开机自启动
- 支持偏好设置窗口
- 支持配置启动后是否自动开启保持亮屏
- 支持低电量电池保护，可按阈值自动关闭保持亮屏
- 支持自定义保持时长
- 支持两种防睡眠模式：仅保持屏幕常亮、保持屏幕常亮并防止系统闲置睡眠
- 支持低电量保护模式：关闭、仅提醒、自动关闭
- 支持插电后自动恢复保持亮屏
- 支持全局快捷键 `Option-Command-K`
- 支持菜单栏显示模式：只显示图标、剩余时间、防睡眠模式、状态文字
- 支持定时快速延长 15 或 30 分钟
- 支持通知偏好，分别控制状态、计时和电池通知
- 支持系统设置风格的侧边栏偏好设置窗口
- 支持首次启动引导
- 支持 DMG 拖拽安装包
- 支持关闭每日自动检查更新
- Release 页面会写明每个版本的更新内容、下载方式和校验信息
- 支持 Universal Binary，同时包含 Apple Silicon 和 Intel 架构
- 支持 GitHub Actions 自动构建 Release
- 开启、关闭和定时结束时发送系统通知
- 支持手动检查更新，并每天自动检查一次 GitHub 最新版本
- 菜单栏常驻，不占用 Dock
- 点击菜单栏图标可以开启、关闭或退出
- 退出应用时自动释放系统亮屏请求
- 支持 macOS 深色、浅色外观
- 不包含分析、广告或追踪 SDK

## 系统要求

- macOS 26.0 或更新版本
- Apple Silicon Mac 或 Intel Mac，当前构建目标为 Universal Binary（`arm64` + `x86_64`）
- 已安装 Xcode Command Line Tools 或 Xcode

本项目最初面向 M1 Mac 和 macOS 26.4.1 开发与验证。

## 工作原理

应用使用 Apple 原生的 IOKit Power Management API：

```swift
kIOPMAssertPreventUserIdleDisplaySleep
```

开启后，应用会创建一个 `PreventUserIdleDisplaySleep` power assertion。这个断言会阻止屏幕因为用户闲置而自动变暗或息屏。

需要注意的是，它不会阻止所有系统行为。例如合上 MacBook 屏幕、用户主动点击睡眠、电量过低或系统策略触发睡眠时，macOS 仍然可以让设备进入睡眠状态。

## 构建

进入项目目录后运行：

```sh
chmod +x build.sh
./build.sh
```

构建产物会生成在：

```text
build/KeepBright.app
dist/KeepBright-版本号-macOS-universal.dmg
```

构建脚本会完成这些步骤：

- 生成应用图标
- 使用 `swiftc` 分别编译 `arm64` 和 `x86_64` 可执行文件
- 使用 `lipo` 合并为 Universal Binary
- 组装标准 macOS `.app` 应用包
- 使用本地临时签名完成 codesign
- 生成带拖拽安装引导的 DMG 安装包

## 运行

双击运行：

```text
build/KeepBright.app
```

也可以通过命令启动：

```sh
open build/KeepBright.app
```

运行后应用不会出现在 Dock 中，只会显示在菜单栏。点击菜单栏里的杯子图标，可以看到：

- 当前保持亮屏状态
- 开启或关闭保持亮屏
- 选择保持时长
- 开启或关闭开机自启动
- 打开偏好设置
- 检查更新
- 关于信息
- 退出应用

默认全局快捷键为：

```text
Option-Command-K
```

可在任意应用中快速开启或关闭保持亮屏。你可以在偏好设置中关闭这个快捷键。

定时模式开启后，菜单栏会显示倒计时。倒计时结束时，应用会自动关闭保持亮屏，并通过系统通知提醒你。

应用会每天自动检查一次 GitHub Releases 是否有新版本。你也可以在菜单栏中点击“检查更新...”手动检查。如果发现新版本，应用会弹出原生提示并引导你打开下载页面。

偏好设置窗口使用类似系统设置的侧边栏布局，分为“常规、计时、电池、更新、通知、关于”。其中可以配置防睡眠模式、菜单栏显示模式、全局快捷键、启动后是否自动开启保持亮屏、自定义保持时长、是否每天自动检查更新、通知偏好、低电量保护模式、电量阈值，以及插电后是否自动恢复保持亮屏。电池保护只在使用电池供电时触发，连接电源时不会自动关闭。

## 验证是否生效

应用运行并开启保持亮屏后，可以通过下面的命令检查系统断言：

```sh
pmset -g assertions | grep KeepBright
```

也可以查看 `PreventUserIdleDisplaySleep` 是否为 `1`：

```sh
pmset -g assertions | grep PreventUserIdleDisplaySleep
```

如果看到类似下面的内容，说明保持亮屏已经生效：

```text
PreventUserIdleDisplaySleep    1
pid xxxx(KeepBright): PreventUserIdleDisplaySleep named: "Keep Bright"
```

## 项目结构

```text
.
├── Resources/
│   └── Info.plist
├── Sources/
│   └── KeepBright/
│       ├── AppDelegate.swift
│       ├── AppPreferences.swift
│       ├── AwakeDuration.swift
│       ├── BatteryMonitor.swift
│       ├── DisplaySleepAssertion.swift
│       ├── LoginItemManager.swift
│       ├── GlobalHotKeyManager.swift
│       ├── MenuBarDisplayMode.swift
│       ├── NotificationManager.swift
│       ├── PreferencesWindowController.swift
│       ├── SleepPreventionMode.swift
│       ├── UpdateChecker.swift
│       └── main.swift
├── Tools/
│   ├── create_dmg.sh
│   ├── make_dmg_background.swift
│   └── make_icon.swift
├── build.sh
├── .github/
│   └── workflows/
│       └── release.yml
├── LICENSE
├── PRIVACY.md
└── README.md
```

核心文件说明：

- `Sources/KeepBright/main.swift`：应用入口
- `Sources/KeepBright/AppPreferences.swift`：应用偏好设置持久化
- `Sources/KeepBright/AwakeDuration.swift`：保持时长选项和持久化
- `Sources/KeepBright/BatteryMonitor.swift`：电源状态和电池电量读取
- `Sources/KeepBright/AppDelegate.swift`：菜单栏图标、菜单和交互逻辑
- `Sources/KeepBright/DisplaySleepAssertion.swift`：IOKit 亮屏断言封装
- `Sources/KeepBright/GlobalHotKeyManager.swift`：全局快捷键管理
- `Sources/KeepBright/LoginItemManager.swift`：开机自启动管理
- `Sources/KeepBright/MenuBarDisplayMode.swift`：菜单栏显示模式
- `Sources/KeepBright/NotificationManager.swift`：系统通知管理
- `Sources/KeepBright/PreferencesWindowController.swift`：原生偏好设置窗口
- `Sources/KeepBright/SleepPreventionMode.swift`：防睡眠模式和电池保护模式
- `Sources/KeepBright/UpdateChecker.swift`：GitHub Release 更新检查
- `Resources/Info.plist`：应用元信息，包含菜单栏应用配置
- `Tools/make_icon.swift`：生成 `.icns` 图标资源
- `Tools/create_dmg.sh`：生成 DMG 拖拽安装包
- `Tools/make_dmg_background.swift`：生成 DMG 背景图
- `build.sh`：无 Xcode 项目的轻量打包脚本
- `.github/workflows/release.yml`：推送版本标签时自动构建并发布 Release

## 设计说明

Keep Bright 使用 AppKit 构建菜单栏应用体验，并通过 `LSUIElement` 让应用不显示在 Dock 和应用切换器中。

菜单栏图标使用 SF Symbols 的杯子图标，颜色跟随系统菜单栏样式自动适配。应用界面尽量保持轻量、安静，符合 macOS 小工具的使用习惯。

## 常见问题

### 为什么应用没有出现在 Dock？

这是预期行为。Keep Bright 是菜单栏工具，启动后只显示在屏幕顶部菜单栏。

### 关闭菜单栏开关后会发生什么？

应用会释放 `PreventUserIdleDisplaySleep` 断言，macOS 会恢复原本的屏幕节能策略。

### 退出应用后屏幕还会保持常亮吗？

不会。应用退出前会自动释放亮屏断言。

### 这个工具会阻止 MacBook 合盖睡眠吗？

不会。它只阻止屏幕因为用户闲置而自动变暗或息屏，不会绕过合盖、低电量或用户主动睡眠等系统行为。

### 是否需要辅助功能、屏幕录制或管理员权限？

不需要。应用只使用 macOS 原生电源管理 API，不需要额外隐私权限或管理员权限。

### 为什么开机自启动没有立即生效？

macOS 可能要求你在“系统设置”里批准新的登录项。如果菜单里显示“需要在系统设置中批准”，请打开系统设置并允许 Keep Bright 作为登录项启动。

### 更新检查会自动安装新版本吗？

不会。当前版本只会检查 GitHub Releases 是否有新版本，并提示你打开下载页面。下载和替换应用仍然由你手动完成。

### 如何关闭自动检查更新？

打开菜单栏中的“偏好设置...”，关闭“每天自动检查更新”。手动点击“检查更新...”仍然可用。

### 电池保护什么时候会触发？

当 Mac 使用电池供电，并且电量低于或等于你在偏好设置里选择的阈值时，Keep Bright 会按你选择的模式处理：仅提醒，或自动关闭保持亮屏。连接电源时不会触发；如果开启了插电后自动恢复，应用会在连接电源后恢复保持亮屏。

### “保持屏幕常亮并防止系统闲置睡眠”是什么？

默认模式只阻止屏幕因闲置而息屏。增强模式会额外阻止系统因为闲置进入睡眠，适合下载、投屏、长时间演示或运行任务时使用。合盖、低电量、用户主动睡眠等系统行为仍然优先。

### 如何调整菜单栏显示？

打开“偏好设置... > 常规”，在“菜单栏显示”中选择只显示图标、剩余时间、防睡眠模式或状态文字。

### 如何关闭某类通知？

打开“偏好设置... > 通知”，分别关闭状态通知、计时通知或电池通知。

### Release 是如何构建的？

推送 `v*` 版本标签后，GitHub Actions 会自动构建 Universal Binary，生成 DMG 和 ZIP，计算 SHA-256，并创建 GitHub Release。

### 为什么通知只显示“收到一条通知”？

这通常是 macOS 的通知预览隐私设置导致的。Keep Bright 会发送标题、副标题和正文；如果系统隐藏预览，你可以在“系统设置 > 通知”中允许显示预览。

## 开发

重新构建：

```sh
./build.sh
```

启动构建产物：

```sh
open build/KeepBright.app
```

查看 Git 状态：

```sh
git status --short --branch
```

## 许可证

本项目使用 MIT License。隐私说明见 [PRIVACY.md](PRIVACY.md)。
