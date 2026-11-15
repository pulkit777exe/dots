#!/usr/bin/env bash
# Lightweight managed-state manifest/receipt for drift detection.

# shellcheck shell=bash

dots_state_manifest_file() { printf '%s\n' "$(dots_state_dir)/state/manifest.json"; }

dots_write_manifest() {
    local repo_dir="${1:?repo_dir required}" status="${2:-unknown}"
    local manifest config_dir state_home
    manifest="$(dots_state_manifest_file)"
    config_dir="$(dots_config_dir)"
    state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
    mkdir -p "$(dots_state_dir)/state" 2>/dev/null || true
    if ! command -v python3 >/dev/null 2>&1; then
        warn "python3 not available — skipping state manifest write"
        return 0
    fi
    python3 - "$repo_dir" "$config_dir" "$state_home" "$manifest" "$status" <<'PY'
import hashlib, json, os, subprocess, sys, time
from pathlib import Path

repo_dir, config_dir, state_home, manifest_path, status = sys.argv[1:6]
config_units = ["colors","hypr","kitty","quickshell","sddm","vlc","Thunar"]
home_files = [("zsh/.zshrc", ".zshrc")]
generated = [
    os.path.join(state_home, "quickshell", "hypr.lua"),
    os.path.join(config_dir, "hypr", "hypridle.conf"),
    os.path.join(config_dir, "hypr", "hyprlock.conf"),
]

def stat_info(p):
    try:
        st = os.lstat(p)
        info = {
            "path": p,
            "exists": True,
            "is_symlink": os.path.islink(p),
            "size": st.st_size,
            "mtime": int(st.st_mtime),
            "mode": oct(st.st_mode & 0o777),
        }
        if os.path.islink(p):
            try:
                info["target"] = os.readlink(p)
                info["resolved"] = str(Path(p).resolve())
            except OSError:
                info["target"] = None
        if os.path.isfile(p) and not os.path.islink(p) and st.st_size <= 1024*1024:
            try:
                h = hashlib.sha256()
                with open(p,'rb') as f:
                    for chunk in iter(lambda: f.read(65536), b''):
                        h.update(chunk)
                info["sha256"] = h.hexdigest()
            except OSError:
                pass
        return info
    except OSError:
        return {"path": p, "exists": False}

def git_rev(repo):
    try:
        return subprocess.check_output(["git","-C",repo,"rev-parse","HEAD"], stderr=subprocess.DEVNULL, text=True).strip()
    except Exception:
        return None

links = {}
for u in config_units:
    links[u] = stat_info(os.path.join(config_dir, u))
home = {}
for src_rel, dst_rel in home_files:
    home[dst_rel] = {
        "source": os.path.join(repo_dir, src_rel),
        **stat_info(os.path.join(os.path.expanduser("~"), dst_rel)),
    }
gen = {p: stat_info(p) for p in generated}
data = {
    "schema": 1,
    "written_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    "status": status,
    "repo_dir": repo_dir,
    "repo_revision": git_rev(repo_dir),
    "config_dir": config_dir,
    "state_home": state_home,
    "managed_links": links,
    "managed_home_files": home,
    "generated_files": gen,
}
tmp = manifest_path + ".tmp"
with open(tmp, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2, sort_keys=True)
    f.write("\n")
os.replace(tmp, manifest_path)
print(manifest_path)
PY
}

