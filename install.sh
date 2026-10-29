#!/bin/bash
# =============================================================================
# install.sh — cold start on a brand-new machine (macOS or Omarchy/Arch).
#
# The repo is private, so a bare `git clone` on a fresh box dies with
# "Password authentication is not supported" (GitHub wants a token, nobody has
# one at hand). This script removes that step: it gets `gh`, logs in through
# the browser (device code, no token to create), clones over HTTPS and hands
# off to the platform bootstrap.
#
# Self-contained on purpose — it must run BEFORE the repo exists, so a copy is
# published in the public repo niklasbabel/setup (nothing secret in here). This
# file is the source; after editing it, copy it there too —
# `test/run.sh --with-network` fails while the two differ. Run it as:
#
#   bash -c "$(curl -fsSL https://raw.githubusercontent.com/niklasbabel/setup/main/install.sh)"
#
# (`bash -c`, not `curl | bash`: stdin must stay the terminal so sudo, the
# Homebrew installer and `gh auth login` can ask.)
#
# Env knobs (all optional):
#   CS_DIR=~/computer-setup   where to clone
#   CS_ROLE=agent-box         writes <platform>/.profile before bootstrap
#   CS_NO_BOOTSTRAP=1         stop after the clone
#
# Safe to re-run: every step skips what is already there.
# =============================================================================
set -euo pipefail

REPO="niklasbabel/computer-setup"
DEST="${CS_DIR:-$HOME/computer-setup}"

case "$(uname -s)" in
  Darwin) PLATFORM=mac ;;
  Linux)  PLATFORM=linux ;;
  *) echo "Unsupported OS: $(uname -s)" >&2; exit 1 ;;
esac
echo "==> computer-setup install (${PLATFORM}) → ${DEST}"

# ---- 1. git + gh -------------------------------------------------------------
if [ "$PLATFORM" = mac ]; then
  if ! xcode-select -p >/dev/null 2>&1; then
    echo "==> Installing Xcode Command Line Tools — click \"Install\" in the dialog (it may open behind this window)."
    xcode-select --install || true
    until xcode-select -p >/dev/null 2>&1; do sleep 15; done
  fi
  if ! command -v brew >/dev/null 2>&1 && [ ! -x /opt/homebrew/bin/brew ] && [ ! -x /usr/local/bin/brew ]; then
    echo "==> Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
  command -v gh >/dev/null 2>&1 || brew install gh
else
  if ! command -v pacman >/dev/null 2>&1; then
    echo "Only Arch/Omarchy is supported on Linux (no pacman found)." >&2; exit 1
  fi
  command -v git >/dev/null 2>&1 && command -v gh >/dev/null 2>&1 \
    || sudo pacman -S --needed --noconfirm git github-cli
fi

# ---- 2. GitHub login (browser, no token) -------------------------------------
if ! gh auth status --hostname github.com >/dev/null 2>&1; then
  echo "==> GitHub login: copy the one-time code, then confirm it in the browser."
  gh auth login --hostname github.com --git-protocol https --web
fi
gh auth setup-git --hostname github.com

# ---- 3. Clone (or update) ----------------------------------------------------
if [ -d "$DEST/.git" ]; then
  echo "==> ${DEST} exists — pulling."
  git -C "$DEST" pull --ff-only
else
  gh repo clone "$REPO" "$DEST"
fi

if [ -n "${CS_ROLE:-}" ]; then
  echo "$CS_ROLE" > "$DEST/$PLATFORM/.profile"
  echo "==> Role: ${CS_ROLE} (${DEST}/${PLATFORM}/.profile)"
fi

# ---- 4. Bootstrap ------------------------------------------------------------
if [ -n "${CS_NO_BOOTSTRAP:-}" ]; then
  echo "==> Cloned. Next: cd ${DEST}/${PLATFORM} && ./bootstrap.sh"
  exit 0
fi
cd "$DEST/$PLATFORM"
exec ./bootstrap.sh
