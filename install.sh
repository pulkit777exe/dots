#!/usr/bin/env bash
# install.sh — link this repo's configs into ~/.config and sanity-check the
# runtime deps they need. Safe to re-run any time (idempotent): anything it
# would replace is moved aside, never deleted.
#
# Works both from a checkout and when piped:
#     ./install.sh
#     ./install.sh --dry-run          # show the plan, change nothing
#     ./install.sh --check            # verify the current session only
#     curl -fsSL <raw>/install.sh | bash -s -- --dry-run
#
# Written for Fedora first (dnf/COPR), since that's the target machine, but
# the symlinking itself is distro-agnostic.

set -euo pipefail

# Resolve the repo root whether we're a file on disk or a stream on stdin.
# BASH_SOURCE points at the fd name ("bash"/"/dev/stdin") when piped, so
# fall back to a clone next to the script, then to the cwd.
resolve_repo_dir() {
    local src="${BASH_SOURCE[0]:-}"
    local dir=""
    if [ -f "$src" ]; then
        dir="$(cd "$(dirname "$src")" && pwd)"
    fi
    if [ -n "$dir" ] && [ -d "$dir/hypr" ] && [ -d "$dir/colors" ]; then
        printf '%s\n' "$dir"
        return 0
    fi
    local cwd
    cwd="$(pwd)"
    if [ -d "$cwd/hypr" ] && [ -d "$cwd/colors" ]; then
        printf '%s\n' "$cwd"
        return 0
    fi
    return 1
}

REPO_DIR="$(resolve_repo_dir || true)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"
DRY_RUN=0
CHECK_ONLY=0
ASSUME_YES=0

# Every top-level dir in this repo that's meant to land in ~/.config/<name>.
UNITS=(colors hypr kitty quickshell vlc Thunar)

log()  { printf '\033[1;32m==>\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m!!\033[0m %s\n' "$1" >&2; }
err()  { printf '\033[1;31mxx\033[0m %s\n' "$1" >&2; }
run()  { if [ "$DRY_RUN" -eq 1 ]; then printf '   would run: %s\n' "$*"; else "$@"; fi; }

usage() {
    cat <<'USAGE'
usage: install.sh [--dry-run] [--check] [--yes] [--help]

  --dry-run   print the plan without touching anything
  --check     only verify the installed config; make no changes
  --yes       do not prompt before moving an existing config aside
  --help      show this message

Moving an existing ~/.config/<unit> aside is always reversible — it is
renamed to <unit>.pre-install.<timestamp>, never deleted — but it is the
one step here that touches files this repo did not create, so it asks
first unless --yes is given.
USAGE
}

while [ $# -gt 0 ]; do
    case "$1" in
        --dry-run)   DRY_RUN=1 ;;
        --check)     CHECK_ONLY=1 ;;
        -y|--yes)    ASSUME_YES=1 ;;
        -h|--help)   usage; exit 0 ;;
        *)           err "unknown argument: $1"; usage >&2; exit 2 ;;
    esac
    shift
done

link_unit() {
    local name="$1"
    local src="$REPO_DIR/$name"
    local dst="$CONFIG_DIR/$name"

    if [ ! -d "$src" ]; then
        warn "skipping $name — not present in the repo"
        return
    fi

    # A unit dir that exists but is empty would install a hollow config that
    # silently breaks the apps reading it. Treat that as an error, not a pass.
    if [ -z "$(ls -A "$src" 2>/dev/null)" ]; then
        err "skipping $name — $src exists but is empty"
        return 1
    fi

    if [ -L "$dst" ] && [ "$(readlink -f "$dst")" = "$(readlink -f "$src")" ]; then
        log "$name already linked"
        return 0
    fi

    if [ -e "$dst" ] || [ -L "$dst" ]; then
        local backup="$dst.pre-install.$(date +%Y%m%d-%H%M%S)"

        if [ "$DRY_RUN" -eq 1 ]; then
            warn "$dst exists and isn't our symlink — would move it to $backup"
        elif [ "$ASSUME_YES" -eq 0 ]; then
            # This is the only step that touches files the repo didn't
            # create. Refuse rather than guess when there is no TTY to ask
            # on — a non-interactive run (CI, cron, a piped bootstrap) must
            # never silently relocate someone's live config.
            if [ ! -t 0 ]; then
                err "$dst exists and isn't our symlink, and there is no terminal to confirm on."
                err "Re-run with --yes to allow moving it to $backup, or move it yourself first."
                return 1
            fi
            warn "$dst exists and isn't our symlink."
            printf '   Move it to %s ? [y/N] ' "$backup"
            local reply=""
            read -r reply || reply=""
            case "$reply" in
                [yY]|[yY][eE][sS]) ;;
                *) warn "left $dst alone"; return 0 ;;
            esac
            mv "$dst" "$backup"
        else
            warn "$dst exists and isn't our symlink — moving it to $backup"
            mv "$dst" "$backup"
        fi
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        log "$name would be linked -> $dst"
    else
        mkdir -p "$(dirname "$dst")"
        ln -s "$(readlink -f "$src")" "$dst"
        log "linked $name -> $dst"
    fi
}

