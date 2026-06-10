#!/bin/bash
#
# build-env.sh — enter a minimal, pinned, hermetic shell for building Lex.app.
#
# This script does NOT build anything. It validates the toolchain, ensures a
# project-local pinned Zig is present, then drops you into an interactive
# sub-shell whose environment is forced to a known constant. Inside that shell
# run `zig build app` (or `test`, `run`, `app-unsigned`); type `exit` to return
# to your normal shell unchanged.
#
# Reproducibility claim: same architecture + same macOS build + same Xcode build
# (+ same source commit + the hash-pinned Zig) -> bit-for-bit identical output.
# The sub-shell makes the build depend on nothing outside that set.
#
# Requirements: macOS, Xcode (full, not just Command Line Tools), curl, shasum,
# tar.

set -euo pipefail

# --- Pins -------------------------------------------------------------------
# Zig is hard-pinned: the download is rejected unless its SHA-256 matches.
# 0.16.0 is required: 0.15.2's Mach-O linker cannot link against the Xcode 26.4+
# SDK (arm64e-only libSystem.tbd entries); the fix landed in 0.16.0.
zig_version="0.16.0"
zig_sha256_aarch64="b23d70deaa879b5c2d486ed3316f7eaa53e84acf6fc9cc747de152450d401489"
zig_sha256_x86_64="0387557ed1877bc6a2e1802c8391953baddba76081876301c522f52977b52ba7"

# Reference environment that defines the reproducible baseline. Leave empty to
# skip the check; set to the exact build numbers to get a warning on drift.
# (Apple's toolchain cannot be hash-pinned, so this is warn-and-continue only.)
ref_macos_build=""
ref_xcode_build=""

# --- Helpers ----------------------------------------------------------------

# Print an error to stderr and exit.
# Parameters:
#   $1: message.
die() {
  echo "build-env: error: ${1}" >&2
  exit 1
}

# Download a file from URL and verify downloaded file with SHA-256.
# If the file existed, verify it with SHA-256. If the hash does not match, try
# to download the file from given URL.
# Parameters:
#   $1: SHA256 hash.
#   $2: URL.
#   $3: Output path.
download() {
  local hash="${1}"
  local url="${2}"
  local output="${3}"
  local sha256="${hash}  ${output}"
  if ! echo -n "${sha256}" | shasum -a 256 -s -c; then
    echo "build-env: downloading ${url}"
    curl -fL "${url}" -o "${output}"
    echo -n "${sha256}" | shasum -a 256 -s -c
  fi
}

# --- Resolve project root ---------------------------------------------------
# Work relative to the repo root regardless of the caller's cwd.
script_dir="$(cd "$(dirname "${0}")" && pwd)"
project_root="$(cd "${script_dir}/.." && pwd)"
cache_dir="${project_root}/.cache"

# --- Re-entry guard ---------------------------------------------------------
if [ "${LEX_BUILD_ENV:-}" = "1" ]; then
  die "already inside the Lex build environment; type 'exit' first"
fi

# --- Pre-flight checks ------------------------------------------------------
[ "$(uname -s)" = "Darwin" ] || die "Lex.app can only be built on macOS"

for cmd in curl shasum tar uname xcode-select sw_vers; do
  command -v "${cmd}" >/dev/null 2>&1 || die "required command not found: ${cmd}"
done

# Detect architecture and map it to Zig's platform naming.
host_arch="$(uname -m)"
case "${host_arch}" in
  arm64) zig_platform="aarch64-macos"; zig_sha256="${zig_sha256_aarch64}" ;;
  x86_64) zig_platform="x86_64-macos"; zig_sha256="${zig_sha256_x86_64}" ;;
  *) die "unsupported architecture: ${host_arch}" ;;
esac

# Resolve the Apple toolchain. Honor an explicit DEVELOPER_DIR, else fall back
# to the active xcode-select path. Reject Command Line Tools: a full Xcode is
# required (swiftc, the macOS SDK).
developer_dir="${DEVELOPER_DIR:-$(xcode-select -p 2>/dev/null || true)}"
[ -n "${developer_dir}" ] || die "no Xcode found; install Xcode and run xcode-select"
case "${developer_dir}" in
  *CommandLineTools*) die "DEVELOPER_DIR points to Command Line Tools; a full Xcode is required" ;;
esac
[ -x "${developer_dir}/usr/bin/xcodebuild" ] || \
  die "xcodebuild not found under ${developer_dir}; a full Xcode is required"
# Resolve the real swiftc via xcrun (works regardless of toolchain layout).
# /usr/bin/swiftc is only a stub that defers to xcrun; the real binary lives in
# the active toolchain. Derive the toolchain bin dir from it for the PATH.
swiftc_path="$(DEVELOPER_DIR="${developer_dir}" xcrun -f swiftc 2>/dev/null || true)"
[ -n "${swiftc_path}" ] && [ -x "${swiftc_path}" ] || \
  die "swiftc could not be resolved via xcrun under ${developer_dir}; a full Xcode is required"
toolchain_bin="$(dirname "${swiftc_path}")"

# Resolve the macOS SDK path. swiftc/clang honor SDKROOT, so pinning it makes
# the Apple link step use a fixed SDK (reproducibility). Zig itself ignores
# SDKROOT and locates the SDK via xcrun on its own, but pinning is harmless.
sdk_path="$(DEVELOPER_DIR="${developer_dir}" xcrun --sdk macosx --show-sdk-path 2>/dev/null || true)"
[ -n "${sdk_path}" ] && [ -d "${sdk_path}" ] || \
  die "macOS SDK could not be resolved via xcrun under ${developer_dir}; a full Xcode is required"

