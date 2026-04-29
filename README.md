# Keep Bright（保持亮屏）

一个原生 macOS 菜单栏小工具。启动后默认开启保持亮屏，防止 Mac 屏幕因为长时间闲置而自动变暗或息屏。

它的目标很简单：像 One Switch 里的“保持屏幕常亮”一样，只做一件事，并且尽量符合 macOS 的原生使用习惯。

## 下载

前往 GitHub Releases 下载最新版本：

[下载 Keep Bright 最新版](https://github.com/swseven-hub/keep-bright/releases/latest)

当前发布包为 macOS Apple Silicon 版本，文件名类似：

```text
KeepBright-1.1.0-macOS-arm64.zip
```

下载后解压，将 `KeepBright.app` 拖到“应用程序”文件夹，双击运行即可。

## 功能

- 启动后自动开启保持亮屏
- 支持永久、15 分钟、30 分钟、1 小时、2 小时定时模式
- 定时模式下在菜单栏显示剩余时间
- 支持开机自启动
- 开启、关闭和定时结束时发送系统通知
- 菜单栏常驻，不占用 Dock
- 点击菜单栏图标可以开启、关闭或退出
- 退出应用时自动释放系统亮屏请求
- 支持 macOS 深色、浅色外观
- 不请求隐私权限，不访问网络，不收集任何数据

## 系统要求

- macOS 26.0 或更新版本
- Apple Silicon Mac，当前构建目标为 `arm64`
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
```

构建脚本会完成这些步骤：

- 生成应用图标
- 使用 `swiftc` 编译原生 arm64 可执行文件
- 组装标准 macOS `.app` 应用包
- 使用本地临时签名完成 codesign

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
- 关于信息
- 退出应用

定时模式开启后，菜单栏会显示倒计时。倒计时结束时，应用会自动关闭保持亮屏，并通过系统通知提醒你。

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
│       ├── DisplaySleepAssertion.swift
│       └── main.swift
├── Tools/
│   └── make_icon.swift
├── build.sh
└── README.md
```

核心文件说明：

- `Sources/KeepBright/main.swift`：应用入口
- `Sources/KeepBright/AwakeDuration.swift`：保持时长选项和持久化
- `Sources/KeepBright/AppDelegate.swift`：菜单栏图标、菜单和交互逻辑
- `Sources/KeepBright/DisplaySleepAssertion.swift`：IOKit 亮屏断言封装
- `Sources/KeepBright/LoginItemManager.swift`：开机自启动管理
- `Sources/KeepBright/NotificationManager.swift`：系统通知管理
- `Resources/Info.plist`：应用元信息，包含菜单栏应用配置
- `Tools/make_icon.swift`：生成 `.icns` 图标资源
- `build.sh`：无 Xcode 项目的轻量打包脚本

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

当前项目尚未添加许可证文件。公开发布代码前，建议根据你的使用方式补充合适的开源许可证。
