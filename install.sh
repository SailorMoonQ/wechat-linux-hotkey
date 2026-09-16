#!/bin/sh
# install.sh - install wechat-toggle and bind it to a GNOME global shortcut.
#
#   curl -fsSL https://raw.githubusercontent.com/SailorMoonQ/wechat-linux-hotkey/main/install.sh | sh
#   ./install.sh [--key '<Control><Alt>w'] [--uninstall]
#
# Idempotent: re-running updates the script and the key binding.
# Environment: WLH_REF selects the git ref to download from (default: main).

set -eu

REPO_RAW="https://raw.githubusercontent.com/SailorMoonQ/wechat-linux-hotkey"
REF="${WLH_REF:-main}"
KEY='<Control><Alt>w'
BIN_DIR="${XDG_BIN_HOME:-$HOME/.local/bin}"
TARGET="$BIN_DIR/wechat-toggle"
SCHEMA="org.gnome.settings-daemon.plugins.media-keys"
KB_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/wechat-toggle/"
KB_SCHEMA="$SCHEMA.custom-keybinding:$KB_PATH"

usage() {
    cat <<USAGE
Usage: install.sh [--key BINDING] [--uninstall]

  --key BINDING   GTK accelerator to bind (default: '$KEY')
  --uninstall     remove the shortcut and the script
USAGE
}

die() { echo "install.sh: $*" >&2; exit 1; }

mode=install
while [ $# -gt 0 ]; do
    case "$1" in
        --key) [ $# -ge 2 ] || die "--key needs a value"; KEY="$2"; shift 2 ;;
        --key=*) KEY="${1#--key=}"; shift ;;
        --uninstall) mode=uninstall; shift ;;
        -h|--help) usage; exit 0 ;;
        *) usage >&2; die "unknown option: $1" ;;
    esac
done

case "${XDG_CURRENT_DESKTOP:-}" in
    *GNOME*) ;;
    *) die "only GNOME is supported (XDG_CURRENT_DESKTOP='${XDG_CURRENT_DESKTOP:-}')" ;;
esac

missing=""
for cmd in gsettings dbus-send pgrep xdotool xwininfo; do
    command -v "$cmd" >/dev/null 2>&1 || missing="$missing $cmd"
done
if [ -n "$missing" ]; then
    echo "install.sh: missing commands:$missing" >&2
    echo "On Debian/Ubuntu: sudo apt install xdotool x11-utils dbus-x11" >&2
    exit 1
fi

# gsettings list manipulation. Lists look like "@as []" or "['/a/', '/b/']".
kb_list() { gsettings get "$SCHEMA" custom-keybindings; }

kb_list_add() {
    cur=$(kb_list)
    case "$cur" in
        *"'$KB_PATH'"*) return 0 ;;
        "@as []") new="['$KB_PATH']" ;;
        *) new="${cur%]}, '$KB_PATH']" ;;
    esac
    gsettings set "$SCHEMA" custom-keybindings "$new"
}

kb_list_remove() {
    cur=$(kb_list)
    case "$cur" in
        *"'$KB_PATH'"*) ;;
        *) return 0 ;;
    esac
    new=$(printf '%s' "$cur" \
          | sed -e "s|, '$KB_PATH'||" -e "s|'$KB_PATH', ||" -e "s|'$KB_PATH'||")
    [ "$new" = "[]" ] && new="@as []"
    gsettings set "$SCHEMA" custom-keybindings "$new"
}

if [ "$mode" = uninstall ]; then
    kb_list_remove
    gsettings reset-recursively "$KB_SCHEMA" 2>/dev/null || true
    rm -f "$TARGET"
    echo "Removed $TARGET and the GNOME shortcut."
    exit 0
fi

mkdir -p "$BIN_DIR"
# Running from a clone: use the sibling file. Piped from curl: download.
src_dir=$(dirname "$0" 2>/dev/null || true)
if [ -n "$src_dir" ] && [ -f "$src_dir/wechat-toggle" ]; then
    cp "$src_dir/wechat-toggle" "$TARGET"
else
    command -v curl >/dev/null 2>&1 || die "curl is required to download wechat-toggle"
    curl -fsSL "$REPO_RAW/$REF/wechat-toggle" -o "$TARGET"
fi
chmod 755 "$TARGET"

kb_list_add
gsettings set "$KB_SCHEMA" name 'WeChat toggle'
gsettings set "$KB_SCHEMA" command "$TARGET"
gsettings set "$KB_SCHEMA" binding "$KEY"

echo "Installed $TARGET and bound it to $KEY."
case "${XDG_SESSION_TYPE:-}" in
    wayland) echo "Note: on Wayland the hotkey can only show WeChat, not minimize or focus it." ;;
esac
