#!/usr/bin/env bash
# ==============================================================================
# herdr-autoname: Uninstaller
# ==============================================================================

set -euo pipefail

HERDR_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/herdr"
SCRIPTS_DIR="$HERDR_CONFIG_DIR/scripts"
ZSHRC_FILE="$HOME/.zshrc"

COLOR_GREEN="\033[0;32m"
COLOR_BLUE="\033[0;34m"
COLOR_RESET="\033[0m"

echo -e "${COLOR_BLUE}==>${COLOR_RESET} Uninstalling herdr-autoname..."

# 1. Stop running daemon
pkill -f "herdr-autoname-daemon.py" >/dev/null 2>&1 || true

# 2. Remove linked scripts
rm -f "$SCRIPTS_DIR/herdr-autoname-daemon.py"
rm -f "$SCRIPTS_DIR/herdr-autoname.zsh"
if [[ -d "$SCRIPTS_DIR" ]] && [[ -z "$(ls -A "$SCRIPTS_DIR")" ]]; then
  rmdir "$SCRIPTS_DIR" 2>/dev/null || true
fi

# 3. Clean ~/.zshrc
if [[ -f "$ZSHRC_FILE" ]]; then
  if grep -q "herdr-autoname" "$ZSHRC_FILE"; then
    python3 - << 'EOF'
import os
import re

zshrc_path = os.path.expanduser("~/.zshrc")
if os.path.exists(zshrc_path):
    with open(zshrc_path, "r", encoding="utf-8") as f:
        content = f.read()
    
    # Remove herdr-autoname block
    pattern = r'\n*# >>> herdr-autoname >>>.*?# <<< herdr-autoname <<<\n*'
    new_content = re.sub(pattern, '\n', content, flags=re.DOTALL)
    
    with open(zshrc_path, "w", encoding="utf-8") as f:
        f.write(new_content)
EOF
    echo -e "${COLOR_BLUE}==>${COLOR_RESET} Removed hooks from $ZSHRC_FILE"
  fi
fi

echo -e "${COLOR_GREEN}✔ Uninstallation complete.${COLOR_RESET}"
