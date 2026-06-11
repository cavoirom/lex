#!/bin/bash
#
# build-env.sh — run a command, or open a shell, in a pinned hermetic build
# environment for Lex.app.
#
# Usage:
#   build-env.sh                # interactive sub-shell
#   build-env.sh zig build app  # run a command in the environment, then exit
#
# Either way the environment is forced to a known constant so the build depends
# on nothing outside the pinned set. Reproducibility: same arch + macOS build +
# Xcode build + source commit + pinned Zig -> bit-for-bit identical output.
#
# Requires: macOS, full Xcode (not just Command Line Tools), curl, shasum, tar.

set -euo pipefail

# --- Pins -------------------------------------------------------------------
# Zig download is rejected unless its SHA-256 matches. 0.16.0 is required:
# 0.15.2's Mach-O linker cannot link against the Xcode 26.4+ SDK (arm64e-only
# libSystem.tbd); fixed in 0.16.0.
zig_version="0.16.0"
zig_sha256_aarch64="b23d70deaa879b5c2d486ed3316f7eaa53e84acf6fc9cc747de152450d401489"
zig_sha256_x86_64="0387557ed1877bc6a2e1802c8391953baddba76081876301c522f52977b52ba7"

# Reproducible baseline. Empty = skip; set to exact build numbers to warn on
# drift. Apple's toolchain cannot be hash-pinned, so this is warn-only.
ref_macos_build=""
ref_xcode_build=""

# --- Helpers ----------------------------------------------------------------

# Print an error to stderr and exit. $1: message.
die() {
  echo "build-env: error: ${1}" >&2
  exit 1
}

# Ensure $3 exists with SHA-256 $1, downloading from $2 if missing or stale.
download() {
  local hash="${1}" url="${2}" output="${3}"
  local sha256="${hash}  ${output}"
  if ! echo -n "${sha256}" | shasum -a 256 -s -c; then
    echo "build-env: downloading ${url}" >&2
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
  die "already inside the Lex build environment"
fi

# --- Pre-flight checks ------------------------------------------------------
[ "$(uname -s)" = "Darwin" ] || die "Lex.app can only be built on macOS"

for cmd in curl shasum tar uname xcode-select sw_vers; do
  command -v "${cmd}" >/dev/null 2>&1 || die "required command not found: ${cmd}"
done

# Map host architecture to Zig's platform naming.
host_arch="$(uname -m)"
case "${host_arch}" in
  arm64) zig_platform="aarch64-macos"; zig_sha256="${zig_sha256_aarch64}" ;;
  x86_64) zig_platform="x86_64-macos"; zig_sha256="${zig_sha256_x86_64}" ;;
  *) die "unsupported architecture: ${host_arch}" ;;
esac

# Resolve the Apple toolchain: honor DEVELOPER_DIR, else the xcode-select path.
# Reject Command Line Tools; a full Xcode (swiftc, macOS SDK) is required.
developer_dir="${DEVELOPER_DIR:-$(xcode-select -p 2>/dev/null || true)}"
[ -n "${developer_dir}" ] || die "no Xcode found; install Xcode and run xcode-select"
case "${developer_dir}" in
  *CommandLineTools*) die "DEVELOPER_DIR points to Command Line Tools; a full Xcode is required" ;;
esac
[ -x "${developer_dir}/usr/bin/xcodebuild" ] || \
  die "xcodebuild not found under ${developer_dir}; a full Xcode is required"

# /usr/bin/swiftc is only a stub that defers to xcrun; resolve the real binary
# via xcrun and derive the toolchain bin dir from it for the PATH.
swiftc_path="$(DEVELOPER_DIR="${developer_dir}" xcrun -f swiftc 2>/dev/null || true)"
[ -n "${swiftc_path}" ] && [ -x "${swiftc_path}" ] || \
  die "swiftc could not be resolved via xcrun under ${developer_dir}"
toolchain_bin="$(dirname "${swiftc_path}")"

# Pin SDKROOT so the Apple link step uses a fixed SDK. Zig ignores SDKROOT and
# locates the SDK via xcrun itself, but pinning is harmless.
sdk_path="$(DEVELOPER_DIR="${developer_dir}" xcrun --sdk macosx --show-sdk-path 2>/dev/null || true)"
[ -n "${sdk_path}" ] && [ -d "${sdk_path}" ] || \
  die "macOS SDK could not be resolved via xcrun under ${developer_dir}"

# Warn (do not fail) when the host drifts from the pinned reference build.
if [ -n "${ref_macos_build}" ]; then
  host_macos_build="$(sw_vers -buildVersion)"
  [ "${host_macos_build}" = "${ref_macos_build}" ] || \
    echo "build-env: warning: macOS build ${host_macos_build} != reference ${ref_macos_build}" >&2
