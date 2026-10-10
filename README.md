# fedora-setup

My post-install setup for Fedora Silverblue (GNOME).

## New install

1. Finish GNOME initial setup and log in.
2. Get this repo onto the machine (git clone, or copy it from a USB stick).
3. Run:

   ```
   cd fedora-setup
   ./setup.sh
   ```

4. Reboot (`systemctl reboot`). Layered rpm packages and the extensions load after the reboot.

To run some steps only: `./setup.sh flatpaks dconf`. To see the steps: `./setup.sh --list`.

| Step         | What it does                                                        | Source                         |
|--------------|---------------------------------------------------------------------|--------------------------------|
| `repos`      | Copies COPR repo files to `/etc/yum.repos.d`                        | `config/repos/`                |
| `packages`   | `rpm-ostree install` of layered packages                            | `config/rpm-packages.txt`      |
| `etc`        | Copies system files into `/etc` (touchpad scroll plugin)            | `files/etc/`                   |
| `flatpaks`   | Installs flatpak apps, lets flatpaks use the theme                  | `config/flatpaks.txt`          |
| `fonts`      | Copies fonts to `~/.local/share/fonts`                              | `assets/fonts/`                |
| `themes`     | Unpacks the GTK/shell theme to `~/.themes`, links GTK4 CSS          | `assets/themes/`               |
| `icons`      | Builds Colloid icons (pink, Catppuccin) from upstream               | `setup.sh` (`ICON_ARGS`)       |
| `extensions` | Downloads extensions for the running GNOME version from e.g.o       | `config/extensions.txt`        |
| `dotfiles`   | Copies config files into `$HOME`                                    | `files/home/`                  |
| `dconf`      | Applies GNOME and extension settings                                | `config/dconf.ini`             |

## Keeping it up to date

After you change something on your machine:

```
./capture.sh       # pulls current state into the repo, shows what changed
git diff           # review
git commit -am "..."
```

`capture.sh` only refreshes things the repo already tracks:

- **Settings:** only keys already in `config/dconf.ini`. To track a new setting, run `dconf watch /`, change the setting in GNOME, and paste the key into the file.
- **Files:** only files already under `files/`. To track a new dotfile, copy it into `files/home/` (same path as under `~`) once.
- **Lists:** layered packages, flatpaks and extensions are rewritten in full.
- **Not captured:** themes, fonts and icons. Replace the files in `assets/` by hand.

## Notes

- `gnome-rounded-blur` (for Blur my Shell's rounded corners) comes from the
  ublue-os COPR. Its repo file only allows that one package, so the COPR
  cannot replace base packages. It must match the installed mutter version;
  updates come through `rpm-ostree upgrade`.
- The touchpad plugin (`files/etc/libinput/plugins/10-touchpad-scroll-speed.lua`)
  slows two-finger scrolling. Change `FACTOR` to tune it, then run
  `./setup.sh etc` and log out and back in.

## Licenses

The scripts and config in this repo are MIT (see `LICENSE`). Bundled
third-party files keep their own licenses:

- `assets/fonts/selawik/`: Selawik by Microsoft, SIL Open Font License 1.1 (`LICENSE.txt` in that folder).
- `assets/themes/`: Catppuccin-GTK-Theme by Fausto-Korpsvart, GPL-3.0 (`LICENSE` and `README.md` in that folder).