dots_check_manifest_drift() {
    local repo_dir="${1:?repo_dir required}" manifest
    manifest="$(dots_state_manifest_file)"
    [ -f "$manifest" ] || { info "state manifest: not found (will be created on apply)"; return 0; }
    if ! command -v python3 >/dev/null 2>&1; then
        warn "python3 not available — skipping manifest drift check"
        return 0
    fi
    python3 - "$repo_dir" "$(dots_config_dir)" "${XDG_STATE_HOME:-$HOME/.local/state}" "$manifest" <<'PY'
import json, os, sys
from pathlib import Path

repo_dir, config_dir, state_home, manifest_path = sys.argv[1:5]
try:
    with open(manifest_path, 'r', encoding='utf-8') as f:
        old = json.load(f)
except Exception as e:
    print(f"WARN\tstate manifest unreadable: {e}")
    sys.exit(0)

def stat_info(p):
    try:
        st = os.lstat(p)
        info = {"exists": True, "is_symlink": os.path.islink(p), "size": st.st_size, "mtime": int(st.st_mtime)}
        if os.path.islink(p):
            try:
                info["target"] = os.readlink(p)
                info["resolved"] = str(Path(p).resolve())
            except OSError:
                info["target"] = None
        return info
    except OSError:
        return {"exists": False}

issues = []
for name, prev in (old.get('managed_links') or {}).items():
    cur = stat_info(os.path.join(config_dir, name))
    if cur.get('exists') != prev.get('exists'):
        issues.append(f"link {name}: existence changed ({prev.get('exists')} -> {cur.get('exists')})")
    elif cur.get('is_symlink') and prev.get('is_symlink') and cur.get('resolved') != prev.get('resolved'):
        issues.append(f"link {name}: target changed ({prev.get('resolved')} -> {cur.get('resolved')})")
    elif (not cur.get('is_symlink')) and prev.get('is_symlink'):
        issues.append(f"link {name}: no longer a symlink")
for rel, prev in (old.get('managed_home_files') or {}).items():
    cur = stat_info(os.path.join(os.path.expanduser('~'), rel))
    if cur.get('exists') != prev.get('exists') or cur.get('resolved') != prev.get('resolved'):
        issues.append(f"home {rel}: changed")
for p, prev in (old.get('generated_files') or {}).items():
    cur = stat_info(p)
    if cur.get('exists') != prev.get('exists'):
        issues.append(f"generated {p}: existence changed")
    elif cur.get('exists') and (cur.get('mtime') != prev.get('mtime') or cur.get('size') != prev.get('size')):
        # Not necessarily bad (regenerated), but worth noting as drift from last recorded state.
        issues.append(f"generated {p}: content metadata changed since last manifest")

if issues:
    print("WARN\tstate manifest drift detected since last recorded apply:")
    for i in issues[:20]:
        print(f"WARN\t - {i}")
    if len(issues) > 20:
        print(f"WARN\t - ... and {len(issues)-20} more")
    sys.exit(1)
else:
    print("OK\tstate manifest: no drift detected from last recorded state")
    sys.exit(0)
PY
}

dots_manifest_diff() {
    dots_check_manifest_drift "${1:?repo_dir required}"
}

dots_manifest_show() {
    local manifest
    manifest="$(dots_state_manifest_file)"
    if [ ! -f "$manifest" ]; then
        err "state manifest not found: $manifest"
        return 1
    fi
    if command -v python3 >/dev/null 2>&1; then
        python3 -m json.tool "$manifest"
    else
        cat "$manifest"
    fi
}

dots_manifest_summary() {
    local manifest
    manifest="$(dots_state_manifest_file)"
    if [ ! -f "$manifest" ]; then
        warn "state manifest not found: $manifest"
        return 1
    fi
    if ! command -v python3 >/dev/null 2>&1; then
        echo "$manifest"
        return 0
    fi
    python3 - "$manifest" <<'PY'
import json, sys
m = json.load(open(sys.argv[1], 'r', encoding='utf-8'))
print(f"schema={m.get('schema')} status={m.get('status')} written_at={m.get('written_at')}")
print(f"repo_revision={m.get('repo_revision')}")
print(f"config_dir={m.get('config_dir')}")
print(f"state_home={m.get('state_home')}")
for sec in ('managed_links','managed_home_files','generated_files'):
    d = m.get(sec) or {}
    ok = sum(1 for v in d.values() if isinstance(v, dict) and v.get('exists'))
    print(f"{sec}: {ok}/{len(d)} present")
PY
}

