#!/usr/bin/env bash
# Per-boot service reconciliation for the AxmolFighter environment.
# Brings up PostgreSQL (with the game database) and a headless X display
# (Xvfb) so the GUI Editor can run. Idempotent and safe to re-run.
set -euo pipefail

PG_VERSION="$(ls /usr/lib/postgresql 2>/dev/null | sort -V | tail -1)"

echo "==> Starting PostgreSQL ${PG_VERSION}"
sudo pg_ctlcluster "$PG_VERSION" main start 2>/dev/null || true

# Wait for PostgreSQL to accept connections.
for _ in $(seq 1 30); do
    if sudo -u postgres pg_isready -q; then break; fi
    sleep 1
done

echo "==> Ensuring game database and credentials"
sudo -u postgres psql -tAc "ALTER USER postgres WITH PASSWORD '123456';" >/dev/null
if ! sudo -u postgres psql -tAc "SELECT 1 FROM pg_database WHERE datname='axmol_fighter'" | grep -q 1; then
    sudo -u postgres createdb axmol_fighter
fi

# Headless X server for the GUI Editor (software OpenGL via llvmpipe).
if ! xdpyinfo -display :99 >/dev/null 2>&1; then
    echo "==> Starting Xvfb on :99"
    Xvfb :99 -screen 0 1280x800x24 +extension GLX >/tmp/xvfb.log 2>&1 &
fi

echo "==> AxmolFighter services ready (PostgreSQL up, DISPLAY=:99)"
