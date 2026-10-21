# Vendored fonts

Binary font files live here so a fresh clone builds a complete desktop with no
network access. `scripts/install-fonts.sh` copies the `.ttf` files into
`~/.local/share/fonts` and rebuilds the font cache.

SF Pro Display is deliberately absent: Apple's font license forbids
redistribution, and this repo is public. The installer prints the one manual
step and `install.sh` keeps the check red until it is done.

Apple Color Emoji is not vendored either. `scripts/setup.sh` installs the
latest Fedora RPM from `samuelngs/apple-emoji-ttf` on first provision
(`./dots packages`); the RPM is system-wide and also ships the fontconfig
snippet that makes it the preferred emoji face.

| Directory | Font | Upstream | License |
| --- | --- | --- | --- |
| `JetBrainsMonoNLNerdFontMono/` | JetBrains Mono Nerd Font Mono (NL) — Regular, Bold, Italic, BoldItalic | nerd-fonts `v3.5.1`, `JetBrainsMono.zip` | OFL-1.1, see `OFL.txt` |
| `MaterialSymbolsRounded/` | Material Symbols Rounded, variable font | `google/material-design-icons`, `variablefont/` | Apache-2.0, see `LICENSE.txt` |

To update: pull the current upstream files, replace the `.ttf` files in place,
refresh the license texts, and record the new version and date here.
