#!/usr/bin/env python3
"""Build a distributable SpecKit-Salesforce release zip.

Produces ``speckit-salesforce-v<version>.zip`` containing a top-level
``speckit-salesforce-v<version>/`` folder, matching the ``download_url`` in
``latest-release.json``. This is the artefact the one-line manifest installer
downloads and extracts.

Usage (from the repo root):

    python3 build-release.py

Then commit the generated zip together with ``latest-release.json`` and push.
When bumping the version, update ``pyproject.toml`` and ``latest-release.json``
first, then re-run this script.
"""
import pathlib
import re
import zipfile

ROOT = pathlib.Path(__file__).resolve().parent

INCLUDE_FILES = [
    "install.sh",
    "update.sh",
    "sample-constitution.md",
    "README.md",
    "INSTALLATION_GUIDE.md",
]
INCLUDE_DIRS = [".specify", ".cursor", ".claude", "docs"]
EXCLUDE_DIR_NAMES = {"__pycache__", ".git"}
EXCLUDE_SUFFIXES = (".pyc", ".pyo", ".bak", ".zip")
EXCLUDE_FILE_NAMES = {".DS_Store", "Thumbs.db"}


def get_version() -> str:
    text = (ROOT / "pyproject.toml").read_text(encoding="utf-8")
    match = re.search(r'^version\s*=\s*"([^"]+)"', text, re.MULTILINE)
    return match.group(1) if match else "1.0.0"


def keep(rel: pathlib.Path) -> bool:
    if EXCLUDE_DIR_NAMES & set(rel.parts):
        return False
    if rel.name in EXCLUDE_FILE_NAMES:
        return False
    if rel.suffix in EXCLUDE_SUFFIXES:
        return False
    return True


def main() -> None:
    version = get_version()
    prefix = f"speckit-salesforce-v{version}"
    zip_name = f"{prefix}.zip"
    out = ROOT / zip_name
    if out.exists():
        out.unlink()

    count = 0
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as zf:
        for name in INCLUDE_FILES:
            path = ROOT / name
            if path.is_file():
                zf.write(path, f"{prefix}/{name}")
                count += 1
        for dirname in INCLUDE_DIRS:
            base = ROOT / dirname
            if not base.exists():
                continue
            for path in sorted(base.rglob("*")):
                rel = path.relative_to(ROOT)
                if path.is_file() and keep(rel):
                    zf.write(path, f"{prefix}/{rel.as_posix()}")
                    count += 1

    print(f"Built {zip_name} ({count} files, top-level folder {prefix}/)")


if __name__ == "__main__":
    main()
