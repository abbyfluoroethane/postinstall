#!/usr/bin/env bash
# Pull the current machine's state back into this repo, then show the diff.
# Review it, then commit what you want to keep.
#
# Updates: dconf values (keys already in config/dconf.ini), rpm package list,
# flatpak list, extension list, and every file under files/ from its live copy.
# Does not touch themes, fonts or icons.
set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO"

echo "dconf values"
python3 -I lib/dconf_refresh.py config/dconf.ini

echo "rpm packages"
{
    echo '# Packages layered with rpm-ostree. One per line.'
    rpm-ostree status --json | python3 -I -c '
import json, sys
d = json.load(sys.stdin)["deployments"][0]
print("\n".join(sorted(d.get("requested-packages", []))))'
} > config/rpm-packages.txt

echo "flatpaks"
{
    echo '# Flatpak apps: <remote> <app-id>. Fedora-preinstalled apps are not listed.'
    flatpak list --app --system --columns=origin,application | awk '$1!="fedora"{print $1" "$2}'
} > config/flatpaks.txt

echo "extensions"
{
    echo '# GNOME extensions installed from extensions.gnome.org. One UUID per line.'
    gsettings get org.gnome.shell enabled-extensions | tr -d "[]',@as" | tr ' ' '\n' | while read -r uuid; do
        [[ -n "$uuid" && -d "$HOME/.local/share/gnome-shell/extensions/$uuid" ]] && echo "$uuid"
    done
} > config/extensions.txt

echo "files"
(cd files/home && find . -type f) | while read -r f; do
    [[ -f "$HOME/${f#./}" ]] && cp "$HOME/${f#./}" "files/home/$f"
done
(cd files/etc && find . -type f) | while read -r f; do
    [[ -f "/etc/${f#./}" ]] && cp "/etc/${f#./}" "files/etc/$f"
done

echo
git -c color.ui=always status --short
git --no-pager diff --stat
