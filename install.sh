#!/usr/bin/env bash
# ==============================================================================
# herdr-autoname: Automated Installer
# Installs tab & pane auto-naming and dynamic renumbering for Herdr multiplexer.
# ==============================================================================

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HERDR_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/herdr"
SCRIPTS_DIR="$HERDR_CONFIG_DIR/scripts"
CONFIG_FILE="$HERDR_CONFIG_DIR/config.toml"
ZSHRC_FILE="$HOME/.zshrc"

COLOR_GREEN="\033[0;32m"
COLOR_BLUE="\033[0;34m"
COLOR_YELLOW="\033[1;33m"
COLOR_RESET="\033[0m"

echo -e "${COLOR_BLUE}==>${COLOR_RESET} Installing herdr-autoname..."

# 1. Dependency checks
if ! command -v python3 >/dev/null 2>&1; then
  echo -e "${COLOR_YELLOW}[Warning]${COLOR_RESET} python3 is required for the background daemon but not found in PATH."
fi

if ! command -v herdr >/dev/null 2>&1; then
  echo -e "${COLOR_YELLOW}[Warning]${COLOR_RESET} herdr binary not found in PATH. Make sure Herdr is installed."
fi

# 2. Setup destination scripts directory
mkdir -p "$SCRIPTS_DIR"

echo -e "${COLOR_BLUE}==>${COLOR_RESET} Linking scripts into $SCRIPTS_DIR..."
ln -sf "$REPO_DIR/daemon/herdr-autoname-daemon.py" "$SCRIPTS_DIR/herdr-autoname-daemon.py"
ln -sf "$REPO_DIR/zsh/herdr-autoname.zsh" "$SCRIPTS_DIR/herdr-autoname.zsh"
chmod +x "$SCRIPTS_DIR/herdr-autoname-daemon.py"

# 3. Configure ~/.config/herdr/config.toml
mkdir -p "$HERDR_CONFIG_DIR"
if [[ -f "$CONFIG_FILE" ]]; then
  if [[ ! -f "${CONFIG_FILE}.bak" ]]; then
    cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"
    echo -e "${COLOR_BLUE}==>${COLOR_RESET} Created backup: ${CONFIG_FILE}.bak"
  fi
else
  touch "$CONFIG_FILE"
fi

# Helper to ensure key-value under a TOML section
python3 - << 'EOF'
import os
import re

config_path = os.path.expanduser("~/.config/herdr/config.toml")
lines = []
if os.path.exists(config_path):
    with open(config_path, "r", encoding="utf-8") as f:
        lines = f.read().splitlines()

cleaned_lines = []
for l in lines:
    if l.strip().startswith("[ui]"):
        cleaned_lines.append("[ui]")
        continue
    if re.match(r"^\s*prompt_new_tab_name\s*=", l):
        continue
    if re.match(r"^\s*show_agent_labels_on_pane_borders\s*=", l):
        continue
    cleaned_lines.append(l)

out_lines = []
ui_found = False
for l in cleaned_lines:
    out_lines.append(l)
    if l.strip() == "[ui]":
        out_lines.append("prompt_new_tab_name = false")
        out_lines.append("show_agent_labels_on_pane_borders = true")
        ui_found = True

if not ui_found:
    out_lines.append("")
    out_lines.append("[ui]")
    out_lines.append("prompt_new_tab_name = false")
    out_lines.append("show_agent_labels_on_pane_borders = true")

with open(config_path, "w", encoding="utf-8") as f:
    f.write("\n".join(out_lines) + "\n")
EOF

echo -e "${COLOR_BLUE}==>${COLOR_RESET} Configured prompt_new_tab_name and show_agent_labels in $CONFIG_FILE"

# 4. Integrate with ~/.zshrc
if [[ -f "$ZSHRC_FILE" ]]; then
  if ! grep -q "herdr-autoname" "$ZSHRC_FILE"; then
    echo -e "${COLOR_BLUE}==>${COLOR_RESET} Adding hook to $ZSHRC_FILE..."
    cat << 'EOF' >> "$ZSHRC_FILE"

# >>> herdr-autoname >>>
[[ -f "$HOME/.config/herdr/scripts/herdr-autoname.zsh" ]] && source "$HOME/.config/herdr/scripts/herdr-autoname.zsh"
# <<< herdr-autoname <<<
EOF
  else
    echo -e "${COLOR_BLUE}==>${COLOR_RESET} Hook already present in $ZSHRC_FILE"
  fi
fi

# 5. Reload Herdr config if server is running
if command -v herdr >/dev/null 2>&1 && herdr status server >/dev/null 2>&1; then
  herdr server reload-config >/dev/null 2>&1 || true
fi

# 6. Restart daemon if Herdr socket is live
if [[ -S "$HERDR_CONFIG_DIR/herdr.sock" ]]; then
  echo -e "${COLOR_BLUE}==>${COLOR_RESET} Starting herdr-autoname daemon..."
  pkill -f "herdr-autoname-daemon.py" >/dev/null 2>&1 || true
  nohup python3 "$SCRIPTS_DIR/herdr-autoname-daemon.py" >/dev/null 2>&1 &
  python3 "$SCRIPTS_DIR/herdr-autoname-daemon.py" --sync-now >/dev/null 2>&1 || true
fi

echo -e "${COLOR_GREEN}✔ Installation complete!${COLOR_RESET}"
echo -e "Open a new pane/tab in Herdr or run: ${COLOR_BLUE}source ~/.zshrc${COLOR_RESET}"
