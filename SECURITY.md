# Security

## The trust model, stated plainly

This repo is installed with a one-liner that fetches and runs code:

```bash
curl -fsSL https://raw.githubusercontent.com/pulkit777exe/dots/main/bootstrap.sh | bash
```

That is the normal dotfiles trust model, and it is not nothing. Read this
before running it on a machine you care about.

**Whoever controls the `pulkit777exe/dots` repository can run arbitrary code
as you.** So can anyone who takes over that account, and so can anyone who
sneaks a commit onto the default branch. The default branch is mutable, so
the code you get today is not necessarily the code you get tomorrow.

If that trade-off is not acceptable, do not use the one-liner. Clone once,
pin a commit, and read what you run:

```bash
git clone https://github.com/pulkit777exe/dots.git ~/dots
git -C ~/dots checkout <commit-or-tag>     # pin it
less ~/dots/install.sh                     # read it
~/dots/install.sh --dry-run                # preview
~/dots/install.sh
```

That removes the mutable-branch problem entirely. Everything in this repo is
plain config — there is no build step and no package to compile. Note the
scope: that statement covers `install.sh` and `bootstrap.sh`, which only
write inside `$HOME` and never touch the network. `scripts/setup.sh` and
`install-software` are provision-time fetchers, not pure config — they
download and execute upstream code (grimblast script, starship installer,
oh-my-zsh installer, brave installer; one pipe runs under `sudo`). Each
fetch site carries a comment stating this; read those before running them
on a machine you care about. `scripts/install-sddm.sh` is the other
exception: it `sudo`-copies the login theme to
`/usr/share/sddm/themes/sequoia`, writes
`/etc/sddm.conf.d/10-sequoia.conf`, installs the user avatar under
`/usr/share/sddm/faces/`, and publishes the greeter fonts to
`/usr/local/share/fonts/dots`. It touches no network and asks first
unless passed `--yes`.

## What the installer will and will not do

`install.sh`:

- **Never uses `sudo`.** It only writes inside `$HOME`. `bootstrap.sh` refuses
  to run as root at all.
- **Never deletes.** An existing `~/.config/<unit>` is *renamed* to
  `<unit>.pre-install.<timestamp>`.
- **Prompts before touching anything it did not create.** Moving an existing
  real directory aside asks first, and refuses outright when there is no
  terminal to ask on — so a non-interactive run (CI, cron, a piped bootstrap)
  can never silently relocate your live config. `--yes` overrides.
- **Refuses empty units.** A unit directory that exists but is empty is an
  error, not a pass, because installing it produces a hollow config that fails
  quietly later.
- **Writes only symlinks** into `~/.config`, pointing into the clone. Delete
  or move the clone and those symlinks dangle; re-run `install.sh` to repair.

`bootstrap.sh` additionally:

- Refuses to run as root.
- Verifies the clone's `origin` matches the expected URL, so a substituted,
  mirrored, or mistyped remote is caught rather than silently used.
- Refuses to run if your checkout has uncommitted local changes, so you never
  execute a tree that differs from what the repo says.

## No network access at runtime

Once installed, nothing in this repo reaches the network. The Python helpers
(`list-themes.py`, `publish-colors.py`, `inotify-watch.py`)
read and write local files and shell out to local tools. There is no `wget`/`urllib` anywhere, and no `curl` in the runtime
path, so the installed desktop cannot phone home, and there is no update
check that runs on its own.

Provisioning is the exception: `scripts/setup.sh` and `install-software`
fetch upstream installers at setup time (see the trust-model note above).
That happens once, interactively, never on its own afterwards.

## No secrets in the repository

The repo contains no API keys, tokens, SSH keys, certificates, or Wi-Fi
credentials. `.gitignore` covers `.env*`, `*.pem`, `*.key`, `credentials*`,
`secrets*`, `__pycache__/`, and machine-local artifacts.

Two things were removed during the audit because they were personal rather
than secret, but did not belong in a public repo:

