#!/usr/bin/env bash
# Everforest theme bootstrap — installs the bits that can't live in chezmoi as
# tracked files (the Colloid icon theme is thousands of generated files; adw-gtk3
# is a packaged theme). The Everforest *colours* and squared geometry come from
# the chezmoi-tracked gtk-3.0/gtk.css + gtk-4.0/gtk.css layered on top of the
# neutral adw-gtk3 base — so there is no separate Everforest GTK theme to build.
# The matching config files (gtk settings.ini, xsettingsd.conf,
# xdg-desktop-portal/hyprland-portals.conf, EverforestHard.colors) ARE chezmoi-
# managed and applied by `chezmoi apply`.
#
# Run once on a fresh machine after `chezmoi apply`:  ~/.local/bin/setup-theme.sh
# Requires: git, sassc (for Colloid). gvfs (for swaync album art over https).
set -euo pipefail

ICONS="$HOME/.local/share/icons"
THEMES="$HOME/.themes"
ICON_THEME="Colloid-Green-Everforest-Dark"
GTK_THEME="adw-gtk3-dark"   # neutral base; Everforest tint lives in the tracked gtk.css
KDE_SCHEME="EverforestHard"

tmp="$(mktemp -d)"; trap 'rm -rf "$tmp"' EXIT
mkdir -p "$ICONS" "$THEMES"

echo ">> Colloid icon theme (Everforest scheme, green folders)"
git clone --depth 1 https://github.com/vinceliuice/Colloid-icon-theme "$tmp/colloid"
"$tmp/colloid/install.sh" -d "$ICONS" -s everforest -t green

echo ">> adw-gtk3 base theme (libadwaita look for GTK3; gtk.css adds the Everforest colours)"
if ! ls -d /usr/share/themes/adw-gtk3* "$THEMES"/adw-gtk3* \
        "$HOME/.local/share/themes"/adw-gtk3* >/dev/null 2>&1; then
  sudo pacman -S --needed --noconfirm adw-gtk3
fi

echo ">> audio-card form-factor symlinks (so GTK4 pavucontrol shows device icons)"
T="$ICONS/$ICON_THEME"
find "$T" -name "audio-card.svg" | while read -r f; do
  d="$(dirname "$f")"
  for n in audio-card-analog audio-card-analog-pci audio-card-analog-usb \
           audio-card-pci audio-card-usb audio-card-analog-stereo audio-speakers-analog-stereo; do
    ln -sf "audio-card.svg" "$d/$n.svg"
  done
done
rm -f "$T/icon-theme.cache"   # let GTK scan live so the symlinks resolve

echo ">> apply KDE color scheme + icon theme (kdeglobals is intentionally NOT tracked)"
if command -v plasma-apply-colorscheme >/dev/null; then
  plasma-apply-colorscheme "$KDE_SCHEME" || true
fi
if command -v kwriteconfig6 >/dev/null; then
  kwriteconfig6 --file kdeglobals --group Icons --key Theme "$ICON_THEME"
  kwriteconfig6 --file kdeglobals --group General --key accentColorFromWallpaper false
fi
if command -v gsettings >/dev/null; then
  gsettings set org.gnome.desktop.interface icon-theme "$ICON_THEME" || true
  gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME" || true
fi

echo ">> done. Restart waybar/swaync (or re-login) to fully apply."
echo "   GTK4 icon theming relies on ~/.config/xdg-desktop-portal/hyprland-portals.conf"
echo "   routing Settings to gtk first (chezmoi-managed)."