# Warn (do not fail) when the host drifts from the pinned reference build.
if [ -n "${ref_macos_build}" ]; then
  host_macos_build="$(sw_vers -buildVersion)"
  if [ "${host_macos_build}" != "${ref_macos_build}" ]; then
    echo "build-env: WARNING: macOS build ${host_macos_build} != reference ${ref_macos_build}" >&2
  fi
fi
if [ -n "${ref_xcode_build}" ]; then
  host_xcode_build="$("${developer_dir}/usr/bin/xcodebuild" -version 2>/dev/null | tail -n1 | awk '{print $NF}')"
  if [ "${host_xcode_build}" != "${ref_xcode_build}" ]; then
    echo "build-env: WARNING: Xcode build ${host_xcode_build} != reference ${ref_xcode_build}" >&2
  fi
fi

# --- Ensure pinned Zig ------------------------------------------------------
zig_dir="${cache_dir}/zig-${zig_version}"
zig_bin="${zig_dir}/zig"
if [ ! -x "${zig_bin}" ]; then
  mkdir -p "${cache_dir}"
  zig_url="https://ziglang.org/download/${zig_version}/zig-${zig_platform}-${zig_version}.tar.xz"
  zig_tarball="${cache_dir}/zig-${zig_platform}-${zig_version}.tar.xz"
  download "${zig_sha256}" "${zig_url}" "${zig_tarball}"
  echo "build-env: extracting Zig ${zig_version}"
  tar -xf "${zig_tarball}" -C "${cache_dir}"
  rm -rf "${zig_dir}"
  mv "${cache_dir}/zig-${zig_platform}-${zig_version}" "${zig_dir}"
fi
[ -x "${zig_bin}" ] || die "Zig binary missing after install: ${zig_bin}"

# --- Build the hermetic environment -----------------------------------------
# Curated PATH: pinned Zig first, then the pinned Xcode toolchain, then the
# system bins (codesign, ar, mkdir, rm, open all live in /usr/bin).
hermetic_path="${zig_dir}:${toolchain_bin}:${developer_dir}/usr/bin:/usr/bin:/bin"

# Project-local, disposable caches so user-global state never leaks in.
tmp_dir="${cache_dir}/tmp"
zig_global_cache="${cache_dir}/zig-global"
mkdir -p "${tmp_dir}" "${zig_global_cache}"

# An rcfile replaces ~/.bashrc for the interactive sub-shell: it prints the
# environment report and sets the prompt, without sourcing user dotfiles.
rcfile="${cache_dir}/build-env.rc"
cat > "${rcfile}" <<'RC'
umask 022
cd "${LEX_PROJECT_ROOT}"

_lex_show() {
  local label="${1}"; shift
  local value
  value="$("$@" 2>/dev/null)" || value="n/a"
  printf '  %-13s %s\n' "${label}" "${value:-n/a}"
}

echo "============================================================"
echo " Lex build environment"
echo "============================================================"
_lex_show "Architecture" uname -m
_lex_show "macOS" sw_vers -productVersion
_lex_show "macOS build" sw_vers -buildVersion
_lex_show "Xcode" sh -c 'xcodebuild -version | head -n1'
_lex_show "Xcode build" sh -c 'xcodebuild -version | tail -n1 | awk "{print \$NF}"'
_lex_show "swiftc" sh -c 'swiftc --version | head -n1'
_lex_show "ld64" sh -c 'ld -v 2>&1 | head -n1'
_lex_show "SDK" xcrun --show-sdk-version
_lex_show "SDK build" xcrun --show-sdk-build-version
_lex_show "Zig" zig version
echo "------------------------------------------------------------"
echo " Determinism: LC_ALL=${LC_ALL} TZ=${TZ} ZERO_AR_DATE=${ZERO_AR_DATE} umask=$(umask)"
echo " DEVELOPER_DIR=${DEVELOPER_DIR}"
echo " SDKROOT=${SDKROOT}"
echo "------------------------------------------------------------"
echo " Resolved commands:"
for c in zig swiftc codesign ar libtool; do
  printf '  %-13s %s\n' "${c}" "$(command -v "${c}" 2>/dev/null || echo n/a)"
done
echo "------------------------------------------------------------"
echo " Run: zig build app   (test | run | app-unsigned)"
echo " Type 'exit' to leave the build environment."
echo "============================================================"

PS1='(lex-build) \w \$ '
RC

echo "build-env: entering hermetic shell (Zig ${zig_version}, ${host_arch})"

# Replace this process with a scrubbed interactive bash. `env -i` drops every
# inherited variable; only the allowlist below survives, so the build depends on
# nothing outside the pinned set.
exec /usr/bin/env -i \
  HOME="${HOME}" \
  USER="${USER}" \
  TERM="${TERM:-xterm-256color}" \
  PATH="${hermetic_path}" \
  DEVELOPER_DIR="${developer_dir}" \
  SDKROOT="${sdk_path}" \
  LC_ALL=C \
  LANG=C \
  TZ=UTC \
  ZERO_AR_DATE=1 \
  TMPDIR="${tmp_dir}" \
  ZIG_GLOBAL_CACHE_DIR="${zig_global_cache}" \
  ZIG_LOCAL_CACHE_DIR="${project_root}/.zig-cache" \
  CLANG_MODULE_CACHE_PATH="${cache_dir}/clang-module-cache" \
  LEX_BUILD_ENV=1 \
  LEX_PROJECT_ROOT="${project_root}" \
  /bin/bash --rcfile "${rcfile}" -i