- `vlc/vlc-qt-interface.conf` carried a machine-specific file-dialog path and
  a recent-media history containing film titles.
- `hypr/` and the Quickshell tree had a hardcoded `/home/pulkit/...` path,
  which is both a privacy leak and a portability bug.

Shell secrets (`zsh/`) follow the same rule: `zsh/.zshrc` is tracked and must
stay free of keys or tokens; anything secret goes in untracked
`~/.zshrc.local` (see `zsh/.zshrc.local.example`).

Wallpapers are **not** committed — they are large binaries, and the shipped
`colors/index.json.example` deliberately contains no absolute paths, so
`list-themes.py` discovers wallpaper directories under `$HOME` at runtime.
The two exceptions are the login theme's bundled assets
(`sddm/sequoia/wallpaper.jpg` + `avatar.jpg`): SDDM runs as its own user
and cannot read a 700 `$HOME`, so the theme ships its own photo and
`scripts/sync-login-wallpaper.sh` refreshes it from the live desktop
wallpaper.
The live `colors/index.json` (gitignored) does contain `$HOME` paths by
design.

## Privilege boundaries

Two components sit on a trust boundary and are worth understanding:

- **`quickshell/scripts/polkit-agent.py` + `services/Auth.qml`** are the
  polkit authentication agent, split in two: the daemon speaks the polkit
  protocol (register, sessions, retries) and the island dialog collects the
  password. They meet over one IPC call plus a per-request response file in
  `$XDG_RUNTIME_DIR/dots-auth` (tmpfs, 0600, unlinked on first read — the
  password is never logged and never touches disk). The agent does not grant
  anything itself; polkitd and the application's `.policy` files decide.
  `hyprpolkitagent` stays installed as a manual fallback but never
  autostarts — two agents race for the same session.
- **Status (2026-10-15): the agent cannot register yet.** polkitd rejects
  registration because no desktop process belongs to a logind session
  (`uwsm` runs the compositor as user units outside `session-2.scope`;
  verified: the reference agent dies the same way). Until session tracking
  is repaired, no polkit prompt of any kind can appear — this is systemic,
  not a dialog bug. The daemon fails loud (exit 2 + log) and self-heals
  the day sessions work, with zero code changes.
- **`/usr/local/bin/dots-set-charge-limit` + `/etc/sudoers.d/dots-charge-limit`**
  are the pragmatic privilege path while polkit is unreachable: a
  root-owned, immutable helper that only writes one sysfs node after
  validating 40-100, plus a NOPASSWD entry scoped to that path and range.
  No prompt appears because the slider gesture already is consent; the
  blast radius is one validated integer into one file. Revisit (agent
  prompts) once sessions are repaired. The settings gesture itself is
  the consent — no prompt appears by design.
- **`hypr/hyprlock.lua`** is the lock screen. It gates access to the session
  and talks to `pam` for authentication. Keep it present and do not weaken
  its `auth` path; treat any change to it as security-relevant.

## Untrusted input

The shell renders data it does not control: network names, media metadata,
notification bodies, and device labels. All of it is attacker-influenced —
a hostile Wi-Fi SSID is fully attacker-chosen.

- **Process invocation uses argv lists, never a shell string.** `Wifi.qml`
  passes `nmcli` arguments as an array, so an SSID like `foo; rm -rf ~` stays
  a single argument and is never interpreted by a shell. Same for the Python
  helpers, which call `subprocess.run` with a list and never `shell=True`.
- **QML `Text` does not evaluate markup or script.** Notification and media
  content is rendered as text, so a malicious notification body cannot execute.

If you add a code path that runs a command built from network names,
notification content, or file names, keep the argv-list discipline. Passing it
through `sh -c` or a shell string would reintroduce command injection.

## Reporting a problem

Open an issue on the repository, or email the maintainer privately if the
report is sensitive. Please do not include real passwords, tokens, or
`hyprlock` output in a public issue.
