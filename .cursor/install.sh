#!/usr/bin/env bash
# Idempotent bootstrap for the AxmolFighter development environment.
# Prepares: git submodules, Rust toolchain, C++ toolchain + Axmol engine,
# system dependencies, and builds the Rust game server and the C++ Editor.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AX_ROOT="${AX_ROOT:-$HOME/axmol}"
AXMOL_BRANCH="release_custom"
AXMOL_REPO="git@github.com:tkzcfc/axmol.git"

echo "==> AxmolFighter install starting (REPO_ROOT=$REPO_ROOT, AX_ROOT=$AX_ROOT)"

# ---------------------------------------------------------------------------
# 1. Git submodules (Client / Config / Editor / Server / Tools / UI)
# ---------------------------------------------------------------------------
echo "==> Initializing git submodules (best-effort; some submodules are private)"
git -C "$REPO_ROOT" submodule sync --recursive || true
# Initialize each submodule independently so that an inaccessible (private)
# submodule does not block the ones needed to build the server and Editor.
git -C "$REPO_ROOT" config --file "$REPO_ROOT/.gitmodules" --get-regexp 'path$' \
  | while read -r _ sub_path; do
        [ -n "$sub_path" ] || continue
        if ! git -C "$REPO_ROOT" submodule update --init --recursive "$sub_path"; then
            echo "WARN: could not initialize submodule '$sub_path' (private or inaccessible); continuing."
        fi
    done

# ---------------------------------------------------------------------------
# 2. System packages (engine + server toolchain + headless GUI runtime)
# ---------------------------------------------------------------------------
echo "==> Installing system packages"
export DEBIAN_FRONTEND=noninteractive
sudo apt-get update -qq
sudo apt-get install -y --no-install-recommends \
    build-essential binutils g++ automake libtool pkg-config ninja-build \
    libx11-dev libxmu-dev libxi-dev libxxf86vm-dev libglu1-mesa-dev libgl2ps-dev \
    libfontconfig1-dev libgtk-3-dev libwebkit2gtk-4.1-dev libasound2-dev \
    libvlc-dev libvlccore-dev vlc \
    xvfb x11-utils libgl1-mesa-dri mesa-utils \
    postgresql postgresql-contrib

# Use GCC as the default C/C++ compiler (Axmol's documented Linux toolchain).
sudo update-alternatives --install /usr/bin/cc  cc  /usr/bin/gcc 100
sudo update-alternatives --install /usr/bin/c++ c++ /usr/bin/g++ 100
sudo update-alternatives --set cc  /usr/bin/gcc
sudo update-alternatives --set c++ /usr/bin/g++

# ---------------------------------------------------------------------------
# 3. Rust toolchain (server crates use edition 2024 -> needs Rust >= 1.85)
# ---------------------------------------------------------------------------
echo "==> Ensuring Rust stable toolchain"
rustup update stable
rustup default stable
rustc --version

# ---------------------------------------------------------------------------
# 4. Axmol engine (tkzcfc/axmol @ release_custom) + engine setup
# ---------------------------------------------------------------------------
if [ ! -d "$AX_ROOT/.git" ]; then
    echo "==> Cloning Axmol engine ($AXMOL_BRANCH)"
    git clone --branch "$AXMOL_BRANCH" --depth 1 "$AXMOL_REPO" "$AX_ROOT"
else
    echo "==> Updating Axmol engine ($AXMOL_BRANCH)"
    git -C "$AX_ROOT" fetch --depth 1 origin "$AXMOL_BRANCH"
    git -C "$AX_ROOT" checkout "$AXMOL_BRANCH"
    git -C "$AX_ROOT" reset --hard "origin/$AXMOL_BRANCH"
fi

# PowerShell is required by the Axmol build tooling (setup.ps1 / axmol CLI).
if ! command -v pwsh >/dev/null 2>&1; then
    echo "==> Installing PowerShell (via engine helper)"
    bash "$AX_ROOT/1k/pwshi.sh"
fi

# Engine setup: downloads axslcc + pinned cmake and writes AX_ROOT/PATH to
# ~/.profile. Answer "n" to the apt prompt since packages are installed above.
echo "==> Running Axmol engine setup"
export AX_ROOT
printf 'n\n' | pwsh "$AX_ROOT/setup.ps1"

# Make AX_ROOT / axmol CLI available to non-login shells too.
if ! grep -q 'AX_ROOT' "$HOME/.bashrc" 2>/dev/null; then
    {
        echo ''
        echo '# Axmol engine (added by AxmolFighter .cursor/install.sh)'
        echo "export AX_ROOT=\"$AX_ROOT\""
        echo 'export PATH="$AX_ROOT/tools/cmdline:$PATH"'
    } >> "$HOME/.bashrc"
fi
export PATH="$AX_ROOT/tools/cmdline:$PATH"

# ---------------------------------------------------------------------------
# 5. Build the Rust game server (gateway / game / town / battle protocol)
# ---------------------------------------------------------------------------
echo "==> Building Rust game server"
( cd "$REPO_ROOT/AxmolFighter-Server/game" && cargo build )

# ---------------------------------------------------------------------------
# 6. Build the C++ Axmol Editor
#    AX_WITH_VPX=OFF: this engine branch ships no Linux libvpx prebuilt and
#    media support is disabled on Linux, so vpx is not needed.
# ---------------------------------------------------------------------------
echo "==> Building AxmolFighter Editor (linux)"
( cd "$REPO_ROOT/AxmolFighter-Editor" && axmol build -p linux -xc -DAX_WITH_VPX=OFF )

# ---------------------------------------------------------------------------
# 7. Local dev config for the game server (points at the local PostgreSQL)
# ---------------------------------------------------------------------------
DEV_DIR="$HOME/.axmolfighter"
mkdir -p "$DEV_DIR"
sed 's#postgres://postgres:123456@[^/]*/axmol_fighter#postgres://postgres:123456@127.0.0.1:5432/axmol_fighter#' \
    "$REPO_ROOT/AxmolFighter-Server/game/game/game.toml" > "$DEV_DIR/game.dev.toml"

echo "==> AxmolFighter install complete"
