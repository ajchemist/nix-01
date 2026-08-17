#!/usr/bin/env bash
#
# nix-01 bootstrap — one command from a fresh macOS/Linux machine to a
# fully configured system.
#
#   curl -fsSL https://raw.githubusercontent.com/ajchemist/nix-01/main/bootstrap.sh | bash
#
# From a local checkout, just:  ./bootstrap.sh   (the sibling flake.nix is
# auto-detected and used instead of GitHub).
#
# Shows the module plan (what is installed / missing / about to change) and
# asks for confirmation before touching the system.
set -eo pipefail

DEFAULT_FLAKE="github:ajchemist/nix-01"
KARABINER_RULE_DESC="Make left modifiers(control, option, command) key work in Korean mode"

# --- CLI ---------------------------------------------------------------------

usage() {
  cat <<'EOF'
Usage: bootstrap.sh [OPTIONS]

One-command system bootstrap: Nix + nix-darwin/home-manager + base config.

Options:
  -n, --dry-run      Show the module plan and exit without changing anything
  -y, --yes          Apply without asking for confirmation
      --flake REF    Flake source (default: github:ajchemist/nix-01, or the
                     local checkout when run next to a flake.nix)
  -h, --help         Show this help
EOF
}

DRY_RUN=0
ASSUME_YES=0
FLAKE=""
while [ $# -gt 0 ]; do
  case "$1" in
    -n|--dry-run) DRY_RUN=1 ;;
    -y|--yes)     ASSUME_YES=1 ;;
    --flake)      FLAKE="$2"; shift ;;
    -h|--help)    usage; exit 0 ;;
    *) echo "unknown option: $1" >&2; usage >&2; exit 1 ;;
  esac
  shift
done

# Local checkout auto-detection: running ./bootstrap.sh next to flake.nix
# uses that flake; curl | bash falls back to the GitHub ref.
if [ -z "$FLAKE" ]; then
  script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-/}")" 2>/dev/null && pwd || true)"
  if [ -n "$script_dir" ] && [ -f "$script_dir/flake.nix" ]; then
    FLAKE="$script_dir"
  else
    FLAKE="$DEFAULT_FLAKE"
  fi
fi

OS="$(uname -s)"
ARCH="$(uname -m)"

# --- Presentation ------------------------------------------------------------

if [ -t 1 ]; then
  B=$'\033[1m'; DIM=$'\033[2m'; GRN=$'\033[32m'; YLW=$'\033[33m'; CYN=$'\033[36m'; R=$'\033[0m'
else
  B=""; DIM=""; GRN=""; YLW=""; CYN=""; R=""
fi

say()  { printf '%s\n' "$*"; }
step() { printf '%s==>%s %s\n' "${CYN}${B}" "$R" "$*"; }

# --- Module registry ---------------------------------------------------------
#
# A module is: name, description, a st_<name> function answering
# "ok" | "missing", and an action label shown in the plan. Adding a module to
# the bootstrap = one register line + one status function; modules whose
# action is "via nix-darwin switch" are actually converged by the flake.

MOD_NAMES=()
MOD_DESCS=()
MOD_ACTIONS=()

register() { # name  description  action-when-missing
  MOD_NAMES+=("$1"); MOD_DESCS+=("$2"); MOD_ACTIONS+=("$3")
}

st_nix()       { command -v nix >/dev/null 2>&1 && echo ok || echo missing; }
st_homebrew()  { command -v brew >/dev/null 2>&1 && echo ok || echo missing; }
st_darwin()    { [ -x /run/current-system/sw/bin/darwin-rebuild ] && echo ok || echo missing; }
st_karabiner() { [ -d /Applications/Karabiner-Elements.app ] && echo ok || echo missing; }
st_kbrule()    {
  grep -qF "$KARABINER_RULE_DESC" "$HOME/.config/karabiner/karabiner.json" 2>/dev/null \
    && echo ok || echo missing
}
st_hm()        { command -v home-manager >/dev/null 2>&1 && echo ok || echo missing; }

