<div align="center">

# Keep Bright

原生 macOS 菜单栏保持亮屏工具。<br>
打开后阻止屏幕因闲置自动变暗或息屏，适合演示、会议、投屏、下载和长时间阅读。

[![Release](https://img.shields.io/github/v/release/swseven-hub/keep-bright?label=release)](https://github.com/swseven-hub/keep-bright/releases/latest)
![macOS](https://img.shields.io/badge/macOS-26.0%2B-111111)
![Swift](https://img.shields.io/badge/Swift-native-orange)
![Universal](https://img.shields.io/badge/Universal-arm64%20%7C%20x86__64-blue)
[![License](https://img.shields.io/badge/license-MIT-green)](LICENSE)

[下载最新版](https://github.com/swseven-hub/keep-bright/releases/latest) ·
[更新日志](CHANGELOG.md) ·
[隐私说明](PRIVACY.md)

</div>

---

## 为什么做它

Keep Bright 的目标很简单：像 One Switch 里的“保持屏幕常亮”一样，只做好一件事，并且保持 macOS 原生、小巧、克制。

它不会出现在 Dock，不打扰当前工作流；启动后常驻菜单栏，需要时点一下即可开启或关闭。

## 下载与安装

| 项目 | 说明 |
| --- | --- |
| 最新版本 | [GitHub Releases](https://github.com/swseven-hub/keep-bright/releases/latest) |
| 推荐安装包 | `KeepBright-1.7.3-macOS-universal.dmg` |
| 备用安装包 | Release 页面同时保留 `.zip` |
| 支持架构 | Apple Silicon 与 Intel Mac |

安装方式：

1. 下载最新版 DMG。
2. 打开 DMG。
3. 将 `KeepBright.app` 拖入 `Applications`。
4. 启动应用，点击菜单栏里的杯子图标开始使用。

> 当前发布包使用本地临时签名，首次运行时 macOS 可能会提示安全确认。

## 功能速览

| 能力 | 说明 |
| --- | --- |
| 保持屏幕常亮 | 阻止屏幕因用户闲置自动变暗或息屏 |
| 防系统闲置睡眠 | 可选增强模式，适合下载、投屏和长时间任务 |
| 自动化规则 | 按指定 App、全屏、外接显示器、连接电源自动开启 |
| 定时保持 | 支持永久、15 分钟、30 分钟、1 小时、2 小时和自定义时长 |
| 菜单栏状态 | 可显示图标、剩余时间、防睡眠模式或状态文字 |
| 全局快捷键 | 默认 `Option-Command-K` 快速开关 |
| 电池保护 | 低电量时提醒或自动关闭，插电后可自动恢复 |
| 通知偏好 | 分别控制状态、计时和电池通知 |
| 更新检查 | 手动检查更新，或每天自动检查一次 GitHub Releases |
| 原生体验 | AppKit、IOKit、UserNotifications、Liquid Glass，无 Electron |

## 自动化规则

自动化默认关闭，避免升级后改变既有使用习惯。你可以在“偏好设置 > 自动化”中按需开启。

| 规则 | 适合场景 |
| --- | --- |
| 指定 App | Keynote、PowerPoint、Zoom、腾讯会议、QuickTime Player 等 |
| 全屏 | 演示、观影、全屏会议、沉浸式阅读 |
| 外接显示器 | 连接显示器、投影仪、会议室屏幕 |
| 连接电源 | 插电办公或长时间任务 |

如果 Keep Bright 是被自动化开启的，当所有触发条件结束后会自动关闭。若你在自动化条件仍满足时手动关闭，它会暂停当前自动化触发，直到条件结束后再恢复监听。

## 偏好设置

偏好设置窗口使用原生 AppKit 与 macOS 26 Liquid Glass，分为这些页面：

| 页面 | 可配置内容 |
| --- | --- |
| 常规 | 启动默认状态、防睡眠模式、菜单栏显示、全局快捷键 |
| 自动化 | 指定 App、全屏、外接显示器、连接电源自动开启 |
| 计时 | 自定义保持时长 |
| 电池 | 低电量保护、保护阈值、插电后恢复 |
| 更新 | 自动检查更新、打开发布页面 |
| 通知 | 状态通知、计时通知、电池通知、系统通知设置入口 |
| 关于 | 项目链接、版本号、隐私说明 |

## 使用方式

启动后，应用只显示在菜单栏。点击杯子图标可以看到：

- 当前保持亮屏状态
- 当前自动化触发状态
- 开启或关闭保持亮屏
- 选择保持时长
- 快速延长 15 或 30 分钟
- 开机自启动
- 偏好设置
- 检查更新
- 关于与退出

默认全局快捷键：

```text
Option-Command-K
```

## 工作原理

Keep Bright 使用 Apple 原生 IOKit Power Management API 创建电源断言：

```swift
kIOPMAssertPreventUserIdleDisplaySleep
```

默认模式会创建 `PreventUserIdleDisplaySleep`，阻止屏幕因用户闲置自动息屏。增强模式会额外使用系统闲置睡眠断言，减少长时间任务被系统睡眠打断的概率。

它不会绕过 macOS 的系统级行为。例如合上 MacBook、用户主动睡眠、低电量保护或系统策略仍然优先。

## 验证是否生效

应用开启后，可以用下面的命令检查系统断言：

```sh
pmset -g assertions | grep KeepBright
```

也可以查看屏幕闲置睡眠断言：

```sh
pmset -g assertions | grep PreventUserIdleDisplaySleep
```

如果看到类似内容，说明保持亮屏已经生效：

```text
PreventUserIdleDisplaySleep    1
pid xxxx(KeepBright): PreventUserIdleDisplaySleep named: "Keep Bright"
```

## 系统要求

| 项目 | 要求 |
| --- | --- |
| macOS | 26.0 或更新版本 |
| 架构 | Apple Silicon 或 Intel |
| 构建工具 | Xcode Command Line Tools 或 Xcode |

本项目最初面向 M1 Mac 和 macOS 26.4.1 开发与验证。

## 本地构建

```sh
chmod +x build.sh
./build.sh
```

构建产物：

```text
build/KeepBright.app
dist/KeepBright-版本号-macOS-universal.dmg
```

构建脚本会完成：

- 生成应用图标
- 分别编译 `arm64` 和 `x86_64`
- 使用 `lipo` 合并 Universal Binary
- 组装标准 `.app`
- 使用本地临时签名完成 codesign
- 生成带拖拽安装引导的 DMG

启动构建产物：

```sh
open build/KeepBright.app
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
│       ├── AutomationManager.swift
│       ├── AwakeDuration.swift
│       ├── BatteryMonitor.swift
│       ├── DisplaySleepAssertion.swift
│       ├── GlobalHotKeyManager.swift
│       ├── LoginItemManager.swift
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
├── .github/
│   └── workflows/
│       └── release.yml
├── build.sh
├── CHANGELOG.md
├── LICENSE
├── PRIVACY.md
└── README.md
```

## 核心文件

| 文件 | 说明 |
| --- | --- |
| `AppDelegate.swift` | 菜单栏图标、菜单、应用生命周期和主要交互 |
| `DisplaySleepAssertion.swift` | IOKit 亮屏断言封装 |
| `AutomationManager.swift` | 自动化规则检测和触发状态管理 |
| `PreferencesWindowController.swift` | 原生偏好设置窗口 |
| `BatteryMonitor.swift` | 电源状态和电池电量读取 |
| `GlobalHotKeyManager.swift` | 全局快捷键管理 |
| `LoginItemManager.swift` | 开机自启动管理 |
| `UpdateChecker.swift` | GitHub Release 更新检查 |
| `Tools/create_dmg.sh` | 生成 DMG 拖拽安装包 |
| `.github/workflows/release.yml` | 标签发布时自动构建 Release |

## 常见问题

<details>
<summary>为什么应用没有出现在 Dock？</summary>

Keep Bright 是菜单栏工具，启动后只显示在屏幕顶部菜单栏。这是预期行为。

</details>

<details>
<summary>关闭菜单栏开关后会发生什么？</summary>

应用会释放 `PreventUserIdleDisplaySleep` 断言，macOS 会恢复原本的屏幕节能策略。

</details>

<details>
<summary>退出应用后屏幕还会保持常亮吗？</summary>

不会。应用退出前会自动释放亮屏断言。

</details>

<details>
<summary>这个工具会阻止 MacBook 合盖睡眠吗？</summary>

不会。它只阻止屏幕因为用户闲置而自动变暗或息屏，不会绕过合盖、低电量或用户主动睡眠等系统行为。

</details>

<details>
<summary>是否需要辅助功能、屏幕录制或管理员权限？</summary>

不需要。应用只使用 macOS 原生电源管理 API，不需要额外隐私权限或管理员权限。

</details>

<details>
<summary>为什么开机自启动没有立即生效？</summary>

macOS 可能要求你在“系统设置”里批准新的登录项。如果菜单里显示“需要在系统设置中批准”，请打开系统设置并允许 Keep Bright 作为登录项启动。

</details>

<details>
<summary>更新检查会自动安装新版本吗？</summary>

不会。当前版本只会检查 GitHub Releases 是否有新版本，并提示你打开下载页面。下载和替换应用仍然由你手动完成。

</details>

<details>
<summary>为什么通知只显示“收到一条通知”？</summary>

这通常是 macOS 的通知预览隐私设置导致的。Keep Bright 会发送标题和正文；如果系统隐藏预览，你可以在“系统设置 > 通知”中允许显示预览。

</details>

## 发布流程

推送 `v*` 版本标签后，GitHub Actions 会自动：

1. 构建 Universal Binary。
2. 生成 DMG 和 ZIP。
3. 计算 SHA-256。
4. 从 `CHANGELOG.md` 抽取对应版本更新说明。
5. 创建 GitHub Release 并上传附件。

## 许可证

本项目使用 MIT License。隐私说明见 [PRIVACY.md](PRIVACY.md)。
