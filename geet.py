#!/usr/bin/env python3
from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path

def main() -> int:
    # This file will be installed into site-packages; bin/ will be installed next to it.
    here = Path(__file__).resolve().parent
    script = here / "bin" / "geet.sh"

    if not script.exists():
        sys.stderr.write(f"geet: expected script not found at {script}\n")
        return 1

    # Ensure executable bit isn't required; run through bash explicitly
    cmd = ["bash", str(script), *sys.argv[1:]]
    return subprocess.call(cmd)

if __name__ == "__main__":
    raise SystemExit(main())