# check_bin <name> <hint> [required|optional] [abs-path ...]
#
# Several of these daemons are not on PATH even when installed: polkitd
# lives at /usr/lib/polkit-1/polkitd and is never symlinked into /usr/bin,
# so `command -v polkit` reported a working system as broken. Allow
# absolute-path fallbacks.
#
# The kind argument separates a dependency this config cannot run without
# from a nicety — "3 things missing" is only useful if you know which of
# them matter.
check_bin() {
    local bin="$1" pkg_hint="$2" kind="${3:-required}"
    shift 3 2>/dev/null || shift $#
    local extra=("$@")

    local found=0 via=""
    if command -v "$bin" >/dev/null 2>&1; then
        found=1
    else
        local p
        for p in ${extra+"${extra[@]}"}; do
            if [ -x "$p" ]; then found=1; via="$p"; break; fi
        done
    fi

    if [ "$found" -eq 1 ]; then
        if [ -n "$via" ]; then
            log "found $bin (not on PATH: $via)"
        else
            log "found $bin"
        fi
        return 0
    fi

    if [ "$kind" = "optional" ]; then
        warn "$bin not found (optional) — $pkg_hint"
        MISSING_OPTIONAL+=("$bin")
    else
        err "$bin not found — $pkg_hint"
        MISSING+=("$bin")
        # Tracked separately from the config checks so a missing required
        # binary can fail the run's verdict. It shares MISSING with
        # check_session's own findings purely so one summary lists them all.
        MISSING_REQ_BIN+=("$bin")
    fi
    # Deliberately return 0. Callers are bare statements under `set -e`, and
    # a non-zero here would abort the whole run on the first missing
    # dependency. The MISSING arrays are what carry the result.
    return 0
}

MISSING=()
MISSING_OPTIONAL=()
MISSING_REQ_BIN=()

check_session() {
    local fail=0

    echo
    log "verifying installed config in $CONFIG_DIR"

    for u in "${UNITS[@]}"; do
        local dst="$CONFIG_DIR/$u"
        if [ ! -e "$dst" ]; then
            err "$u: not installed"
            fail=1
        elif [ -L "$dst" ]; then
            log "$u: linked -> $(readlink -f "$dst")"
        else
            warn "$u: real directory, not a symlink (run install.sh to take over)"
            fail=1
        fi
    done

    # The shell is only useful if its entrypoint and the Keybinds singleton
    # are both present — those are the two files Hyprland and the global
    # shortcuts depend on.
    for f in "$CONFIG_DIR/quickshell/shell.qml" "$CONFIG_DIR/quickshell/modules/Keybinds.qml" \
             "$CONFIG_DIR/quickshell/modules/qmldir" "$CONFIG_DIR/hypr/hyprland.lua" \
             "$CONFIG_DIR/colors/index.json" "$CONFIG_DIR/kitty/kitty.conf"; do
        if [ -e "$f" ]; then
            log "present: ${f#"$CONFIG_DIR"/}"
        else
            err "missing: ${f#"$CONFIG_DIR"/}"
            fail=1
        fi
    done

    # The theme catalog must be the dict form the discovery script expects.
    if [ -e "$CONFIG_DIR/colors/index.json" ]; then
        if command -v python3 >/dev/null 2>&1; then
            if python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); sys.exit(0 if isinstance(d.get("themes"), dict) else 1)' \
                "$CONFIG_DIR/colors/index.json" 2>/dev/null; then
                log "colors/index.json: theme catalog OK"
            else
                err "colors/index.json: 'themes' is not a key->metadata object; theme discovery will fail"
                fail=1
            fi
        fi
    fi

    if [ "${#MISSING[@]}" -gt 0 ]; then
        echo
        err "missing REQUIRED: ${MISSING[*]}"
        err "the desktop will not be whole until these are installed"
    fi
    if [ "${#MISSING_OPTIONAL[@]}" -gt 0 ]; then
        echo
        warn "missing optional (features degrade): ${MISSING_OPTIONAL[*]}"
    fi

    # A missing required binary is part of the verdict even though the config
    # checks are what this function owns. Without this the run printed
    # "check passed" on a machine missing a required dependency, and exited 0,
    # so bootstrap.sh read a broken install as a good one.
    if [ "${#MISSING_REQ_BIN[@]}" -gt 0 ]; then
        fail=1
    fi

    echo
    if [ "$fail" -eq 0 ]; then
        log "check passed"
    else
        err "check FAILED — see above"
    fi
    return "$fail"
}

