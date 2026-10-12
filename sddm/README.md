# sddm/sequoia — macOS-style login theme

Wallpaper on top, `Monday 12 October` + `10:47` top-centre, avatar + name +
frosted-glass password pill bottom-centre. Matches `hypr/hyprlock.lua`, which
uses the same photo for the lock screen.

| File | Role |
| --- | --- |
| `Main.qml` | The theme. Plain QtQuick + `SddmComponents`; no GraphicalEffects/Effects dependency. |
| `theme.conf` | `background`, `fontFamily` (SF Pro Display), hint, date/time formats. |
| `wallpaper.jpg` | The shared photo (login + lock). Refresh it with `scripts/sync-login-wallpaper.sh` after changing the desktop wallpaper, then re-run `install-sddm.sh` to push it system-wide. |
| `avatar.jpg` | Fallback face. The greeter prefers `/usr/share/sddm/faces/<user>.face.icon`. |
| `metadata.desktop` | `QtVersion=6` so SDDM uses `sddm-greeter-qt6`. |

Auth is stock SDDM: `sddm.login(user, password, sessionIndex)` over PAM, so
user/password behaviour is unchanged — last user + `hyprland-uwsm` session
are preselected, failures clear the field and shake the pill.

## Install

Needs sudo (system theme dir + `/etc/sddm.conf.d`), run in a terminal:

```bash
./scripts/install-sddm.sh --yes   # copy theme, select it, install avatar + fonts
./scripts/install-sddm.sh --check # verify without changing anything
```

`./install.sh` (no sudo) links `~/.config/sddm` for live editing and
regenerates `hyprlock.conf` from `hypr/hyprlock.lua` on every Hyprland
reload. Preview without rebooting:

```bash
sddm-greeter-qt6 --test-mode --theme ~/.config/sddm/sequoia
```

Then reboot to see the real greeter.
