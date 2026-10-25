#!/usr/bin/env python3
"""Build the single review place and stamp it with the exact source revision."""
from __future__ import annotations

import hashlib
import json
import subprocess
import zipfile
from pathlib import Path

from build import ROOT, build


def git(*args: str) -> str:
    result = subprocess.run(
        ["git", *args], cwd=ROOT, capture_output=True, text=True, check=True
    )
    return result.stdout.strip()


def main() -> None:
    output = ROOT / "build" / "mining-away.rbxl"
    output.parent.mkdir(exist_ok=True)
    report = build(ROOT / "assets" / "mining-away-base.rbxl", output)
    try:
        revision = git("rev-parse", "HEAD")
        dirty = bool(git("status", "--porcelain", "--untracked-files=normal"))
        source_paths = git("ls-files").splitlines()
    except subprocess.CalledProcessError:
        revision, dirty = "uncommitted-bootstrap", True
        source_paths = []
    metadata = {
        "project": "Olivegord/mining-away",
        "source_commit": revision,
        "source_dirty": dirty,
        "place": output.name,
        "place_sha256": hashlib.sha256(output.read_bytes()).hexdigest(),
        "base_sha256": report["original_sha256"],
        "studio_validation": "Not established by this build command; see review report.",
    }
    metadata_path = output.parent / "revision.json"
    metadata_path.write_text(json.dumps(metadata, indent=2) + "\n")
    package = output.parent / "mining-away-review.zip"
    with zipfile.ZipFile(package, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        archive.write(output, "mining-away.rbxl")
        archive.write(metadata_path, "revision.json")
        archive.write(output.parent / "build-report.json", "build-report.json")
        for relative in source_paths:
            path = ROOT / relative
            if path.is_file() and not path.is_symlink() and not relative.startswith("build/"):
                archive.write(path, "source/" + relative)
    print(json.dumps({"metadata": metadata, "package": str(package)}, indent=2))


if __name__ == "__main__":
    main()

