#!/usr/bin/env bash
set -euo pipefail

# AI Skills installer — copies skills into the correct directory for the
# detected AI agent tool (Claude Code, opencode, Cursor, etc).

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
SKILLS_DIR="${ROOT_DIR}/skills"

# --- defaults -------------------------------------------------------------
MODE="all"
SKILLS=""
TARGET=""

# --- parse args ------------------------------------------------------------
usage() {
  cat <<'EOF'
Usage: install.sh [options]

Options:
  --all                Install all skills (default)
  --skills "a b c"     Install only the listed skills
  --target <dir>       Override the target skills directory
  -h, --help           Show this help
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all) MODE="all"; shift ;;
    --skills) MODE="some"; SKILLS="$2"; shift 2 ;;
    --target) TARGET="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1 ;;
  esac
done

# --- detect target directory ------------------------------------------------
detect_target() {
  # Prefer explicit target.
  if [[ -n "$TARGET" ]]; then
    echo "$TARGET"
    return 0
  fi

  # Detect based on environment variables / tool presence.
  if [[ -n "${CLAUDE_SKILLS_DIR:-}" ]]; then
    echo "$CLAUDE_SKILLS_DIR"; return 0
  fi
  if [[ -n "${OPENCODE_SKILLS_DIR:-}" ]]; then
    echo "$OPENCODE_SKILLS_DIR"; return 0
  fi

  # Default to Claude Code's skills directory; note in output.
  echo "${HOME}/.claude/skills"
}

TARGET="$(detect_target)"
mkdir -p "$TARGET"

# --- select skills ----------------------------------------------------------
mapfile -t AVAILABLE < <(find "$SKILLS_DIR" -mindepth 1 -maxdepth 1 -type d -exec basename {} \;)

if [[ "$MODE" == "some" ]]; then
  TO_INSTALL=()
  for s in $SKILLS; do
    if [[ -d "$SKILLS_DIR/$s" ]]; then
      TO_INSTALL+=("$s")
    else
      echo "Warning: skill '$s' not found in $SKILLS_DIR, skipping." >&2
    fi
  done
  if [[ ${#TO_INSTALL[@]} -eq 0 ]]; then
    echo "No valid skills selected. Aborting." >&2
    exit 1
  fi
else
  TO_INSTALL=("${AVAILABLE[@]}")
fi

# --- install -----------------------------------------------------------------
echo "Installing ${#TO_INSTALL[@]} skill(s) into: $TARGET"
for s in "${TO_INSTALL[@]}"; do
  cp -R "$SKILLS_DIR/$s" "$TARGET/"
  echo "  ✓ $s"
done

echo ""
echo "Done. Restart your agent session, then try a matching prompt."
