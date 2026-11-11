# herdr-autoname ⚡🏷️

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Terminal: Herdr](https://img.shields.io/badge/terminal-Herdr-blueviolet.svg)](https://herdr.dev)
[![Shell: Zsh](https://img.shields.io/badge/shell-Zsh-orange.svg)](https://www.zsh.org/)
[![Python 3.8+](https://img.shields.io/badge/python-3.8+-brightgreen.svg)](https://www.python.org/)

> **Dynamic tab auto-naming & real-time renumbering for the [Herdr](https://herdr.dev) terminal workspace manager.**

Automatically keeps your tabs formatted as `<tab_index>. <folder_name>`, re-numbers remaining tabs in real-time when any tab is deleted or moved, and tracks directory changes (`cd ..`) seamlessly.

---

## ✨ Features

- **Sequential Numbering**: Tabs are always numbered sequentially: `1. web-client`, `2. api-service`, `3. auth-worker`, perfectly matching Herdr's `prefix + 1..9` shortcut keys.
- **Instant Directory Tracking**: Changing directories in a pane (`cd ..`, `cd path/to/project`) updates the tab name in milliseconds.
- **Dynamic Renumbering on Tab Close**: Closing an intermediate tab (e.g. Tab 2) immediately renumbers subsequent tabs (`3. payment-service` becomes `2. payment-service`) via real-time Herdr socket events (`tab.closed`, `tab.moved`).
- **Pane Command Awareness**: Panes adapt dynamically when running commands like `nvim` and restore to the folder name when returning to the shell prompt.
- **Native AI Agent Integration**: Works smoothly alongside Herdr's native agent detection (`agy`, `pi`, `claude`, `opencode`) and displays active status badges.
- **Portable & Zero-Maintenance**: Clone on personal or work machines and run `./install.sh`.

---

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                       Herdr TUI                             │
│   Tab 1: web-client │ Tab 2: api-service │ Tab 3: database  │
└──────────────────────────────┬──────────────────────────────┘
                               │
                Unix Socket: ~/.config/herdr/herdr.sock
                               │
            ┌──────────────────┴──────────────────┐
            ▼                                     ▼
 ┌──────────────────────┐             ┌──────────────────────┐
 │ herdr-autoname-daemon│             │   zsh Shell Hook     │
 │ (Background listener)│             │ (chpwd / preexec)    │
 │                      │             │                      │
 │ Subscribes to:       │             │ Tracks 'cd' events   │
 │ • tab.closed/created │             │ Tracks 'nvim' runs   │
 │ • tab.moved          │             │ (~15ms execution)    │
 │ • pane.closed/exited │             └──────────────────────┘
 └──────────────────────┘
```

---

## 🚀 Quick Start (1-Command Install)

Clone the repository and run the automated installer:

```bash
git clone https://github.com/eugeniourueta/herdr-autoname.git
cd herdr-autoname
./install.sh
```

Then reload your shell or open a new Herdr pane:

```bash
source ~/.zshrc
```

---

## 🛠️ What `install.sh` Does

1. **Creates Links**: Symlinks `daemon/herdr-autoname-daemon.py` and `zsh/herdr-autoname.zsh` to `~/.config/herdr/scripts/`.
2. **Configures Herdr**: Updates `~/.config/herdr/config.toml` (with automatic backup to `config.toml.bak`):
   ```toml
   [ui]
   prompt_new_tab_name = false
   show_agent_labels_on_pane_borders = true
   ```
3. **Adds Zsh Integration**: Appends an isolated, managed block to `~/.zshrc`:
   ```zsh
   # >>> herdr-autoname >>>
   [[ -f "$HOME/.config/herdr/scripts/herdr-autoname.zsh" ]] && source "$HOME/.config/herdr/scripts/herdr-autoname.zsh"
   # <<< herdr-autoname <<<
   ```
4. **Starts Daemon**: Automatically spins up the background listener if Herdr is running.

---

## 🧪 Testing the Setup

1. **Tab Creation**: Press `Ctrl+b c`. The tab will be created immediately with `<index>. <current_folder>` without asking for a manual name.
2. **Directory Navigation**: Run `cd ..` inside any pane. Notice how the tab label updates in real-time.
3. **Tab Deletion**: Close an intermediate tab with `Ctrl+b Shift+X`. All remaining tabs will renumber in microsecond real-time.
4. **Command Execution**: Run `nvim`. The pane will display `nvim`. Exit Neovim (`:q`) to see it revert back to your directory.

---

## 🗑️ Uninstallation

To completely remove `herdr-autoname` and restore your previous configuration:

```bash
./uninstall.sh
```

---

## 📄 License

MIT © [Eugenio Urueta](https://github.com/eugeniourueta)
