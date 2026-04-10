#!/bin/sh
#
# docker-build.sh
#
# One-command wrapper that runs the full PureDarwin build pipeline inside
# the Docker container defined by the repo's Dockerfile.
#
# Requires Docker with BuildKit support (Docker Desktop ≥ 20.10 on Windows/Mac,
# or Docker Engine ≥ 20.10 on Linux / WSL2).
#
# Usage:
#   ./docker-build.sh                          # full pipeline
#   ./docker-build.sh libelf libdwarf          # build specific projects only
#   ./docker-build.sh --assemble-only          # skip build, assemble image only
#   ./docker-build.sh --build-only             # compile only, no image assembly
#
# Output: puredarwin.vmwarevm (and/or puredarwin.iso, puredarwin.vmdk)
#         in the current directory (bind-mounted from the container).
#
# On Windows (PowerShell / cmd):
#   docker-build.sh must be called from Git Bash, WSL, or via:
#     docker run ... (see the Dockerfile for details)
#
# ─────────────────────────────────────────────────────────────────────────────

set -e

REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
IMAGE_NAME="puredarwin-builder"
CONTAINER_NAME="puredarwin-build-$$"

ASSEMBLE_ONLY=0
BUILD_ONLY=0
BUILD_ARGS=""

for _arg in "$@"; do
    case "$_arg" in
        --assemble-only) ASSEMBLE_ONLY=1 ;;
        --build-only)    BUILD_ONLY=1 ;;
        *)               BUILD_ARGS="$BUILD_ARGS $_arg" ;;
    esac
done

echo "==> PureDarwin full build pipeline (Docker)"
echo "    Repo : $REPO_ROOT"
echo "    Image: $IMAGE_NAME"
echo ""

# ─────────────────────────────────────────────────────────────────────────────
# 1. Build the Docker image (skipped if it already exists and sources have
#    not changed; Docker layer caching handles this automatically).
# ─────────────────────────────────────────────────────────────────────────────
if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
    echo "--- Building Docker image (first run; ~10-30 min for cctools-port) ---"
    docker build --progress=plain -t "$IMAGE_NAME" "$REPO_ROOT"
else
    echo "--- Docker image '$IMAGE_NAME' already exists (use 'docker build' to rebuild) ---"
fi

echo ""

# ─────────────────────────────────────────────────────────────────────────────
# 2. Run the appropriate pipeline step(s).
# ─────────────────────────────────────────────────────────────────────────────
run_in_docker() {
    _cmd="$1"
    docker run \
        --rm \
        --name "$CONTAINER_NAME" \
        -v "$REPO_ROOT:/repo" \
        "$IMAGE_NAME" \
        sh -c "$_cmd"
}

if [ "$ASSEMBLE_ONLY" = "1" ]; then
    echo "--- Assembling disk image only ---"
    run_in_docker \
        "cd /repo && sudo ./setup/pd_setup_linux puredarwin.vmwarevm PureDarwin <<< 'y
y
y'"
elif [ "$BUILD_ONLY" = "1" ]; then
    echo "--- Compiling Darwin sources only ---"
    run_in_docker \
        "cd /repo && ./setup/pd_build_linux$BUILD_ARGS"
else
    echo "--- Full pipeline: compile + assemble ---"
    run_in_docker \
        "cd /repo \
         && ./setup/pd_build_linux$BUILD_ARGS \
         && echo '' \
         && echo 'Assembling disk image...' \
         && printf 'y\ny\ny\n' | sudo ./setup/pd_setup_linux puredarwin.vmwarevm PureDarwin"
fi

echo ""
echo "==> docker-build.sh complete."
if [ "$BUILD_ONLY" != "1" ]; then
    echo "    Output: $REPO_ROOT/puredarwin.vmwarevm"
    echo "            Open with VMware Workstation / Fusion to boot PureDarwin."
fi