main() {
    # Refuse root. CONFIG_DIR is derived from $HOME, so under sudo this
    # installs into /root/.config instead of the real user's config — it
    # reports success while doing nothing useful, and leaves stray symlinks
    # in root's home pointing into the user's dotfiles. Nothing here needs
    # root: it only writes inside $HOME.
    if [ "$(id -u)" -eq 0 ]; then
        err "Refusing to run as root."
        err "Run it as your normal user:  ./install.sh"
        err "(Under sudo, \$HOME is /root, so this would link /root/.config instead of yours.)"
        exit 1
    fi

    if [ -z "$REPO_DIR" ]; then
        err "cannot locate the repo root (no hypr/ and colors/ found)."
        err "Run this from a clone of the repo, or use ./bootstrap.sh."
        exit 1
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        log "dry run — no changes will be made"
    fi
    log "repo:    $REPO_DIR"
    log "target:  $CONFIG_DIR"

    if [ "$CHECK_ONLY" -eq 0 ]; then
        echo
        log "linking configs"
        for u in "${UNITS[@]}"; do
            link_unit "$u" || true
        done
    fi

    echo
    log "checking runtime dependencies (see README.md > Requirements)"
    echo
    log "required runtime"
    check_bin hyprland "sudo dnf copr enable solopasha/hyprland && sudo dnf install hyprland"
    check_bin quickshell "not in Fedora's official repos — COPR build (status moves fast) or source build; must match this machine's Qt6 minor version, see README.md"
    check_bin kitty "sudo dnf install kitty"
    check_bin python3 "sudo dnf install python3"
    check_bin cliphist "sudo dnf install cliphist   (or: go install github.com/sentriz/cliphist@latest)"
    check_bin wl-copy "sudo dnf install wl-clipboard"
    # Referenced by modules/startup.lua and services/Theme.qml.
    check_bin hyprpaper "sudo dnf install hyprpaper — without it the wallpaper daemon never starts"
    # Referenced by hypr/hyprlock.lua and the SUPER+L bind.
    check_bin hyprlock "sudo dnf install hyprlock — without it SUPER+L does nothing"
    # Referenced by hypr/hypridle.toml.
    check_bin hypridle "sudo dnf install hypridle — without it idleDPMS/idle actions never fire"
    # Not a bare `polkit` binary: the daemon is polkitd and ships outside PATH.
    check_bin polkitd "sudo dnf install polkit" required /usr/lib/polkit-1/polkitd /usr/libexec/polkitd

    echo
    log "optional (features degrade without them)"
    check_bin brightnessctl "sudo dnf install brightnessctl — XF86MonBrightness* keys"
    check_bin playerctl "sudo dnf install playerctl — XF86Audio* media keys"
    check_bin hyprsunset "blue-light filter; without it the control centre's Night Light toggle does nothing" optional

    local cs=0
    check_session || cs=$?

    echo
    if [ "$CHECK_ONLY" -eq 1 ]; then
        log "done (check only)"
    else
        log "done — log out, select the Hyprland session, and log back in"
    fi

    # The links are in place either way, so a missing dependency is reported
    # rather than fatal to the run itself. The exit code still reflects it so
    # bootstrap.sh (and CI) do not read a broken machine as a clean install.
    if [ "$cs" -ne 0 ]; then
        err "finished with errors — see above"
        return "$cs"
    fi
    return 0
}

main "$@"
