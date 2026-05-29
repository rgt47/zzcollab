#!/usr/bin/env python3
"""
check-binaries.py  --  pre-build Docker package audit

Reads renv.lock, queries Posit Package Manager for:
  1. System library requirements per package (sysreqs)
  2. Compilation flag (needs_compilation) per package

Then checks the project Dockerfile for the declared system deps and
reports any gaps -- packages that will compile from source and any
system libraries not yet installed in the image.

Usage:
    python3 tools/check-binaries.py [--renv-lock PATH] [--dockerfile PATH]
                                     [--distro SLUG] [--r-version X.Y]
                                     [--fail-on-missing]

Exits 0 when no actionable gaps are found, 1 when --fail-on-missing is
set and missing system deps are detected.
"""

import argparse
import json
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

PPM_BASE = "https://packagemanager.posit.co/__api__/repos/cran"
PPM_BATCH = 75  # packages per sysreqs API call


# ---------------------------------------------------------------------------
# renv.lock parsing
# ---------------------------------------------------------------------------

def read_renv_lock(path: str) -> dict:
    p = Path(path)
    if not p.exists():
        print(f"  renv.lock not found: {path}", file=sys.stderr)
        sys.exit(1)
    with open(p) as f:
        return json.load(f)


def packages_from_lock(lock: dict) -> list[tuple[str, str]]:
    """Return [(name, version), ...] for CRAN-sourced packages only."""
    out = []
    for name, info in lock.get("Packages", {}).items():
        source = info.get("Source", "")
        repo = info.get("Repository", "")
        if source in ("Repository", "CRAN") or "CRAN" in repo:
            out.append((name, info.get("Version", "")))
    return sorted(out)


def r_minor_from_lock(lock: dict) -> str:
    """Return major.minor R version string from renv.lock."""
    ver = lock.get("R", {}).get("Version", "4.4.0")
    parts = ver.split(".")
    return f"{parts[0]}.{parts[1]}" if len(parts) >= 2 else "4.4"


# ---------------------------------------------------------------------------
# Dockerfile parsing
# ---------------------------------------------------------------------------

def installed_system_libs(dockerfile_path: str) -> set[str]:
    """
    Extract apt package names declared in apt-get install lines in the
    Dockerfile. Returns a set of lowercased package names.
    """
    p = Path(dockerfile_path)
    if not p.exists():
        return set()

    libs = set()
    in_apt = False
    with open(p) as f:
        for raw in f:
            line = raw.strip().rstrip("\\").strip()
            if "apt-get install" in line:
                in_apt = True
            if in_apt:
                # Collect tokens that look like apt package names
                for tok in line.split():
                    if tok.startswith("-") or tok in (
                        "apt-get", "install", "&&", "\\", "RUN",
                        "-y", "--no-install-recommends",
                    ):
                        continue
                    libs.add(tok.lower())
                # End of continuation block
                if not raw.rstrip().endswith("\\"):
                    in_apt = False
    return libs


def base_image_os_slug(dockerfile_path: str) -> tuple[str, str]:
    """
    Derive (distro_slug, release) from the Dockerfile BASE_IMAGE ARG or
    FROM line.  Defaults to (noble, 24.04) for rocker images.
    """
    p = Path(dockerfile_path)
    if not p.exists():
        return "noble", "24.04"

    # rocker image → distro map (base images ship Ubuntu LTS)
    rocker_map = {
        "4.4": ("noble", "24.04"),
        "4.5": ("noble", "24.04"),
        "4.3": ("jammy", "22.04"),
        "4.2": ("jammy", "22.04"),
    }
    with open(p) as f:
        for line in f:
            line = line.strip()
            if line.startswith("ARG R_VERSION="):
                rv = line.split("=", 1)[1].split(".")
                key = f"{rv[0]}.{rv[1]}" if len(rv) >= 2 else "4.4"
                return rocker_map.get(key, ("noble", "24.04"))
            if line.startswith("FROM rocker/"):
                tag = line.split(":")[-1] if ":" in line else "4.4"
                parts = tag.split(".")
                key = f"{parts[0]}.{parts[1]}" if len(parts) >= 2 else "4.4"
                return rocker_map.get(key, ("noble", "24.04"))
    return "noble", "24.04"


# ---------------------------------------------------------------------------
# PPM API
# ---------------------------------------------------------------------------

def _get(url: str) -> dict | list | None:
    try:
        req = urllib.request.Request(
            url, headers={"User-Agent": "zzcollab-check-binaries/1.0"}
        )
        with urllib.request.urlopen(req, timeout=15) as resp:
            return json.loads(resp.read().decode())
    except (urllib.error.URLError, json.JSONDecodeError) as exc:
        print(f"  PPM API error ({url}): {exc}", file=sys.stderr)
        return None


