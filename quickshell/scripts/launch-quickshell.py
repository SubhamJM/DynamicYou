#!/usr/bin/env python3
import ctypes
import os
import sys


def main():
    # Restore the shell's former physical size on a 1x monitor without scaling apps.
    os.environ["QT_SCALE_FACTOR"] = "1.2"
    # Drop idle jemalloc pages promptly after closing QML panels.
    os.environ.setdefault(
        "MALLOC_CONF",
        "background_thread:true,narenas:2,dirty_decay_ms:500,muzzy_decay_ms:0,tcache_max:4096,thp:never",
    )
    os.environ.setdefault("QSG_ATLAS_WIDTH", "1024")
    os.environ.setdefault("QSG_ATLAS_HEIGHT", "1024")

    # Skip implicit huge pages while keeping explicitly requested ones available.
    pr_set_thp_disable = 41
    pr_thp_disable_except_advised = 2
    libc = ctypes.CDLL(None, use_errno=True)
    libc.prctl(pr_set_thp_disable, 1, pr_thp_disable_except_advised, 0, 0)
    os.execvp("qs", ["qs", *sys.argv[1:]])


if __name__ == "__main__":
    main()
