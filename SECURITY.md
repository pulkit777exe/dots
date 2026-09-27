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
plain config — there is no build step, no package to compile, and no code that
fetches anything at runtime (see "No network access" below), so reading it is
a complete audit.

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

## No network access

Nothing in this repo reaches the network at runtime. The Python helpers
(`list-themes.py`, `publish-colors.py`, `inotify-watch.py`, `list-apps.py`)
read and write local files and shell out to local tools. `generate-theme-wallpapers.py` synthesises wallpapers locally
with PIL. There is no `curl`/`wget`/`urllib` in any script, so installing this
cannot phone home, and there is no update check that runs on its own.

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

Wallpapers are **not** committed — they are large binaries, and
`colors/index.json` deliberately contains no absolute paths, so
`list-themes.py` discovers wallpaper directories on each machine at runtime.

## Privilege boundaries

Two components sit on a trust boundary and are worth understanding:

- **`quickshell/services/Auth.qml`** is a polkit authentication agent. It
  forwards the password you type to the requesting application's agent flow;
  it does not grant anything itself. It is the *agent*, not the authority —
  polkitd and the application's `.policy` files decide.
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
