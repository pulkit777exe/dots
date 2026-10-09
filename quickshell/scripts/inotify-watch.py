#!/usr/bin/env python3

import ctypes
import ctypes.util
import errno
import os
import sys

IN_MODIFY = 0x00000002
IN_ATTRIB = 0x00000004
IN_CLOSE_WRITE = 0x00000008
IN_MOVED_FROM = 0x00000040
IN_MOVED_TO = 0x00000080
IN_CREATE = 0x00000100
IN_DELETE = 0x00000200
IN_DELETE_SELF = 0x00000400
IN_MOVE_SELF = 0x00000800
IN_ISDIR = 0x40000000

MASK = (
    IN_ATTRIB
    | IN_CLOSE_WRITE
    | IN_CREATE
    | IN_DELETE
    | IN_DELETE_SELF
    | IN_MODIFY
    | IN_MOVED_FROM
    | IN_MOVED_TO
    | IN_MOVE_SELF
)

libc = ctypes.CDLL(ctypes.util.find_library("c"), use_errno=True)
libc.inotify_init1.restype = ctypes.c_int
libc.inotify_add_watch.restype = ctypes.c_int

class InotifyEvent(ctypes.Structure):
    _fields_ = [
        ("wd", ctypes.c_int),
        ("mask", ctypes.c_uint32),
        ("cookie", ctypes.c_uint32),
        ("len", ctypes.c_uint32),
        ("name", ctypes.c_char * 0),
    ]

def main() -> int:
    args = sys.argv[1:]
    recursive = False
    if args and args[0] == "-r":
        recursive = True
        args = args[1:]

    if not args:
        print("usage: inotify-watch.py [-r] PATH [PATH ...]", file=sys.stderr)
        return 2

    fd = libc.inotify_init1(0)
    if fd < 0:
        print(f"inotify_init1 failed: {os.strerror(ctypes.get_errno())}", file=sys.stderr)
        return 1

    wd_to_path = {}

    def add_watch(path: str) -> None:
        if not os.path.exists(path):
            print(f"path does not exist: {path}", file=sys.stderr)
            return
        try:
            wd = libc.inotify_add_watch(fd, os.fsencode(path), MASK)
        except OSError as e:
            print(f"failed to watch {path}: {e}", file=sys.stderr)
            return
        if wd < 0:
            print(f"failed to watch {path}: {os.strerror(ctypes.get_errno())}", file=sys.stderr)
            return
        wd_to_path[wd] = path
        if recursive and os.path.isdir(path):
            for root, dirs, _files in os.walk(path):
                for d in dirs:
                    add_watch(os.path.join(root, d))

    for p in args:
        add_watch(os.path.abspath(p))

    if not wd_to_path:
        print("no paths successfully watched", file=sys.stderr)
        return 1

    buf = ctypes.create_string_buffer(4096)
    while True:
        try:
            data = os.read(fd, len(buf))
        except OSError as e:
            if e.errno == errno.EINTR:
                continue
            raise
        n = len(data)
        if n <= 0:
            continue
        offset = 0
        while offset + ctypes.sizeof(InotifyEvent) <= n:
            event = InotifyEvent.from_buffer_copy(data[offset:])
            name = ""
            if event.len:
                name_start = offset + ctypes.sizeof(InotifyEvent)
                name_bytes = data[name_start:name_start + event.len]
                name = name_bytes.rstrip(b"\x00").decode("utf-8", "replace")
            path = wd_to_path.get(event.wd, "")
            print(os.path.join(path, name) if name else path, flush=True)
            if (
                recursive
                and event.len
                and event.mask & IN_ISDIR
                and event.mask & (IN_CREATE | IN_MOVED_TO)
            ):
                new_dir = os.path.join(path, name)
                add_watch(new_dir)
            offset += ctypes.sizeof(InotifyEvent) + event.len

if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(0)
