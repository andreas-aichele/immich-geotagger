#!/usr/bin/env python3
"""Patch package:jni for reproducible Android builds.

The Android linker adds a GNU build-id to libdartjni.so by default. That build-id
can differ between otherwise identical builds, which breaks F-Droid's
reproducible-build signature-copy verification. Disable it in package:jni's
CMake configuration after `flutter pub get`.
"""

from __future__ import annotations

import json
from pathlib import Path
from urllib.parse import unquote, urljoin, urlparse


PROJECT_ROOT = Path.cwd()
PACKAGE_CONFIG = PROJECT_ROOT / ".dart_tool" / "package_config.json"


def package_root(package_name: str) -> Path:
    if not PACKAGE_CONFIG.is_file():
        raise SystemExit(
            f"Missing {PACKAGE_CONFIG}. Run 'flutter pub get' before this script."
        )

    config = json.loads(PACKAGE_CONFIG.read_text(encoding="utf-8"))
    base_uri = PACKAGE_CONFIG.parent.resolve().as_uri() + "/"

    for package in config.get("packages", []):
        if package.get("name") != package_name:
            continue

        root_uri = package.get("rootUri")
        if not root_uri:
            break

        resolved = urljoin(base_uri, root_uri)
        parsed = urlparse(resolved)
        if parsed.scheme != "file":
            raise SystemExit(
                f"package:{package_name} does not resolve to a local file URI: {root_uri}"
            )
        return Path(unquote(parsed.path))

    raise SystemExit(f"package:{package_name} not found in {PACKAGE_CONFIG}")


jni_root = package_root("jni")
cmake_file = jni_root / "src" / "CMakeLists.txt"

if not cmake_file.is_file():
    raise SystemExit(f"Missing package:jni CMake file: {cmake_file}")

text = cmake_file.read_text(encoding="utf-8")
old = 'target_link_options(jni PRIVATE "-Wl,-z,max-page-size=16384")'
new = (
    'target_link_options(jni PRIVATE "-Wl,-z,max-page-size=16384" '
    '"-Wl,--build-id=none")'
)

if new in text:
    print(f"package:jni reproducibility patch already applied: {cmake_file}")
elif old in text:
    cmake_file.write_text(text.replace(old, new, 1), encoding="utf-8")
    print(f"Patched package:jni to disable GNU build-id: {cmake_file}")
else:
    raise SystemExit(
        "Unexpected package:jni CMakeLists.txt format. "
        "Review the reproducibility patch before releasing."
    )
