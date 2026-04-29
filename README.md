# 保持亮屏

一个原生 macOS 菜单栏应用。启动后默认开启，使用 IOKit 的 `PreventUserIdleDisplaySleep` power assertion 阻止屏幕因闲置而自动变暗或息屏。

## 构建

```sh
chmod +x build.sh
./build.sh
```

构建产物会生成在：

```text
build/KeepBright.app
```

## 运行

双击 `build/KeepBright.app`，或运行：

```sh
open build/KeepBright.app
```

应用不会显示在 Dock 中，只会出现在菜单栏。点击菜单栏里的杯子图标可以开启、关闭或退出。
