# wechat-linux-hotkey design

Date: 2026-09-15

## Goal

Give WeChat for Linux (the official `wechat` deb, 4.x) the same global hotkey
Windows WeChat has: press Ctrl+Alt+W to bring the main window to the front, press
it again while it is focused to put it away. Ship it as a small script plus a
one-line installer on GitHub (`SailorMoonQ/wechat-linux-hotkey`).

## Scope

- WeChat only. Process name, window title and tray menu labels are fixed.
- GNOME on X11 is the fully supported target. Wayland gets best-effort "show"
  without focus control. KDE is out of scope for now; the installer refuses
  desktops it does not know rather than half-installing.
- Install via `curl | sh` or from a clone; both run the same `install.sh`.

## Why not a GNOME extension

Everything the tool does is DBus (tray menu) plus one gsettings key (the
shortcut). Neither needs GNOME internals. An extension would only add Wayland
focus control, at the cost of per-GNOME-version maintenance and review on
extensions.gnome.org.

## How showing works (the part that is not obvious)

Closing WeChat to the tray unmaps its main window. Force-mapping it with
`xdotool windowmap` produces a black, unpainted window because WeChat still
believes it is hidden. The only way that makes WeChat paint the window again is
its own tray icon, which it registers as a `org.kde.StatusNotifierItem-<pid>-N`
DBus name with a `com.canonical.dbusmenu` menu holding a "显示" (Show) entry.
Sending `Event(<id>, "clicked")` to that entry is exactly a tray click.

GNOME's focus-stealing prevention may then only flag the window as
demanding attention, so on X11 the script follows up with
`xdotool windowactivate` once the window is mapped.

## Components

### `wechat-toggle` (bash, installed to `~/.local/bin`)

1. Find the WeChat main process with `pgrep -o -x wechat`. If absent, exec
   `wechat` (looked up on PATH) and exit.
2. On X11: locate the main window (`xdotool search --pid <pid> --name '^微信$'`,
   English UI title "WeChat" also accepted). If it is the active window,
   minimize it and exit.
3. Find the StatusNotifierItem bus name for that pid via
   `org.freedesktop.DBus.ListNames`, read the menu layout with `GetLayout`, find
   the item whose label is "显示" or "Show", send `Event(id, "clicked")` with
   `--print-reply` (without it dbus-send can exit before the message is flushed).
4. On X11: poll up to 3 s for the window to become viewable, then
   `windowactivate --sync`. On Wayland: stop after step 3.

Dependencies: `dbus-send`, `pgrep`; on X11 additionally `xdotool`, `xwininfo`.

### `install.sh`

- Idempotent, POSIX sh compatible enough for `curl | sh` (it re-execs under
  bash if needed).
- Options: `--key '<Control><Alt>w'` (default), `--uninstall`, `--help`.
- Checks: GNOME session (`XDG_CURRENT_DESKTOP` contains GNOME), required
  commands present; prints the `apt install` line for what is missing and exits
  non-zero.
- Source of `wechat-toggle`: the file next to `install.sh` when run from a
  clone; otherwise downloaded from
  `https://raw.githubusercontent.com/SailorMoonQ/wechat-linux-hotkey/<ref>/wechat-toggle`
  where `<ref>` defaults to `main` and can be overridden with `WLH_REF`.
- Installs to `~/.local/bin/wechat-toggle` (mode 755) and registers a GNOME
  custom keybinding at
  `/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/wechat-toggle/`
  with name "WeChat toggle". Re-running updates the script and the key.
- `--uninstall` removes the keybinding path from the list, resets its keys and
  deletes the script.

### Repository layout

```
wechat-toggle
install.sh
README.md          (zh-CN first, English below)
LICENSE            (MIT)
.github/workflows/ci.yml   (shellcheck + bash -n on both scripts)
docs/superpowers/specs/    (this document)
```

## Testing

CI can only lint (no WeChat on runners). Manual end-to-end on this machine:
install from a clone and via `curl | sh`, then run the three transitions
(focused → minimized, minimized → shown, closed-to-tray → shown), then
`--uninstall` and confirm the gsettings path and the file are gone.
