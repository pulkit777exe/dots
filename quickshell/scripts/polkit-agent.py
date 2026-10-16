#!/usr/bin/env python3
"""Island-styled polkit authentication agent.

Owns the polkit protocol (register, sessions, retries) and delegates the
face to the shell: on each challenge it pre-creates a 0600 response file,
wakes the island dialog with one IPC call carrying a JSON payload, and
waits on the response via inotify. Submit writes {"password": ...},
cancel (any close path) writes {"cancelled": true}; both are consumed
exactly once and unlinked immediately.

Password lifetime: tmpfs file, 0600, deleted on first read. Never logged.

Usage:
    polkit-agent.py                 run the agent (foreground; exec from session start)
    polkit-agent.py --self-test     protocol unit tests, no polkit traffic
    polkit-agent.py --stop          unregister path is automatic on SIGTERM; this only documents it
"""

from __future__ import annotations

import argparse
import json
import logging
import os
import re
import signal
import subprocess
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from lib import state_home  # noqa: E402

STATE_DIR = state_home() / "quickshell"
LOG_FILE = STATE_DIR / "polkit-agent.log"
WATCHDOG_SECS = 120

COOKIE_RE = re.compile(r"[^A-Za-z0-9_-]")


def sanitize_cookie(cookie: str) -> str:
    """Clamp a daemon-issued cookie to a safe filename stem."""
    return COOKIE_RE.sub("", cookie or "")[:64]


def bridge_dir() -> Path:
    base = os.environ.get("XDG_RUNTIME_DIR", f"/run/user/{os.getuid()}")
    return Path(base) / "dots-auth"


def resp_path(cookie: str) -> Path:
    return bridge_dir() / f"{sanitize_cookie(cookie)}.resp"


def show_payload(cookie: str, user: str, message: str, retry: bool, path: Path) -> str:
    return json.dumps(
        {
            "cookie": sanitize_cookie(cookie),
            "user": user,
            "message": message,
            "retry": bool(retry),
            "respPath": str(path),
        }
    )


def parse_response(text: str):
    """Return ("password", pw) | ("cancelled", None) | ("empty", None)."""
    if not (text or "").strip():
        return ("empty", None)
    try:
        data = json.loads(text)
    except (ValueError, TypeError):
        return ("empty", None)
    if not isinstance(data, dict):
        return ("empty", None)
    if data.get("cancelled"):
        return ("cancelled", None)
    pw = data.get("password")
    if isinstance(pw, str):
        return ("password", pw)
    return ("empty", None)


def pretty_user(identity_string: str) -> str:
    """'unix-user:pulkit' -> 'pulkit'; anything else passes through."""
    if ":" in identity_string:
        return identity_string.split(":", 1)[1] or identity_string
    return identity_string


def setup_logging() -> logging.Logger:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    logger = logging.getLogger("polkit-agent")
    logger.setLevel(logging.INFO)
    handler = logging.FileHandler(LOG_FILE)
    handler.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(message)s"))
    logger.addHandler(handler)
    return logger


# --------------------------------------------------------------------------
# Live agent (gi imports stay here so --self-test needs nothing but stdlib
# for the pure parts; gi is imported lazily inside main()).
# --------------------------------------------------------------------------