case "$OS" in
  Darwin)
    register nix            "Nix package manager"                        "install (Determinate Systems)"
    register homebrew       "Homebrew package manager"                   "install"
    register nix-darwin     "system config (darwinConfigurations.default)" "darwin-rebuild switch"
    register karabiner      "Karabiner-Elements (homebrew cask)"         "via nix-darwin switch"
    register karabiner-rule "Korean-mode left modifiers -> karabiner.json" "via nix-darwin switch"
    ;;
  Linux)
    register nix            "Nix package manager"                        "install (Determinate Systems)"
    register home-manager   "user config (homeConfigurations)"           "home-manager switch"
    ;;
  *) echo "Unsupported OS: $OS" >&2; exit 1 ;;
esac

status_of() {
  case "$1" in
    nix)            st_nix ;;
    homebrew)       st_homebrew ;;
    nix-darwin)     st_darwin ;;
    karabiner)      st_karabiner ;;
    karabiner-rule) st_kbrule ;;
    home-manager)   st_hm ;;
  esac
}

print_plan() {
  say ""
  say "${B}nix-01 bootstrap${R} ${DIM}· $OS ($ARCH) · flake: $FLAKE${R}"
  say ""
  local i name st mark action
  for i in "${!MOD_NAMES[@]}"; do
    name="${MOD_NAMES[$i]}"
    st="$(status_of "$name")"
    if [ "$st" = ok ]; then
      mark="${GRN}✓${R}"; action="${DIM}up to date${R}"
      case "${MOD_ACTIONS[$i]}" in
        *switch*) action="${DIM}converge on switch${R}" ;;
      esac
    else
      mark="${YLW}•${R}"; action="${YLW}${MOD_ACTIONS[$i]}${R}"
    fi
    printf '  [%s] %-15s %-46s %s\n' "$mark" "$name" "${MOD_DESCS[$i]}" "$action"
  done
  say ""
}

confirm() {
  [ "$ASSUME_YES" = 1 ] && return 0
  if [ -r /dev/tty ]; then
    printf '%s' "${B}Proceed? [y/N] ${R}" > /dev/tty
    local ans; read -r ans < /dev/tty || ans=""
    case "$ans" in y|Y|yes|YES) return 0 ;; *) return 1 ;; esac
  fi
  say "No terminal available for confirmation; re-run with --yes to apply." >&2
  return 1
}

# --- Apply -------------------------------------------------------------------

apply_nix() {
  step "Installing Nix (Determinate Systems installer, requires sudo)"
  curl -fsSL https://install.determinate.systems/nix | sh -s -- install --no-confirm
  # shellcheck disable=SC1091
  if [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
  fi
}

apply_homebrew() {
  step "Installing Homebrew"
  NONINTERACTIVE=1 /bin/bash -c \
    "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
}

apply_darwin() {
  # nix-darwin refuses to activate while these pre-existing files are in the
  # way; move them aside once (nix-darwin replaces them with symlinks).
  local f
  for f in /etc/bashrc /etc/zshrc /etc/zshenv; do
    if [ -f "$f" ] && [ ! -L "$f" ]; then
      step "Moving $f -> $f.before-nix-darwin"
      sudo mv "$f" "$f.before-nix-darwin"
    fi
  done

  step "darwin-rebuild switch --flake $FLAKE#default"
  local nix; nix="$(command -v nix)"
  sudo -H "$nix" --extra-experimental-features "nix-command flakes" run \
    github:nix-darwin/nix-darwin/master#darwin-rebuild -- \
    switch --flake "$FLAKE#default"
}

apply_hm() {
  step "home-manager switch --flake $FLAKE#$USER-linux"
  local nix; nix="$(command -v nix)"
  "$nix" --extra-experimental-features "nix-command flakes" run \
    github:nix-community/home-manager -- \
    switch -b backup --flake "$FLAKE#$USER-linux"
}

# --- Main --------------------------------------------------------------------

print_plan

if [ "$DRY_RUN" = 1 ]; then
  say "${DIM}(dry run — nothing was changed)${R}"
  exit 0
fi

confirm || exit 1
say ""

[ "$(st_nix)" = ok ] || apply_nix
case "$OS" in
  Darwin)
    [ "$(st_homebrew)" = ok ] || apply_homebrew
    apply_darwin
    ;;
  Linux)
    apply_hm
    ;;
esac

say ""
step "Result"
print_plan
say "${GRN}${B}Done.${R}"
