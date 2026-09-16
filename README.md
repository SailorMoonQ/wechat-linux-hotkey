# wechat-linux-hotkey

给 Linux 版微信加上和 Windows 版一样的全局快捷键：按 `Ctrl+Alt+W` 唤起微信主窗口，
窗口已聚焦时再按一次就把它收起来。

[English](#english)

## 安装

```sh
curl -fsSL https://raw.githubusercontent.com/SailorMoonQ/wechat-linux-hotkey/main/install.sh | sh
```

或者 clone 后运行：

```sh
git clone https://github.com/SailorMoonQ/wechat-linux-hotkey.git
cd wechat-linux-hotkey
./install.sh                      # 默认绑定 Ctrl+Alt+W
./install.sh --key '<Super>w'     # 换一个键位
./install.sh --uninstall          # 卸载
```

安装脚本会把 `wechat-toggle` 放到 `~/.local/bin`，并在 GNOME 里注册一条名为
"WeChat toggle" 的自定义快捷键。重复运行会更新脚本和键位。之后也可以在
「设置 → 键盘 → 自定义快捷键」里直接改。

依赖：`xdotool`、`x11-utils`、`dbus-x11`（Ubuntu/Debian 上 `sudo apt install` 这三个即可）。

## 支持范围

| 环境 | 状态 |
|---|---|
| GNOME + X11 | 完整支持：唤起、聚焦、再按收起 |
| GNOME + Wayland | 只能唤起。Wayland 不允许脚本聚焦或最小化窗口，能否弹到前台由 GNOME 决定 |
| KDE 及其他桌面 | 暂不支持，安装脚本会拒绝 |

在微信 4.1.x（官方 deb 包）+ Ubuntu 22.04 GNOME 42 上验证。

## 原理

Linux 版微信没有自带的全局热键，所以由桌面环境的快捷键去调用 `wechat-toggle`：

1. 微信没在运行就直接启动它。
2. 主窗口已经聚焦就最小化。
3. 其他情况通过 DBus 点一下微信托盘图标菜单里的「显示」，然后再显式聚焦一次。

第 3 步必须走托盘菜单。微信关到托盘时会把主窗口 unmap，如果用 `xdotool windowmap`
硬把窗口拉出来，得到的是一个黑色未绘制的空窗口，因为微信自己仍认为它处于隐藏状态。
托盘图标是一个 `org.kde.StatusNotifierItem-<pid>-1` DBus 对象，其 `com.canonical.dbusmenu`
菜单里有「显示」项，对它发一个 `clicked` 事件等价于用鼠标点托盘，微信会自己把窗口画出来。

GNOME 的焦点防抢有时只会把窗口标记为「需要注意」而不弹出，所以在 X11 上脚本会在窗口
出现后再用 `xdotool windowactivate` 聚焦一次。

## English

Gives WeChat for Linux the global hotkey Windows WeChat has: press `Ctrl+Alt+W`
to bring the main window to the front, press it again while focused to put it away.

```sh
curl -fsSL https://raw.githubusercontent.com/SailorMoonQ/wechat-linux-hotkey/main/install.sh | sh
```

`install.sh` copies `wechat-toggle` to `~/.local/bin` and registers a GNOME custom
shortcut named "WeChat toggle". Options: `--key '<Super>w'` to change the binding,
`--uninstall` to remove everything. Requires `xdotool`, `x11-utils` and `dbus-x11`.

Fully supported on GNOME + X11. On GNOME + Wayland the hotkey can only ask WeChat
to show its window; focus and minimize are not available to scripts there. Other
desktops are not supported yet.

Showing goes through WeChat's own tray icon (a StatusNotifierItem on the session
bus) by clicking its "显示"/"Show" dbusmenu entry over DBus. Force-mapping the
window with xdotool does not work: WeChat unmaps the window when closed to the
tray and leaves it unpainted (black) if something else maps it.

## License

MIT