def run_agent(logger: logging.Logger) -> int:
    import gi

    gi.require_version("Polkit", "1.0")
    gi.require_version("PolkitAgent", "1.0")
    from gi.repository import Gio, GLib, Polkit, PolkitAgent

    loop = GLib.MainLoop()
    sessions: dict = {}
    attempts: dict = {}

    directory = bridge_dir()
    directory.mkdir(parents=True, exist_ok=True)
    os.chmod(directory, 0o700)
    for stale in directory.glob("*.resp"):
        try:
            stale.unlink()
        except OSError:
            pass

    def ipc(*args: str) -> None:
        try:
            subprocess.run(
                ["quickshell", "ipc", "call", *args],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=10,
                check=False,
            )
        except Exception as e:  # noqa: BLE001 - best effort wake-up
            logger.warning("ipc call failed: %s", e)

    def cleanup(cookie: str) -> None:
        sessions.pop(cookie, None)
        attempts.pop(cookie, None)
        try:
            resp_path(cookie).unlink()
        except OSError:
            pass

    def dismiss_dialog(cookie: str) -> None:
        ipc("auth", "dismiss", sanitize_cookie(cookie))

    def show_dialog(cookie: str, user: str, message: str, retry: bool) -> None:
        path = resp_path(cookie)
        try:
            fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
            os.close(fd)
        except OSError as e:
            logger.warning("cannot pre-create %s: %s", path, e)
            return
        ipc("auth", "show", show_payload(cookie, user, message, retry, path))

    def finish(cookie: str, ok: bool) -> None:
        dismiss_dialog(cookie)
        cleanup(cookie)
        logger.info("cookie %s completed ok=%s", sanitize_cookie(cookie), ok)

    def on_session_request(session, _request: str, _echo_on: bool, cookie: str) -> None:
        st = sessions.get(cookie)
        if st is None:
            return
        show_dialog(cookie, st["user"], st["message"], st["attempts"] > 0)

    def on_session_completed(session, gained: bool, cookie: str) -> None:
        if gained:
            finish(cookie, True)
        else:
            # polkitd re-challenges via a fresh initiate; surface the error
            # meanwhile so a retry lands on an explanatory dialog.
            st = sessions.get(cookie)
            if st is not None:
                show_dialog(cookie, st["user"], st["message"], True)

    def arm_watchdog(cookie: str) -> None:
        def fired() -> bool:
            if cookie in sessions:
                logger.warning("cookie %s watchdog: no response, cancelling", sanitize_cookie(cookie))
                st = sessions.pop(cookie, None)
                if st is not None:
                    try:
                        st["session"].cancel()
                    except Exception:  # noqa: BLE001
                        pass
                dismiss_dialog(cookie)
                cleanup(cookie)
            return False

        GLib.timeout_add_seconds(WATCHDOG_SECS, fired)

    def on_resp_changed(monitor, _file, _other, _event, _data=None) -> None:
        for cookie in list(sessions):
            path = resp_path(cookie)
            try:
                text = path.read_text()
            except OSError:
                continue
            kind, value = parse_response(text)
            if kind == "empty":
                continue
            try:
                path.unlink()
            except OSError:
                pass
            st = sessions.get(cookie)
            if st is None:
                continue
            if kind == "cancelled":
                logger.info("cookie %s cancelled by user", sanitize_cookie(cookie))
                try:
                    st["session"].cancel()
                except Exception:  # noqa: BLE001
                    pass
                finish(cookie, False)
            else:
                try:
                    st["session"].response(value)
                except Exception as e:  # noqa: BLE001
                    logger.warning("session.response failed: %s", e)
                    finish(cookie, False)

    class Agent(PolkitAgent.Listener):
        def do_initiate_authentication(
            self, action_id, message, icon_name, details, cookie, identities, cancellable
        ):
            cookie = sanitize_cookie(cookie)
            if not cookie or not identities:
                logger.warning("ignoring challenge without cookie/identities")
                return
            old = sessions.pop(cookie, None)
            if old is not None:
                try:
                    old["session"].cancel()
                except Exception:  # noqa: BLE001
                    pass
            try:
                ident = identities[0]
                user = pretty_user(ident.to_string())
            except Exception as e:  # noqa: BLE001
                logger.warning("bad identity: %s", e)
                return
            session = PolkitAgent.Session.new(ident, cookie)
            attempts[cookie] = attempts.get(cookie, 0)
            sessions[cookie] = {
                "session": session,
                "user": user,
                "message": message or action_id,
                "attempts": attempts[cookie],
            }
            session.connect("request", on_session_request, cookie)
            session.connect("completed", on_session_completed, cookie)
            session.initiate()
            attempts[cookie] += 1
            arm_watchdog(cookie)
            logger.info("challenge %s for %s (%s)", cookie, user, action_id)

    def session_id() -> str | None:
        # The kernel audit session of THIS process is authoritative;
        # XDG_SESSION_ID is inherited across session boundaries (ssh,
        # sudo, containers) and can point at a session we don't live in.
        try:
            with open("/proc/self/sessionid") as f:
                sid = f.read().strip()
            if sid and sid != "4294967295":
                return sid
        except OSError:
            pass
        sid = os.environ.get("XDG_SESSION_ID")
        if sid:
            return sid
        try:
            proxy = Gio.DBusProxy.new_for_bus_sync(
                Gio.BusType.SYSTEM,
                Gio.DBusProxyFlags.NONE,
                None,
                "org.freedesktop.login1",
                "/org/freedesktop/login1",
                "org.freedesktop.login1.Manager",
                None,
            )
            res = proxy.call_sync(
                "GetSessionByPID", GLib.Variant("(u)", (os.getpid(),)), Gio.DBusCallFlags.NONE, -1, None
            )
            return res.unpack()[0] or None
        except Exception as e:  # noqa: BLE001
            logger.warning("no session id: %s", e)
            return None

    def handle_term(*_args) -> None:
        logger.info("SIGTERM, unregistering")
        try:
            agent.unregister(handle)
        except Exception:  # noqa: BLE001
            pass
        loop.quit()

    sid = session_id()
    if not sid:
        logger.error("cannot determine session id; set XDG_SESSION_ID")
        return 2
    try:
        subject = Polkit.UnixSession.new(sid)
    except Exception as e:  # noqa: BLE001
        logger.error("cannot build session subject: %s", e)
        return 2
    agent = Agent()
    try:
        handle = agent.register(0, subject, "/org/dots/PolicyKit1/AuthenticationAgent")
    except Exception as e:  # noqa: BLE001
        logger.error("register failed: %s", e)
        return 2
    if handle in (None, False):
        logger.error("polkitd refused registration")
        return 2
    logger.info("registered for session %s", sid)

    monitor = Gio.File.new_for_path(str(directory)).monitor_directory(Gio.FileMonitorFlags.NONE, None)
    monitor.connect("changed", on_resp_changed)

    try:
        from gi.repository import GLibUnix

        GLibUnix.signal_add(GLib.PRIORITY_DEFAULT, signal.SIGTERM, handle_term)
        GLibUnix.signal_add(GLib.PRIORITY_DEFAULT, signal.SIGINT, handle_term)
    except (ImportError, AttributeError):
        GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGTERM, handle_term)
        GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGINT, handle_term)
    try:
        loop.run()
    finally:
        for cookie in list(sessions):
            cleanup(cookie)
    return 0


