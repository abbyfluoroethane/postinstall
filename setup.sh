#!/usr/bin/env bash
# Post-install setup for Fedora Silverblue.
#
# Usage: ./setup.sh            run every step
#        ./setup.sh <step>...  run only the named steps
#        ./setup.sh --list     show the steps
#
# Every step is safe to run again. Run as your normal user from a GNOME
# session; steps that change the system ask for sudo.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GTK_THEME="Catppuccin-Pink-Dark-MB"
ICON_REPO="https://github.com/vinceliuice/Colloid-icon-theme.git"
ICON_ARGS=(-s catppuccin -t pink)   # gives Colloid-Pink-Catppuccin

STEPS=(repos packages etc flatpaks fonts themes icons extensions dotfiles dconf)

log()  { printf '\n\033[1;35m==> %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m  ! %s\033[0m\n' "$*" >&2; }

# Print the non-comment, non-blank lines of a list file.
entries() { grep -vE '^\s*(#|$)' "$1" || true; }

step_repos() {
    log "Adding package repos"
    for f in "$REPO"/config/repos/*.repo; do
        sudo install -m644 "$f" "/etc/yum.repos.d/$(basename "$f")"
        echo "  $(basename "$f")"
    done
}

step_packages() {
    log "Layering rpm packages"
    mapfile -t pkgs < <(entries "$REPO/config/rpm-packages.txt")
    [[ ${#pkgs[@]} -eq 0 ]] && return
    sudo rpm-ostree install --idempotent --allow-inactive "${pkgs[@]}"
}

step_etc() {
    log "Installing files into /etc"
    (cd "$REPO/files/etc" && find . -type f) | while read -r f; do
        sudo install -D -m644 "$REPO/files/etc/$f" "/etc/${f#./}"
        echo "  /etc/${f#./}"
    done
}

step_flatpaks() {
    log "Installing flatpaks"
    sudo flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
    sudo flatpak remote-modify --enable flathub
    entries "$REPO/config/flatpaks.txt" | while read -r remote app; do
        flatpak install --system --noninteractive --or-update "$remote" "$app" </dev/null
    done
    # Let flatpak apps see the GTK theme and icons.
    flatpak override --user \
        --filesystem=xdg-config/gtk-4.0:ro \
        --filesystem="$HOME/.themes:ro" \
        --filesystem="$HOME/.icons:ro" \
        --filesystem=xdg-data/icons:ro
}

step_fonts() {
    log "Installing fonts"
    mkdir -p "$HOME/.local/share/fonts"
    cp -r "$REPO"/assets/fonts/* "$HOME/.local/share/fonts/"
    fc-cache -f "$HOME/.local/share/fonts" >/dev/null
}

step_themes() {
    log "Installing GTK / shell theme"
    mkdir -p "$HOME/.themes" "$HOME/.config/gtk-4.0"
    for t in "$REPO"/assets/themes/*.tar.gz; do
        tar -xzf "$t" -C "$HOME/.themes"
    done
    # libadwaita (GTK4) apps ignore gtk-theme, so link the theme's CSS in.
    for f in assets gtk.css gtk-dark.css; do
        ln -sfn "$HOME/.themes/$GTK_THEME/gtk-4.0/$f" "$HOME/.config/gtk-4.0/$f"
    done
}

step_icons() {
    log "Building icon theme"
    local tmp
    tmp="$(mktemp -d)"
    git clone --depth 1 --quiet "$ICON_REPO" "$tmp/icons"
    (cd "$tmp/icons" && ./install.sh "${ICON_ARGS[@]}" >/dev/null)
    rm -rf "$tmp"
}

step_extensions() {
    log "Installing GNOME extensions"
    local shell_ver tmp info url
    shell_ver="$(gnome-shell --version | grep -oE '[0-9]+' | head -1)"
    tmp="$(mktemp -d)"
    entries "$REPO/config/extensions.txt" | while read -r uuid; do
        info="$(curl -fsSL "https://extensions.gnome.org/extension-info/?uuid=$uuid&shell_version=$shell_ver")" || {
            warn "$uuid: no version for GNOME $shell_ver"; continue; }
        url="$(python3 -I -c 'import json,sys; print(json.load(sys.stdin)["download_url"])' <<<"$info")"
        curl -fsSL -o "$tmp/ext.zip" "https://extensions.gnome.org$url"
        gnome-extensions install --force "$tmp/ext.zip"
        echo "  $uuid"
    done
    rm -rf "$tmp"
    # Enabling happens through enabled-extensions in config/dconf.ini.
    # GNOME on Wayland loads new extensions at the next login.
}

step_dotfiles() {
    log "Copying dotfiles into $HOME"
    (cd "$REPO/files/home" && find . -type f) | while read -r f; do
        install -D -m644 "$REPO/files/home/$f" "$HOME/${f#./}"
        echo "  ~/${f#./}"
    done
}

step_dconf() {
    log "Applying GNOME settings"
    dconf load / < "$REPO/config/dconf.ini"
}

main() {
    if [[ "${1:-}" == "--list" ]]; then
        printf '%s\n' "${STEPS[@]}"; exit 0
    fi
    [[ $EUID -eq 0 ]] && { echo "Run as your normal user, not root." >&2; exit 1; }
    command -v rpm-ostree >/dev/null || { echo "This is for Fedora Atomic (rpm-ostree)." >&2; exit 1; }

    local run=("$@")
    [[ ${#run[@]} -eq 0 ]] && run=("${STEPS[@]}")
    for s in "${run[@]}"; do
        declare -F "step_$s" >/dev/null || { echo "Unknown step: $s (see --list)" >&2; exit 1; }
    done

    # Ask for the sudo password once, up front.
    sudo -v
    for s in "${run[@]}"; do "step_$s"; done

    log "Done"
    if rpm-ostree status --json | python3 -I -c 'import json,sys; d=json.load(sys.stdin)["deployments"]; sys.exit(0 if not d[0]["booted"] else 1)'; then
        echo "  A new deployment is staged. Reboot to finish: systemctl reboot"
    else
        echo "  Log out and back in to load extensions and themes."
    fi
}

main "$@"
