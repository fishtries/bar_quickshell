# bar_quickshell

A customizable Wayland desktop shell configuration using [Quickshell](https://git.outfoxxed.me/outfoxxed/quickshell) and an embedded AI assistant (`aside`).

## Installation

We provide an easy installation script that sets up the project correctly and installs all necessary dependencies (including the internal `aside` module).

### 1-Step Easy Install

1. Open your terminal.
2. Clone the repository and run the installer:

```bash
git clone https://github.com/fishtries/bar_quickshell.git ~/.config/quickshell
cd ~/.config/quickshell
./install.sh
```

**What the script does:**
- Validates that `quickshell` is installed.
- Asks to install system packages via `pacman` if on Arch Linux (`gtk4`, `gtk4-layer-shell`, `python-gobject`).
- Safely moves the configuration to `~/.config/quickshell` if you cloned it elsewhere.
- Creates an isolated Python virtual environment and installs the bundled `aside` module cleanly.

### Manual Installation (Alternative)
If you prefer doing things manually or the script fails on your distribution:
1. Ensure `quickshell` is installed.
2. Clone this repo to `~/.config/quickshell`.
3. Install system dependencies: Python 3.11+, `gtk4`, `gtk4-layer-shell`, `python-gobject`.
4. Run `make install` inside `~/.config/quickshell/aside/`.

## Running
After installation, start `quickshell` from your terminal or add it to your compositor's autostart configuration.
