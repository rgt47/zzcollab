#!/usr/bin/env bash
##############################################################################
# verify.sh - `zzc verify`: the validation layer for reproducibility claims.
#
# Phase 3 of the reproducibility-toggle plan. Where `zzc status` reports the
# capture level inferred from artifact presence (L0-L2), `zzc verify` confirms
# the claim. It runs in two tiers:
#
#   Coherence tier (default, no build): the captured artifacts agree with each
#     other and with .zzcollab-state. Catches the drift a toggle could
#     introduce - a dangling base reference, an install mode that contradicts
#     renv.lock presence, mismatched R versions, a backend conflict.
#
#   Reproduction tier (--full): rebuild the image and run the test suite inside
#     it. This is the only check that earns L3. On success it stamps
#     `verified=<ISO8601>` into .zzcollab-state; any later regeneration rewrites
#     the record without that key, so a changed environment reverts to
#     unverified automatically.
#
# Depends on lib/core.sh (log_*), modules/status.sh (_zzc_state_get,
# _zzc_detect_backend), modules/config.sh. Sourced by zzcollab.sh.
##############################################################################

# Per-run result counters, reset at the top of cmd_verify.
_VRF_FAIL=0
_VRF_WARN=0
_VRF_SKIP=0

_vrf_pass() { printf "  [ ok ] %s\n" "$1"; }
_vrf_fail() { printf "  [FAIL] %s\n" "$1"; _VRF_FAIL=$((_VRF_FAIL + 1)); }
_vrf_warn() { printf "  [warn] %s\n" "$1"; _VRF_WARN=$((_VRF_WARN + 1)); }
_vrf_skip() { printf "  [skip] %s\n" "$1"; _VRF_SKIP=$((_VRF_SKIP + 1)); }

# Extract the R version from a renv.lock (top-level R.Version). Echoes the
# version or nothing. Prefers python3 for correct JSON parsing; falls back to a
# line scan when python3 is absent.
_vrf_renv_r_version() {
    local lock="$1"
    [[ -f "$lock" ]] || return 0
    if command -v python3 >/dev/null 2>&1; then
        python3 -c 'import json,sys
try:
    d = json.load(open(sys.argv[1]))
    print(d.get("R", {}).get("Version", ""))
except Exception:
    pass' "$lock" 2>/dev/null
    else
        grep -A3 '"R"' "$lock" 2>/dev/null | grep -m1 '"Version"' \
            | cut -d'"' -f4
    fi
}

# Confirm a renv.lock is well-formed JSON with a Packages section.
_vrf_renv_lock_valid() {
    local lock="$1"
    command -v python3 >/dev/null 2>&1 || return 2  # cannot check
    python3 -c 'import json,sys
try:
    d = json.load(open(sys.argv[1]))
    sys.exit(0 if isinstance(d.get("Packages"), dict) else 1)
except Exception:
    sys.exit(1)' "$lock" 2>/dev/null
}

# Update (or add) the verified=<value> line in .zzcollab-state without touching
# other keys. Writes through a temp file then mv, since the project directory is
# frequently cloud-synced and an in-place edit can race the sync provider.
_vrf_stamp_verified() {
    local value="$1" tmp
    [[ -f .zzcollab-state ]] || return 1
    tmp=$(mktemp)
    grep -v '^verified=' .zzcollab-state > "$tmp" 2>/dev/null || true
    echo "verified=${value}" >> "$tmp"
    mv "$tmp" .zzcollab-state
}

# cmd_verify [dir] [--full]
cmd_verify() {
    local d="." full=false
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --full) full=true; shift ;;
            help|--help|-h)
                cat << 'EOF'
VERIFY - confirm the reproducibility claim

USAGE:
    zzc verify [dir] [--full]

Coherence tier (default, no build):
    Checks that the captured artifacts are mutually consistent and agree
    with .zzcollab-state. Fast; requires no Docker.

Reproduction tier (--full):
    Rebuilds the image and runs the test suite inside it. Only this earns
    the L3 (verified) level and stamps .zzcollab-state. Requires Docker and
    may take several minutes.

