# ==============================================================================
# herdr-autoname.zsh
# Shell integration hooks for Herdr multiplexer:
# - Renames tab to "<index>. <folder>" on 'cd' and shell startup.
# - Renames pane to running command (e.g. nvim, agy, git) via preexec.
# - Restores pane name to current folder upon returning to prompt via precmd.
# - Automatically launches background daemon for real-time tab renumbering.
# ==============================================================================

if [[ -n "$HERDR_ENV" ]]; then

  _herdr_update_tab_name() {
    [[ -z "$HERDR_TAB_ID" ]] && return
    local folder="${PWD##*/}"
    [[ "$PWD" == "$HOME" ]] && folder="~"
    [[ -z "$folder" ]] && folder="/"

    # Fetch 1-based index of this tab in the active workspace
    local tab_idx
    tab_idx=$(herdr tab list --workspace "$HERDR_WORKSPACE_ID" 2>/dev/null | \
              grep -o '"tab_id":"[^"]*"' | grep -n "$HERDR_TAB_ID" | cut -d: -f1)

    if [[ -n "$tab_idx" ]]; then
      herdr tab rename "$HERDR_TAB_ID" "${tab_idx}. ${folder}" >/dev/null 2>&1
    fi
  }

  _herdr_pane_preexec() {
    [[ -z "$HERDR_PANE_ID" ]] && return
    local cmd="${1%% *}"
    cmd="${cmd##*/}"
    [[ -n "$cmd" ]] && herdr pane rename "$HERDR_PANE_ID" "$cmd" >/dev/null 2>&1
  }

  _herdr_pane_precmd() {
    [[ -z "$HERDR_PANE_ID" ]] && return
    local folder="${PWD##*/}"
    [[ "$PWD" == "$HOME" ]] && folder="~"
    [[ -z "$folder" ]] && folder="/"
    herdr pane rename "$HERDR_PANE_ID" "$folder" >/dev/null 2>&1
  }

  autoload -U add-zsh-hook
  add-zsh-hook chpwd _herdr_update_tab_name
  add-zsh-hook preexec _herdr_pane_preexec
  add-zsh-hook precmd _herdr_pane_precmd

  # Initial trigger for newly opened tabs and panes
  _herdr_update_tab_name
  _herdr_pane_precmd

  # Launch daemon in background if Herdr socket exists and daemon is not yet running
  local _daemon_script="$HOME/.config/herdr/scripts/herdr-autoname-daemon.py"
  if [[ -S "$HOME/.config/herdr/herdr.sock" && -f "$_daemon_script" ]] && ! pgrep -f "herdr-autoname-daemon.py" >/dev/null 2>&1; then
    nohup python3 "$_daemon_script" >/dev/null 2>&1 &
  fi

fi