fi
if [ -n "${ref_xcode_build}" ]; then
  host_xcode_build="$("${developer_dir}/usr/bin/xcodebuild" -version 2>/dev/null | tail -n1 | awk '{print $NF}')"
  [ "${host_xcode_build}" = "${ref_xcode_build}" ] || \
    echo "build-env: warning: Xcode build ${host_xcode_build} != reference ${ref_xcode_build}" >&2
fi

# --- Ensure pinned Zig ------------------------------------------------------
zig_dir="${cache_dir}/zig-${zig_version}"
zig_bin="${zig_dir}/zig"
if [ ! -x "${zig_bin}" ]; then
  mkdir -p "${cache_dir}"
  zig_url="https://ziglang.org/download/${zig_version}/zig-${zig_platform}-${zig_version}.tar.xz"
  zig_tarball="${cache_dir}/zig-${zig_platform}-${zig_version}.tar.xz"
  download "${zig_sha256}" "${zig_url}" "${zig_tarball}"
  echo "build-env: extracting Zig ${zig_version}" >&2
  tar -xf "${zig_tarball}" -C "${cache_dir}"
  rm -rf "${zig_dir}"
  mv "${cache_dir}/zig-${zig_platform}-${zig_version}" "${zig_dir}"
fi
[ -x "${zig_bin}" ] || die "Zig binary missing after install: ${zig_bin}"

# --- Build the hermetic environment -----------------------------------------
# Curated PATH: pinned Zig, then the pinned Xcode toolchain, then system bins
# (codesign, ar, mkdir, rm, open all live in /usr/bin).
hermetic_path="${zig_dir}:${toolchain_bin}:${developer_dir}/usr/bin:/usr/bin:/bin"

# Project-local, disposable caches so user-global state never leaks in.
tmp_dir="${cache_dir}/tmp"
zig_global_cache="${cache_dir}/zig-global"
mkdir -p "${tmp_dir}" "${zig_global_cache}"

# Environment report, run inside the hermetic shell by both modes (via eval of
# LEX_REPORT) so the versions reflect what the build actually sees.
#
# It is carried as text in an env var, not a shell function: each mode execs a
# fresh bash after `env -i`, and nothing in this outer process survives that
# exec. `env -i` even strips exported functions (BASH_FUNC_* vars), so the only
# thing both children reliably receive is the allowlisted environment. `eval
# "${LEX_REPORT}"` is the shared call site; the body stays defined exactly once.
report_script="$(cat <<'REPORT'
_lex_show() {
  local label="${1}"; shift
  local value
  value="$("$@" 2>/dev/null)" || value="n/a"
  printf '%-12s %s\n' "${label}" "${value:-n/a}"
}

echo "lex build environment"
_lex_show "arch"   uname -m
_lex_show "macos"  sw_vers -productVersion
_lex_show "build"  sw_vers -buildVersion
_lex_show "xcode"  sh -c 'xcodebuild -version | head -n1'
_lex_show "swiftc" sh -c 'swiftc --version | head -n1'
_lex_show "ld64"   sh -c 'ld -v 2>&1 | head -n1'
_lex_show "sdk"    xcrun --show-sdk-build-version
_lex_show "zig"    zig version
echo "determinism: LC_ALL=${LC_ALL} TZ=${TZ} ZERO_AR_DATE=${ZERO_AR_DATE} umask=$(umask)"
REPORT
)"

# Replace this process with a scrubbed program. `env -i` drops every inherited
# variable; only the allowlist below survives, so the build depends on nothing
# outside the pinned set. $@ is the program (bash for the interactive case).
run_in_env() {
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
    LEX_REPORT="${report_script}" \
    "$@"
}

# Runner mode: print the report, then run the given command from the project
# root and exit with its status.
if [ "$#" -gt 0 ]; then
  run_in_env /bin/bash -c \
    'umask 022; cd "${LEX_PROJECT_ROOT}" || exit 1; eval "${LEX_REPORT}"; exec "$@"' \
    bash "$@"
fi

# Shell mode: an rcfile replaces ~/.bashrc for the interactive sub-shell; it
# prints the environment report and sets the prompt without sourcing dotfiles.
rcfile="${cache_dir}/build-env.rc"
cat > "${rcfile}" <<'RC'
umask 022
cd "${LEX_PROJECT_ROOT}"
eval "${LEX_REPORT}"
echo "run: zig build app   (test | run | app-unsigned); exit to leave"
PS1='(lex-build) \w \$ '
RC

run_in_env /bin/bash --rcfile "${rcfile}" -i