def self_test() -> int:
    failures = []

    def check(name: str, cond: bool, detail: str = "") -> None:
        print(("ok" if cond else "FAIL"), "-", name, detail)
        if not cond:
            failures.append(name)

    check("cookie passthrough", sanitize_cookie("abc-123_X") == "abc-123_X")
    check("cookie strips slashes", sanitize_cookie("a/b\\c") == "abc")
    check("cookie truncates", len(sanitize_cookie("x" * 100)) == 64)
    check("cookie empty", sanitize_cookie("") == "")
    check(
        "payload round-trips",
        json.loads(show_payload("c 1", "u", "m", True, Path("/r/c.resp")))["cookie"] == "c 1".replace(" ", ""),
    )
    check("payload carries path", json.loads(show_payload("c", "u", "m", False, Path("/r")))["respPath"] == "/r")
    check("parse password", parse_response('{"password": "s3cret"}') == ("password", "s3cret"))
    check("parse cancelled", parse_response('{"cancelled": true}') == ("cancelled", None))
    check("parse empty", parse_response("") == ("empty", None))
    check("parse garbage", parse_response("{nope") == ("empty", None))
    check("parse non-string pw", parse_response('{"password": 5}') == ("empty", None))
    check("pretty unix-user", pretty_user("unix-user:pulkit") == "pulkit")
    check("pretty passthrough", pretty_user("weird") == "weird")

    import gi

    gi.require_version("Polkit", "1.0")
    gi.require_version("PolkitAgent", "1.0")
    from gi.repository import Gio, GLib, Polkit, PolkitAgent

    check("Listener.register exists", hasattr(PolkitAgent.Listener, "register"))
    check("Session.response exists", hasattr(PolkitAgent.Session, "response"))
    check("Session.cancel exists", hasattr(PolkitAgent.Session, "cancel"))
    try:
        Polkit.UnixSession.new("selftest")
        unix_ok = True
    except Exception as e:  # noqa: BLE001
        unix_ok, unix_err = False, str(e)
        print("  note:", unix_err)
    check("UnixSession.new constructs", unix_ok)

    seen = []
    with tempfile.TemporaryDirectory() as tmp:
        watchdir = Path(tmp)
        mon = Gio.File.new_for_path(str(watchdir)).monitor_directory(Gio.FileMonitorFlags.NONE, None)

        def on_change(_m, f, _o, _e, _d=None):
            try:
                if f.get_path() and Path(f.get_path()).read_text().strip():
                    seen.append(Path(f.get_path()).name)
            except OSError:
                pass

        mon.connect("changed", on_change)
        loop = GLib.MainLoop()

        def write_and_quit():
            (watchdir / "c1.resp").write_text('{"password": "x"}')
            return False

        GLib.timeout_add(100, write_and_quit)
        GLib.timeout_add_seconds(5, loop.quit)
        loop.run()
    check("inotify round-trip", "c1.resp" in seen, str(seen))

    print(f"self-test: {len(failures)} failures" if failures else "self-test: all green")
    return 1 if failures else 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description="island-styled polkit agent")
    parser.add_argument("--self-test", action="store_true", help="protocol unit tests, no polkit traffic")
    args = parser.parse_args(argv)
    if args.self_test:
        return self_test()
    logger = setup_logging()
    logger.info("starting")
    try:
        return run_agent(logger)
    except Exception:  # noqa: BLE001 - never die silently
        logger.exception("fatal")
        return 3


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