def fetch_sysreqs(
    package_names: list[str], distro: str, release: str
) -> dict[str, list[str]]:
    """
    Return {package_name: [apt_dep, ...]} for packages that have system
    requirements on the given distro/release.  Queries in batches of
    PPM_BATCH to stay within URL length limits.
    """
    result: dict[str, list[str]] = {}

    for i in range(0, len(package_names), PPM_BATCH):
        batch = package_names[i : i + PPM_BATCH]
        params = urllib.parse.urlencode(
            {
                "pkgs": ",".join(batch),
                "distribution": distro,
                "release": release,
            }
        )
        url = f"{PPM_BASE}/sysreqs?{params}"
        data = _get(url)
        if not data:
            continue
        # Response shape: {"requirements": [{"packages": [...], "requirements": [{"requirement": ...}]}]}
        # or {"requirements": [{"name": "libcurl4-openssl-dev", "packages": [...]}]}
        for req in data.get("requirements", []):
            dep = req.get("requirement") or req.get("name", "")
            if not dep:
                continue
            for pkg in req.get("packages", []):
                result.setdefault(pkg.lower(), [])
                if dep not in result[pkg.lower()]:
                    result[pkg.lower()].append(dep)

    return result


def fetch_compilation_flags(
    packages: list[tuple[str, str]]
) -> dict[str, bool]:
    """
    Return {name: needs_compilation} for each package.
    Queries PPM in batches.
    """
    result: dict[str, bool] = {}

    for i in range(0, len(packages), PPM_BATCH):
        batch = packages[i : i + PPM_BATCH]
        for name, version in batch:
            params = urllib.parse.urlencode({"name": name})
            data = _get(f"{PPM_BASE}/packages?{params}")
            if data and isinstance(data, list) and data:
                flag = data[0].get("needs_compilation", "no")
                result[name] = str(flag).lower() in ("yes", "true", "1")

    return result


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--renv-lock",    default="renv.lock")
    ap.add_argument("--dockerfile",   default="Dockerfile")
    ap.add_argument("--distro",       default="")
    ap.add_argument("--r-version",    default="")
    ap.add_argument("--fail-on-missing", action="store_true",
                    help="Exit 1 when system dep gaps are found")
    ap.add_argument("--skip-api",     action="store_true",
                    help="Skip PPM network calls (report structure only)")
    args = ap.parse_args()

    print("\n╔══════════════════════════════════════════════════════╗")
    print("║         Pre-build Docker Package Audit               ║")
    print("╚══════════════════════════════════════════════════════╝\n")

    lock = read_renv_lock(args.renv_lock)
    packages = packages_from_lock(lock)
    r_minor = args.r_version or r_minor_from_lock(lock)

    distro, release = base_image_os_slug(args.dockerfile)
    if args.distro:
        distro = args.distro

    print(f"  renv.lock:   {len(packages)} CRAN packages")
    print(f"  Target OS:   Ubuntu {release} ({distro})")
    print(f"  R version:   {r_minor}")
    print(f"  Dockerfile:  {args.dockerfile}\n")

    installed = installed_system_libs(args.dockerfile)

    if args.skip_api:
        print("  --skip-api: skipping PPM network calls.\n")
        return 0

    # -- System requirements --------------------------------------------------
    print("  Querying PPM for system requirements...")
    names = [n for n, _ in packages]
    sysreqs = fetch_sysreqs(names, distro, release)

    missing_deps: dict[str, list[str]] = {}
    for pkg, deps in sysreqs.items():
        absent = [d for d in deps if d.lower() not in installed]
        if absent:
            missing_deps[pkg] = absent

    # -- Compilation flags ----------------------------------------------------
    print("  Querying PPM for compilation flags...")
    compiles = fetch_compilation_flags(packages)
    source_builds = [n for n, flag in compiles.items() if flag]

    # -- Report ---------------------------------------------------------------
    print()
    if source_builds:
        print(f"  ⚙  Packages that will compile from source ({len(source_builds)}):")
        for pkg in sorted(source_builds):
            gap = "  ⚠  missing system deps: " + ", ".join(
                missing_deps.get(pkg.lower(), [])
            ) if pkg.lower() in missing_deps else ""
            print(f"       {pkg}{gap}")
    else:
        print("  ✅ All packages have precompiled binaries.")

    print()
    if missing_deps:
        print(f"  ⚠  System dependency gaps ({len(missing_deps)} packages):")
        print("     Add the following to your Dockerfile apt-get install block:\n")
        all_missing = sorted(
            {d for deps in missing_deps.values() for d in deps}
        )
        for dep in all_missing:
            pkgs_needing = [
                p for p, ds in missing_deps.items() if dep in ds
            ]
            print(f"       {dep:<35}  # needed by: {', '.join(pkgs_needing)}")
        print()
        if args.fail_on_missing:
            return 1
    else:
        print("  ✅ All system dependencies are declared in the Dockerfile.\n")

    return 0


if __name__ == "__main__":
    sys.exit(main())
