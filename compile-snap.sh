#!/usr/bin/env bash
set -euo pipefail

# compile.sh — install, fix Electron sandbox helper, build snap, optionally clean up.

if [[ ! -f package.json ]]; then
  echo "Error: package.json not found. Run this from the project root." >&2
  exit 1
fi

echo "[0/6] Checking for node & npm…"
command -v node >/dev/null || { echo "Error: node not found." >&2; exit 1; }
command -v npm  >/dev/null || { echo "Error: npm not found."  >&2; exit 1; }

echo "[1/6] Installing dependencies…"
# If package-lock exists, prefer npm ci, otherwise npm install
if [[ -f package-lock.json ]]; then
  npm ci
else
  npm install
fi

echo "[2/6] Ensuring Electron is installed (dev dependency)…"
# If electron isn't installed for any reason, add it using the version pinned in package.json if possible.
if [[ ! -x node_modules/.bin/electron ]]; then
  # Try to read requested version from package.json (devDependencies or dependencies)
  ELECTRON_VER="$(node -p "(() => {
    const p=require('./package.json');
    return (p.devDependencies && p.devDependencies.electron) ||
           (p.dependencies && p.dependencies.electron) || '';
  })()" 2>/dev/null || true)"

  if [[ -n "${ELECTRON_VER}" ]]; then
    echo "  electron not found; installing electron@${ELECTRON_VER}…"
    npm install --save-dev "electron@${ELECTRON_VER}"
  else
    echo "  electron not found; installing latest electron (no version pinned in package.json)…"
    npm install --save-dev electron
  fi
fi

echo "[3/6] Locating chrome-sandbox…"
# chrome-sandbox path varies across electron versions/distros, so search for it.
SANDBOX_PATH="$(find node_modules -type f -path '*/electron/dist/chrome-sandbox' -print -quit 2>/dev/null || true)"

if [[ -z "${SANDBOX_PATH}" ]]; then
  echo "Error: chrome-sandbox not found under node_modules/. Electron may not have installed correctly." >&2
  echo "Try: rm -rf node_modules package-lock.json && npm install" >&2
  exit 1
fi

echo "  Found: ${SANDBOX_PATH}"

echo "[4/6] Fixing Electron chrome-sandbox permissions…"
sudo chown root:root "${SANDBOX_PATH}"
sudo chmod 4755 "${SANDBOX_PATH}"

echo "[5/6] Building snap…"
npm run build-snap

echo "[6/6] Locating snap artifact…"
SNAP_PATH="$(ls -1t dist/*.snap 2>/dev/null | head -n 1 || true)"
if [[ -z "${SNAP_PATH}" ]]; then
  echo "Build finished, but no .snap found in dist/." >&2
  exit 1
fi

echo
echo "Built snap: ${SNAP_PATH}"
echo
echo "Install locally (not via store) with:"
echo "  sudo snap install \"${SNAP_PATH}\" --dangerous"
echo

read -r -p "Install it now? [y/N] " yn
case "${yn:-N}" in
  y|Y|yes|YES) sudo snap install "${SNAP_PATH}" --dangerous ;;
  *) echo "OK — not installing." ;;
esac

echo
read -r -p "Remove build artifacts to save space (node_modules, dist/linux-unpacked, caches)? [y/N] " cn
case "${cn:-N}" in
  y|Y|yes|YES)
    echo "Cleaning up…"
    rm -rf dist/linux-unpacked 2>/dev/null || true
    rm -rf node_modules 2>/dev/null || true
    # Optional: remove electron-builder caches (will force downloads next time)
    rm -rf ~/.cache/electron ~/.cache/electron-builder 2>/dev/null || true
    echo "Done. (Snap remains installed if you chose to install it.)"
    ;;
  *)
    echo "OK — keeping files."
    ;;
esac