EXIT STATUS:
    0  all checks passed (warnings allowed)
    1  one or more checks failed
EOF
                return 0 ;;
            -*) log_error "Unknown option: $1"; return 1 ;;
            *) d="$1"; shift ;;
        esac
    done

    if [[ ! -f "$d/.zzcollab" && ! ( -f "$d/DESCRIPTION" && -f "$d/Makefile" ) ]]; then
        log_error "Not a zzcollab workspace (no .zzcollab marker or DESCRIPTION)."
        return 1
    fi

    _VRF_FAIL=0; _VRF_WARN=0; _VRF_SKIP=0

    local backend mode state_base state_rv
    backend=$(_zzc_detect_backend "$d")
    mode=$(_zzc_state_get install_mode "$d")
    state_base=$(_zzc_state_get base_image "$d")
    state_rv=$(_zzc_state_get r_version "$d")

    echo ""
    echo "VERIFY  $(cd "$d" && pwd)"
    echo ""
    echo "Coherence"

    # 1. Backend not in conflict.
    if [[ "$backend" == "conflict" ]]; then
        _vrf_fail "backend conflict: both renv.lock and a nix file present"
    else
        _vrf_pass "backend unambiguous ($backend)"
    fi

    # 2. State record present.
    if [[ -f "$d/.zzcollab-state" ]]; then
        _vrf_pass "state record present (.zzcollab-state)"
    else
        _vrf_warn "no .zzcollab-state; provenance and read-back unavailable"
    fi

    # 3. install_mode agrees with renv.lock presence.
    if [[ -z "$mode" ]]; then
        _vrf_skip "install mode not recorded; cannot cross-check renv.lock"
    elif [[ "$mode" == "renv" && ! -f "$d/renv.lock" ]]; then
        _vrf_fail "install_mode=renv but renv.lock is missing"
    elif [[ "$mode" == "description" && -f "$d/renv.lock" ]]; then
        _vrf_fail "install_mode=description but renv.lock is present"
    else
        _vrf_pass "install mode ($mode) consistent with renv.lock presence"
    fi

    # 4. Dockerfile install block agrees with renv.lock presence.
    if [[ -f "$d/Dockerfile" ]]; then
        if grep -q '^COPY renv.lock' "$d/Dockerfile" 2>/dev/null; then
            if [[ -f "$d/renv.lock" ]]; then
                _vrf_pass "Dockerfile copies renv.lock and renv.lock exists"
            else
                _vrf_fail "Dockerfile copies renv.lock but renv.lock is missing (dangling)"
            fi
        else
            _vrf_pass "Dockerfile installs from DESCRIPTION (no renv.lock dependency)"
        fi

        # 5. Dockerfile base image matches the remembered base.
        if [[ -n "$state_base" ]]; then
            local base_noTag="${state_base%:*}"
            if grep -q "$base_noTag" "$d/Dockerfile" 2>/dev/null; then
                _vrf_pass "Dockerfile base image matches state ($base_noTag)"
            else
                _vrf_fail "Dockerfile base does not match state base_image ($state_base)"
            fi
        else
            _vrf_skip "no base_image in state; cannot cross-check Dockerfile FROM"
        fi
    else
        _vrf_skip "no Dockerfile; environment not containerised"
    fi

    # 6. renv.lock is well-formed and its R version agrees across sources.
    if [[ -f "$d/renv.lock" ]]; then
        _vrf_renv_lock_valid "$d/renv.lock"
        case $? in
            0) _vrf_pass "renv.lock is valid JSON with a Packages section" ;;
            1) _vrf_fail "renv.lock is malformed or has no Packages section" ;;
            2) _vrf_skip "python3 absent; cannot validate renv.lock JSON" ;;
        esac

        local lock_rv df_rv
        lock_rv=$(_vrf_renv_r_version "$d/renv.lock")
        df_rv=""
        [[ -f "$d/Dockerfile" ]] && df_rv=$(grep -m1 '^ARG R_VERSION=' "$d/Dockerfile" 2>/dev/null | cut -d= -f2)
        local mismatch=""
        [[ -n "$lock_rv" && -n "$state_rv" && "$lock_rv" != "$state_rv" ]] && mismatch="state=$state_rv vs lock=$lock_rv"
        [[ -n "$lock_rv" && -n "$df_rv"    && "$lock_rv" != "$df_rv"    ]] && mismatch="${mismatch:+$mismatch; }Dockerfile=$df_rv vs lock=$lock_rv"
        if [[ -n "$mismatch" ]]; then
            _vrf_fail "R version mismatch: $mismatch"
        elif [[ -n "$lock_rv" ]]; then
            _vrf_pass "R version consistent across sources ($lock_rv)"
        else
            _vrf_skip "could not read R version from renv.lock"
        fi
    fi

    # 6b. Data integrity: the raw data still matches its recorded manifest.
    if [[ -f "$d/data-manifest.sha256" ]]; then
        if ! command -v shasum >/dev/null 2>&1; then
            _vrf_skip "shasum absent; cannot check data-manifest.sha256"
        elif ( cd "$d" && shasum -a 256 --check data-manifest.sha256 ) >/dev/null 2>&1; then
            _vrf_pass "raw data matches data-manifest.sha256"
        else
            _vrf_fail "raw data does not match data-manifest.sha256 (changed/missing files)"
        fi
    fi

    # 7. Dependency triad (Code subset of DESCRIPTION subset of renv.lock).
    # Delegated to zzrenvcheck; reported but not gating (advisory layer).
    if command -v Rscript >/dev/null 2>&1 \
       && Rscript -e "quit(status = !requireNamespace('zzrenvcheck', quietly = TRUE))" >/dev/null 2>&1; then
        if Rscript -e "zzrenvcheck::check_packages(auto_fix = FALSE, strict = TRUE)" >/dev/null 2>&1; then
            _vrf_pass "dependency triad consistent (zzrenvcheck)"
        else
            _vrf_warn "zzrenvcheck reported dependency issues; run 'zzc validate'"
        fi
    else
        _vrf_skip "zzrenvcheck unavailable; run 'make check-renv' in the container"
    fi

    # --- Reproduction tier ---------------------------------------------------
    local reproduced=false
    if [[ "$full" == true ]]; then
        echo ""
        echo "Reproduction (--full)"
        if [[ ! -f "$d/Dockerfile" ]]; then
            _vrf_skip "no Dockerfile; nothing to rebuild (host backend)"
        elif ! command -v docker >/dev/null 2>&1; then
            _vrf_fail "docker not found; cannot rebuild the environment"
        else
            echo "  rebuilding image (this may take several minutes)..."
            if ( cd "$d" && make docker-build ) >/dev/null 2>&1; then
                _vrf_pass "image rebuilt from the pinned definition"
                echo "  running tests inside the image..."
                if ( cd "$d" && make docker-test ) >/dev/null 2>&1; then
                    _vrf_pass "test suite passed inside the rebuilt image"
                    reproduced=true
                else
                    _vrf_fail "tests failed inside the rebuilt image"
                fi
            else
                _vrf_fail "image failed to rebuild"
            fi
        fi
    fi

    # --- Verdict -------------------------------------------------------------
    echo ""
    if [[ "$_VRF_FAIL" -gt 0 ]]; then
        log_error "verify: $_VRF_FAIL failed, $_VRF_WARN warnings, $_VRF_SKIP skipped"
        return 1
    fi

    if [[ "$reproduced" == true ]]; then
        local ts
        ts=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        if _vrf_stamp_verified "$ts"; then
            log_success "verify: reproduced and stamped (level L3, verified $ts)"
        else
            log_success "verify: reproduced (no state record to stamp)"
        fi
    elif [[ "$full" == true ]]; then
        log_success "verify: coherence passed; reproduction skipped (host backend)"
    else
        log_success "verify: coherence passed ($_VRF_WARN warnings, $_VRF_SKIP skipped)"
        echo "  Run 'zzc verify --full' to rebuild and reach L3 (verified)."
    fi
    return 0
}
