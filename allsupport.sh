#!/usr/bin/env bash
set -e

# ─── 0) Detect platform ──────────────────────────────────────────────────────
OS_TYPE="$(uname -s)"
case "$OS_TYPE" in
  Linux*)
    if [ -n "$PREFIX" ] && [[ "$PREFIX" == *"com.termux"* ]]; then
      OS="termux"
    else
      OS="linux"
    fi
    ;;
  Darwin*)
    OS="mac"
    ;;
  MINGW*|MSYS*|CYGWIN*|Windows_NT)
    OS="windows"
    ;;
  *)
    echo "[!] Unsupported OS: $OS_TYPE"
    exit 1
    ;;
esac
echo -e "\e[94m[Info] Detected platform: $OS\e[0m"

# ─── Helper: install dependencies per‐platform ───────────────────────────────
install_dependencies() {
  case "$OS" in
    termux)
      echo -e "\e[93m[Termux] Repairing dpkg if needed…\e[0m"
      dpkg --configure -a || apt install -f -y || true
      export DEBIAN_FRONTEND=noninteractive

      echo -e "\e[94m[Termux] Updating & installing: nodejs, git, esbuild\e[0m"
      pkg update -y
      pkg install nodejs git esbuild -y
      ;;
    linux)
      if command -v apt >/dev/null; then
        echo -e "\e[94m[Linux/apt] Updating & installing: nodejs, git, esbuild\e[0m"
        sudo apt update && sudo apt install -y nodejs git esbuild
      elif command -v dnf >/dev/null; then
        echo -e "\e[94m[Linux/dnf] Installing: git, nodejs, npm + esbuild via npm\e[0m"
        sudo dnf install -y git nodejs npm
        npm install -g esbuild
      elif command -v pacman >/dev/null; then
        echo -e "\e[94m[Linux/pacman] Installing: git, nodejs, npm + esbuild via npm\e[0m"
        sudo pacman -Sy --noconfirm git nodejs npm
        npm install -g esbuild
      else
        echo "[!] No supported Linux package manager found (apt, dnf, pacman). Install git, nodejs, esbuild manually."
        exit 1
      fi
      ;;
    mac)
      if command -v brew >/dev/null; then
        echo -e "\e[94m[macOS] Updating Homebrew & installing: git, node, esbuild\e[0m"
        brew update
        brew install git node esbuild
      else
        echo "[!] Homebrew not found. Please install it from https://brew.sh/ and re-run."
        exit 1
      fi
      ;;
    windows)
      # use Winget or Chocolatey to get Git + Node.js, then esbuild via npm
      if command -v winget >/dev/null; then
        echo -e "\e[94m[Windows] Installing Git & Node.js via winget\e[0m"
        powershell.exe -Command "winget install --id Git.Git -e --source winget; winget install --id OpenJS.NodeJS.LTS -e --source winget"
      elif command -v choco >/dev/null; then
        echo -e "\e[94m[Windows] Installing Git & Node.js via choco\e[0m"
        powershell.exe -Command "choco install git nodejs-lts -y"
      else
        echo "[!] Neither winget nor choco found. Install Git and Node.js manually."
        exit 1
      fi
      echo -e "\e[94m[Windows] Installing esbuild globally via npm\e[0m"
      npm install -g esbuild
      ;;
  esac
}

# ─── 1) Install prerequisites ────────────────────────────────────────────────
install_dependencies

# ─── 2) Clone SillyTavern ────────────────────────────────────────────────────
echo -e "\n\e[94m[Step] Cloning SillyTavern repository…\e[0m"
cd "$HOME"
rm -rf SillyTavern
git clone https://github.com/SillyTavern/SillyTavern.git
cd SillyTavern

# ─── 3) Switch to staging branch ────────────────────────────────────────────
echo -e "\n\e[94m[Step] Switching to 'staging' branch…\e[0m"
git fetch --all
if git switch staging 2>/dev/null; then
  echo -e "\e[92m[✓] Now on staging (git switch)\e[0m"
else
  echo -e "\e[93m[Fallback] Checking out staging…\e[0m"
  git checkout staging
fi
git pull --ff-only

# ─── 4) Install node_modules ────────────────────────────────────────────────
ARCH="$(uname -m)"
if grep -q MemTotal /proc/meminfo 2>/dev/null; then
  MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
  MEM_GB=$(( MEM_KB / 1024 / 1024 ))
else
  MEM_GB=4
fi
echo -e "\n\e[94m[Info] Arch: $ARCH, RAM: ${MEM_GB}GB\e[0m"
echo -e "\e[94m[Step] Installing npm dependencies…\e[0m"
if [ "$MEM_GB" -lt 1 ] || [[ "$ARCH" =~ ^(arm|i686)$ ]]; then
  echo -e "\e[93m[⚙️] Low-mem/ARM: applying GC workarounds…\e[0m"
  export NODE_OPTIONS="--max-old-space-size=2048 --no-separate-gc-phases"
  npm ci --no-optional
else
  npm ci
fi

# ─── 5) Launch SillyTavern ───────────────────────────────────────────────────
echo -e "\n\e[94m[Step] Launching SillyTavern…\e[0m"
bash start.sh || {
  echo -e "\n\e[91m[!] Launch failed. Try:\e[0m"
  echo "    cd ~/SillyTavern && bash start.sh"
  exit 1
}

echo -e "\n\e[92m✅ SillyTavern (staging) is installed and running!\e[0m"
echo -e "\e[96m📘 Get started: https://sillytavern.rnsv.xyz/basics/editor\e[0m"
