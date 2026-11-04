#!/usr/bin/env python3
"""Pack the Godot project into a reproducible zip for `godot-runner --main-pack`.

The project has no imported assets, so the pack is just the source tree. Files
are sorted and timestamps fixed so the same tree always gives the same bytes.

Usage: pack.py GAME_DIR OUT_ZIP
"""
import os
import sys
import zipfile

SKIP_DIRS = {"tests"}
SKIP_FILES = {"export_presets.cfg"}
KEEP_HIDDEN = {".godot/global_script_class_cache.cfg"}
EPOCH = (1980, 1, 1, 0, 0, 0)


def files(root):
    for dirpath, dirnames, filenames in os.walk(root):
        rel_dir = os.path.relpath(dirpath, root)
        dirnames[:] = sorted(
            d for d in dirnames
            if d not in SKIP_DIRS or rel_dir != "."
        )
        for name in sorted(filenames):
            rel = os.path.normpath(os.path.join(rel_dir, name)).replace(os.sep, "/")
            hidden = any(part.startswith(".") for part in rel.split("/"))
            if hidden and rel not in KEEP_HIDDEN:
                continue
            if rel in SKIP_FILES:
                continue
            yield rel


def main():
    root, out = sys.argv[1], sys.argv[2]
    names = sorted(files(root))
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for rel in names:
            info = zipfile.ZipInfo(rel, EPOCH)
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            with open(os.path.join(root, rel), "rb") as f:
                z.writestr(info, f.read())
    print(f"packed {len(names)} files into {out}")


if __name__ == "__main__":
    main()
