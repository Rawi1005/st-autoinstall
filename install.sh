#!/usr/bin/env bash
set -Eeuo pipefail

# SillyTavern Termux auto-installer
# Default branch: staging
# Safe for:
# curl -fsSL https://raw.githubusercontent.com/Rawi1005/st-autoinstall/main/install.sh | bash

ST_REPO_URL="${ST_REPO_URL:-https://github.com/SillyTavern/SillyTavern.git}"
ST_BRANCH="${ST_BRANCH:-staging}"
ST_DIR="${ST_DIR:-$HOME/SillyTavern}"
ST_MODE="${ST_MODE:-prompt}"       # prompt, repair, backup, delete, cancel
ST_LAUNCH="${ST_LAUNCH:-1}"        # 1 = launch after install, 0 = install only
ST_GLOBAL="${ST_GLOBAL:-0}"        # 1 = node server.js --global
ST_SKIP_UPGRADE="${ST_SKIP_UPGRADE:-0}"
MIN_NODE_MAJOR="${MIN_NODE_MAJOR:-20}"
FORCE_WEBPACK_HOTFIX="${FORCE_WEBPACK_HOTFIX:-0}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

info(){ printf "%b\n" "${BLUE}[INFO]${NC} $*"; }
ok(){ printf "%b\n" "${GREEN}[OK]${NC} $*"; }
warn(){ printf "%b\n" "${YELLOW}[WARN]${NC} $*"; }
die(){ printf "%b\n" "${RED}[FATAL]${NC} $*" >&2; exit 1; }

trap 'die "Failed near line $LINENO: $BASH_COMMAND"' ERR

usage(){
cat <<USAGE
SillyTavern Termux installer using Yarn.

Default branch is staging.

Examples:
  curl -fsSL https://raw.githubusercontent.com/Rawi1005/st-autoinstall/main/install.sh | bash
  curl -fsSL https://raw.githubusercontent.com/Rawi1005/st-autoinstall/main/install.sh | bash -s -- --mode repair
  curl -fsSL https://raw.githubusercontent.com/Rawi1005/st-autoinstall/main/install.sh | bash -s -- --no-launch

Options:
  --branch release|staging
  --dir PATH
  --mode prompt|repair|backup|delete|cancel
  --repair
  --fresh
  --delete
  --no-launch
  --global
  --skip-upgrade
  --force-webpack-hotfix
  -h, --help
USAGE
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --branch) ST_BRANCH="${2:?Missing value for --branch}"; shift 2 ;;
    --dir) ST_DIR="${2:?Missing value for --dir}"; shift 2 ;;
    --mode) ST_MODE="${2:?Missing value for --mode}"; shift 2 ;;
    --repair) ST_MODE="repair"; shift ;;
    --fresh) ST_MODE="backup"; shift ;;
    --delete) ST_MODE="delete"; shift ;;
    --no-launch) ST_LAUNCH="0"; shift ;;
    --global) ST_GLOBAL="1"; shift ;;
    --skip-upgrade) ST_SKIP_UPGRADE="1"; shift ;;
    --force-webpack-hotfix) FORCE_WEBPACK_HOTFIX="1"; shift ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done

case "$ST_MODE" in
  prompt|repair|backup|delete|cancel) ;;
  *) die "Bad --mode: $ST_MODE" ;;
esac

mkdir -p "$HOME/.local/bin"
export PATH="$HOME/.local/bin:${PATH:-}"

persist_user_bin(){
  local rc="$HOME/.bashrc"
  local line='export PATH="$HOME/.local/bin:$PATH"'
  mkdir -p "$HOME/.local/bin"
  if [ ! -f "$rc" ] || ! grep -Fq '.local/bin' "$rc"; then
    printf '\n# Added by SillyTavern auto-installer\n%s\n' "$line" >> "$rc"
  fi
}

detect_prefix(){
  if [ -n "${PREFIX:-}" ]; then
    echo "$PREFIX"
  elif [ -d /data/data/com.termux/files/usr ]; then
    echo /data/data/com.termux/files/usr
  elif [ -d /data/user/0/com.termux/files/usr ]; then
    echo /data/user/0/com.termux/files/usr
  else
    dirname "$(dirname "$(readlink -f "$(command -v bash)")")"
  fi
}

TERMUX_PREFIX="$(detect_prefix)"
export TMPDIR="${TMPDIR:-$TERMUX_PREFIX/tmp}"
mkdir -p "$TMPDIR"

ARCH="$(uname -m 2>/dev/null || echo unknown)"
MEM_KB="$(awk '/MemTotal/ {print $2}' /proc/meminfo 2>/dev/null || echo 0)"
MEM_GB=$(( MEM_KB / 1024 / 1024 ))
LOW_RESOURCE=0
[ "$MEM_GB" -lt 3 ] && LOW_RESOURCE=1
[[ "$ARCH" =~ ^(arm|armv7|i686|x86)$ ]] && LOW_RESOURCE=1

ask_tty(){
  local prompt="$1"
  local default="$2"
  local answer=""

  if [ -r /dev/tty ] && [ -w /dev/tty ]; then
    printf "%s" "$prompt" > /dev/tty
    IFS= read -r answer < /dev/tty || answer="$default"
  else
    answer="$default"
  fi

  [ -n "$answer" ] || answer="$default"
  printf "%s" "$answer"
}

banner(){
  printf "%b\n" "${CYAN}==============================================${NC}"
  printf "%b\n" "${CYAN} SillyTavern Auto Install - Yarn + Webpack Guard${NC}"
  printf "%b\n" "${CYAN} Branch: $ST_BRANCH${NC}"
  printf "%b\n" "${CYAN} Folder: $ST_DIR${NC}"
  printf "%b\n" "${CYAN} Arch: $ARCH, RAM: ${MEM_GB}GB${NC}"
  printf "%b\n" "${CYAN}==============================================${NC}"
}

setup_apt(){
  export DEBIAN_FRONTEND=noninteractive
  mkdir -p "$TERMUX_PREFIX/etc/apt/apt.conf.d"

  cat > "$TERMUX_PREFIX/etc/apt/apt.conf.d/99noconf" <<'APTCONF'
APT::Get::Assume-Yes "true";
APT::Install-Recommends "false";
APT::Install-Suggests "false";
DPkg::Options { "--force-confdef"; "--force-confold"; };
APTCONF

  dpkg --configure -a || true
  apt install -f -y || true
}

pm_update(){
  if command -v pkg >/dev/null 2>&1; then
    pkg update -y
  else
    apt update
  fi
}

pm_upgrade(){
  if [ "$ST_SKIP_UPGRADE" = "1" ]; then
    warn "Skipping package upgrade."
    return 0
  fi

  if command -v pkg >/dev/null 2>&1; then
    pkg upgrade -y
  else
    apt upgrade -y
  fi
}

pm_install(){
  if command -v pkg >/dev/null 2>&1; then
    pkg install -y "$@"
  else
    apt install -y "$@"
  fi
}

pm_reinstall(){
  if command -v pkg >/dev/null 2>&1; then
    pkg reinstall -y "$@" || pkg install -y "$@"
  else
    apt install --reinstall -y "$@" || apt install -y "$@"
  fi
}

install_packages(){
  info "Updating Termux packages..."
  pm_update
  pm_upgrade

  info "Installing required packages..."
  pm_install git python make clang tar nano

  if ! pm_install nodejs-lts; then
    warn "nodejs-lts failed. Trying nodejs."
    pm_install nodejs
  fi

  pm_install yarn || warn "Yarn package failed. npm fallback will install Yarn later."
  pm_install esbuild || warn "esbuild package failed. npm fallback will install esbuild later."
}

ensure_cmd_pkg(){
  local cmd="$1"
  local pkg="$2"

  if command -v "$cmd" >/dev/null 2>&1; then
    ok "$cmd: $(command -v "$cmd")"
    return 0
  fi

  warn "$cmd missing. Trying package: $pkg"
  pm_reinstall "$pkg" || true
  command -v "$cmd" >/dev/null 2>&1
}

ensure_node(){
  ensure_cmd_pkg node nodejs-lts || ensure_cmd_pkg node nodejs || die "Node.js could not be installed. Try: pkg change-repo"

  local major minor patch
  major="$(node -e "console.log(Number(process.versions.node.split('.')[0]) || 0)" 2>/dev/null || echo 0)"
  minor="$(node -e "console.log(Number(process.versions.node.split('.')[1]) || 0)" 2>/dev/null || echo 0)"
  patch="$(node -e "console.log(Number(process.versions.node.split('.')[2]) || 0)" 2>/dev/null || echo 0)"

  [ "$major" -ge "$MIN_NODE_MAJOR" ] || die "Node $(node -v 2>/dev/null || echo unknown) is too old. Need Node $MIN_NODE_MAJOR+."

  if [ "$major" -eq 23 ] && [ "$minor" -eq 2 ]; then
    warn "Node 23.2.x has known Webpack build problems. Trying to replace it with nodejs-lts."
    pm_install nodejs-lts || true
    hash -r || true

    major="$(node -e "console.log(Number(process.versions.node.split('.')[0]) || 0)" 2>/dev/null || echo 0)"
    minor="$(node -e "console.log(Number(process.versions.node.split('.')[1]) || 0)" 2>/dev/null || echo 0)"

    if [ "$major" -eq 23 ] && [ "$minor" -eq 2 ]; then
      warn "Still on Node 23.2.x. Webpack hotfix will be forced."
      FORCE_WEBPACK_HOTFIX="1"
    fi
  fi

  node --input-type=commonjs <<'NODECHECK'
const fs = require('fs');
const os = require('os');
const path = require('path');
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), 'st-node-'));
fs.writeFileSync(path.join(tmp, 'ok.txt'), 'ok');
fs.rmSync(tmp, { recursive: true, force: true });
console.log('Node core modules OK');
NODECHECK

  ok "Node: $(node -v)"
}

make_user_npm_wrapper(){
  local npm_cli="$1"
  local npx_cli="$2"

  persist_user_bin
  mkdir -p "$HOME/.local/bin"

  cat > "$HOME/.local/bin/npm" <<WRAPNPM
#!/usr/bin/env sh
exec node "$npm_cli" "\$@"
WRAPNPM
  chmod +x "$HOME/.local/bin/npm"

  if [ -n "$npx_cli" ] && [ -f "$npx_cli" ]; then
    cat > "$HOME/.local/bin/npx" <<WRAPNPX
#!/usr/bin/env sh
exec node "$npx_cli" "\$@"
WRAPNPX
    chmod +x "$HOME/.local/bin/npx"
  fi

  export PATH="$HOME/.local/bin:$PATH"
  hash -r || true
}

repair_npm_from_existing_files(){
  local npm_cli npx_cli base

  for base in \
    "$TERMUX_PREFIX/lib/node_modules/npm" \
    "$TERMUX_PREFIX/lib/nodejs/npm" \
    "$HOME/.local/share/st-autoinstall/npm/package"; do
    npm_cli="$base/bin/npm-cli.js"
    npx_cli="$base/bin/npx-cli.js"

    if [ -f "$npm_cli" ]; then
      warn "npm files exist but npm command is missing. Creating user wrapper."
      make_user_npm_wrapper "$npm_cli" "$npx_cli"
      command -v npm >/dev/null 2>&1 && return 0
    fi
  done

  return 1
}

bootstrap_npm_for_user(){
  warn "npm is still missing. Installing npm for this user into ~/.local."
  persist_user_bin

  mkdir -p "$HOME/.local/share/st-autoinstall/npm" "$HOME/.local/bin"
  rm -rf "$HOME/.local/share/st-autoinstall/npm/package"

  local tmp_tgz
  tmp_tgz="$(mktemp "${TMPDIR:-/tmp}/npm.XXXXXX.tgz")"

  node --input-type=module - "$tmp_tgz" <<'BOOTSTRAPNPM'
import { writeFile } from 'node:fs/promises';

const out = process.argv[2];
const metaRes = await fetch('https://registry.npmjs.org/npm/latest', {
  headers: { accept: 'application/json' },
});

if (!metaRes.ok) {
  throw new Error(`npm registry failed: ${metaRes.status}`);
}

const meta = await metaRes.json();
const tarball = meta?.dist?.tarball;

if (!tarball) {
  throw new Error('npm registry response did not include a tarball');
}

const tarRes = await fetch(tarball);

if (!tarRes.ok) {
  throw new Error(`npm tarball download failed: ${tarRes.status}`);
}

await writeFile(out, Buffer.from(await tarRes.arrayBuffer()));
console.log(`Downloaded npm ${meta.version}`);
BOOTSTRAPNPM

  tar -xzf "$tmp_tgz" -C "$HOME/.local/share/st-autoinstall/npm"
  rm -f "$tmp_tgz"

  make_user_npm_wrapper \
    "$HOME/.local/share/st-autoinstall/npm/package/bin/npm-cli.js" \
    "$HOME/.local/share/st-autoinstall/npm/package/bin/npx-cli.js"

  command -v npm >/dev/null 2>&1
}

ensure_npm(){
  info "Checking npm. If missing, it will be installed for this user."

  if command -v npm >/dev/null 2>&1; then
    ok "npm found: $(command -v npm)"
  else
    repair_npm_from_existing_files || true
  fi

  if ! command -v npm >/dev/null 2>&1; then
    warn "npm command not found. Reinstalling Node.js package first."
    pm_reinstall nodejs-lts || pm_reinstall nodejs || true
    hash -r || true
    repair_npm_from_existing_files || true
  fi

  if ! command -v npm >/dev/null 2>&1; then
    warn "Trying separate npm package if available."
    pm_install npm || true
    hash -r || true
    repair_npm_from_existing_files || true
  fi

  if ! command -v npm >/dev/null 2>&1; then
    bootstrap_npm_for_user || die "npm could not be installed even with user-local fallback."
  fi

  npm --version >/dev/null || die "npm exists but cannot run."

  npm config set prefix "$HOME/.local" --location=user >/dev/null 2>&1 || npm config set prefix "$HOME/.local" >/dev/null 2>&1 || true
  npm config set fund false --location=user >/dev/null 2>&1 || npm config set fund false >/dev/null 2>&1 || true
  npm config set audit false --location=user >/dev/null 2>&1 || npm config set audit false >/dev/null 2>&1 || true
  npm config set progress false --location=user >/dev/null 2>&1 || npm config set progress false >/dev/null 2>&1 || true

  local cache
  cache="$(npm config get cache 2>/dev/null | tail -n 1 || true)"

  if [ -z "$cache" ] || [ "$cache" = undefined ] || [ "$cache" = null ]; then
    npm config set cache "$HOME/.npm" >/dev/null 2>&1 || true
    cache="$HOME/.npm"
  fi

  mkdir -p "$cache"
  [ -w "$cache" ] || die "npm cache is not writable: $cache"

  npm cache verify >/dev/null 2>&1 || npm cache clean --force >/dev/null 2>&1 || true

  ok "npm: $(npm -v) at $(command -v npm)"
}

ensure_yarn(){
  info "Checking Yarn. If missing, it will be installed for this user."

  if ! command -v yarn >/dev/null 2>&1; then
    warn "Yarn command missing. Trying package manager."
    pm_reinstall yarn || pm_install yarn || true
    hash -r || true
  fi

  if ! command -v yarn >/dev/null 2>&1; then
    warn "Installing Yarn Classic using npm."
    npm install -g yarn@1
    hash -r || true
  fi

  command -v yarn >/dev/null 2>&1 || die "Yarn could not be installed."

  local ver major
  ver="$(yarn --version 2>/dev/null | tail -n 1 || true)"
  [ -n "$ver" ] || die "Yarn exists but cannot run."

  major="$(printf "%s" "$ver" | cut -d. -f1)"

  if [ "$major" -ge 2 ] 2>/dev/null; then
    warn "Yarn $ver detected. Installing Yarn Classic v1 for node_modules compatibility."
    npm install -g yarn@1
    hash -r || true
  fi

  yarn config set network-timeout 600000 >/dev/null 2>&1 || true
  yarn config set progress false >/dev/null 2>&1 || true

  ok "Yarn: $(yarn --version) at $(command -v yarn)"
}

ensure_esbuild(){
  info "Checking esbuild."

  if command -v esbuild >/dev/null 2>&1; then
    ok "esbuild: $(esbuild --version 2>/dev/null || echo unknown)"
    return 0
  fi

  pm_reinstall esbuild || pm_install esbuild || true
  hash -r || true

  if ! command -v esbuild >/dev/null 2>&1; then
    warn "Installing esbuild using npm."
    npm install -g esbuild
    hash -r || true
  fi

  command -v esbuild >/dev/null 2>&1 || die "esbuild could not be installed."
  ok "esbuild: $(esbuild --version 2>/dev/null || echo unknown)"
}

stack_health(){
  info "Preflight: checking git, Node.js, npm, Yarn, and esbuild."
  ensure_cmd_pkg git git || die "git could not be installed."
  ensure_node
  ensure_npm
  ensure_yarn
  ensure_esbuild
  ok "Stack healthy: node $(node -v), npm $(npm -v), yarn $(yarn --version)"
}

handle_existing(){
  [ -d "$ST_DIR" ] || return 0

  local mode="$ST_MODE"

  if [ "$mode" = prompt ]; then
    warn "Existing SillyTavern folder found: $ST_DIR"
    echo "Choose:"
    echo "  r = repair/update keep data"
    echo "  b = backup old folder then fresh install"
    echo "  d = delete old folder then fresh install"
    echo "  n = cancel"

    local choice
    choice="$(ask_tty "Your choice [r/b/d/n]: " n)"

    case "$choice" in
      r|R) mode=repair ;;
      b|B) mode=backup ;;
      d|D) mode=delete ;;
      *) mode=cancel ;;
    esac
  fi

  case "$mode" in
    repair)
      [ -d "$ST_DIR/.git" ] || die "Existing folder is not a git repo. Use --fresh to backup and reinstall."
      ok "Repair mode selected. Data will be kept."
      ;;
    backup)
      local backup="$HOME/SillyTavern_backup_$(date +%Y%m%d_%H%M%S)"
      warn "Moving old folder to $backup"
      mv "$ST_DIR" "$backup"
      ;;
    delete)
      warn "Deleting $ST_DIR"
      rm -rf "$ST_DIR"
      ;;
    cancel)
      ok "Cancelled."
      exit 0
      ;;
  esac
}

restore_webpack_patch_before_update(){
  [ -d .git ] || return 0
  [ -f webpack.config.js ] || return 0

  if grep -q "ST_TERMUX_WEBPACK_HOTFIX" webpack.config.js 2>/dev/null; then
    warn "Removing old installer Webpack hotfix before git update."
    git restore webpack.config.js 2>/dev/null || git checkout -- webpack.config.js 2>/dev/null || true
  fi
}

checkout_branch(){
  restore_webpack_patch_before_update

  git fetch origin --prune

  if git show-ref --verify --quiet "refs/heads/$ST_BRANCH"; then
    git switch "$ST_BRANCH" 2>/dev/null || git checkout "$ST_BRANCH"
  elif git show-ref --verify --quiet "refs/remotes/origin/$ST_BRANCH"; then
    git switch --track "origin/$ST_BRANCH" 2>/dev/null || git checkout -b "$ST_BRANCH" "origin/$ST_BRANCH"
  else
    die "Branch not found: $ST_BRANCH"
  fi

  git pull --rebase --autostash origin "$ST_BRANCH"
}

clone_or_update(){
  if [ -d "$ST_DIR/.git" ]; then
    info "Updating SillyTavern repo."
    cd "$ST_DIR"
    git remote set-url origin "$ST_REPO_URL" || true
    checkout_branch
  else
    info "Cloning SillyTavern branch $ST_BRANCH."
    mkdir -p "$(dirname "$ST_DIR")"
    git clone --branch "$ST_BRANCH" "$ST_REPO_URL" "$ST_DIR"
    cd "$ST_DIR"
  fi
}

project_health(){
  info "Checking SillyTavern project files."

  [ -f package.json ] || die "package.json missing."
  [ -f server.js ] || die "server.js missing."
  [ -f webpack.config.js ] || die "webpack.config.js missing."

  node --input-type=commonjs <<'PROJECTCHECK'
const fs = require('fs');

const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));

if (!pkg.dependencies || Object.keys(pkg.dependencies).length === 0) {
  console.error('package.json has no dependencies; checkout looks broken.');
  process.exit(1);
}

console.log(`Project OK: ${pkg.name || 'unknown'}, dependencies: ${Object.keys(pkg.dependencies).length}`);
PROJECTCHECK
}

clean_generated_caches(){
  info "Cleaning generated Webpack/cache folders."

  rm -rf data/_webpack
  rm -rf dist/_webpack
  rm -rf node_modules/.cache
  rm -rf .cache
  rm -rf cache
}

clean_bad_node_modules(){
  if [ ! -d node_modules ]; then
    return 0
  fi

  info "Existing node_modules found. Checking basic modules."

  if node --input-type=commonjs <<'NMCHECK' >/dev/null 2>&1
require.resolve('express/package.json');
require.resolve('webpack/package.json');
require.resolve('yaml/package.json');
require.resolve('ws/package.json');
NMCHECK
  then
    ok "Old node_modules has basic modules. Yarn will verify it."
  else
    warn "Old node_modules is broken. Removing it."
    rm -rf node_modules
  fi
}

yarn_install(){
  clean_bad_node_modules

  local args=(
    install
    --production=true
    --ignore-scripts
    --non-interactive
    --check-files
    --network-timeout
    600000
  )

  if [ "$LOW_RESOURCE" -eq 1 ]; then
    warn "Low-memory or old CPU detected. Using safer Yarn settings."
    export NODE_OPTIONS="--max-old-space-size=2048 ${NODE_OPTIONS:-}"
    args+=(--network-concurrency 1)
  else
    export NODE_OPTIONS="--max-old-space-size=4096 ${NODE_OPTIONS:-}"
  fi

  info "Installing node_modules with Yarn."

  if ! yarn "${args[@]}"; then
    warn "Yarn failed. Cleaning cache and retrying once."
    yarn cache clean >/dev/null 2>&1 || true
    rm -rf node_modules
    yarn install --production=true --ignore-scripts --non-interactive --check-files --network-timeout 600000 --network-concurrency 1
  fi
}

verify_modules(){
  info "Verifying node_modules."

  [ -d node_modules ] || die "node_modules missing after Yarn install."

  node --input-type=commonjs <<'VERIFY'
const fs = require('fs');
const path = require('path');
const { createRequire } = require('module');

const req = createRequire(path.join(process.cwd(), 'package.json'));
const pkg = JSON.parse(fs.readFileSync('package.json', 'utf8'));
const deps = Object.keys(pkg.dependencies || {});

const missing = deps.filter(name => {
  const parts = name.split('/');
  return !fs.existsSync(path.join(process.cwd(), 'node_modules', ...parts));
});

if (missing.length) {
  console.error('Missing dependency folders:');
  for (const name of missing.slice(0, 30)) console.error(' - ' + name);
  if (missing.length > 30) console.error(' ...and ' + (missing.length - 30) + ' more');
  process.exit(1);
}

for (const name of ['express', 'webpack', 'yaml', 'cookie-parser', 'ws']) {
  req.resolve(name + '/package.json');
  console.log('Module resolves OK: ' + name);
}

console.log('All direct dependency folders are present: ' + deps.length);
VERIFY

  ok "node_modules verified."
}

apply_webpack_hotfix(){
  info "Applying Termux Webpack hotfix: disable module concatenation."

  node --input-type=module <<'PATCHWEBPACK'
import fs from 'node:fs';

const file = 'webpack.config.js';
let text = fs.readFileSync(file, 'utf8');

if (text.includes('ST_TERMUX_WEBPACK_HOTFIX')) {
  console.log('Webpack hotfix already applied.');
  process.exit(0);
}

const before = text;

text = text.replace(
  /(performance:\s*\{\s*hints:\s*false,\s*\},\s*)output:/,
  '$1optimization: { concatenateModules: false }, /* ST_TERMUX_WEBPACK_HOTFIX */ output:'
);

if (text === before) {
  console.error('Could not patch webpack.config.js automatically. Config format changed.');
  process.exit(1);
}

fs.writeFileSync(file, text);
console.log('Patched webpack.config.js');
PATCHWEBPACK
}

run_webpack_test(){
  info "Testing SillyTavern frontend Webpack build before launch."

  mkdir -p data
  rm -rf data/_webpack
  rm -rf dist/_webpack
  rm -rf node_modules/.cache

  node --input-type=module <<'WEBPACKTEST'
import path from 'node:path';
import webpack from 'webpack';

globalThis.DATA_ROOT = path.resolve('data');

const configModule = await import(path.resolve('webpack.config.js'));
const getPublicLibConfig = configModule.default;

const compiler = webpack(getPublicLibConfig({ pruneCache: true }));

const stats = await new Promise((resolve, reject) => {
  compiler.run((err, result) => {
    compiler.close((closeErr) => {
      if (err) return reject(err);
      if (closeErr) return reject(closeErr);
      resolve(result);
    });
  });
});

if (stats.hasErrors()) {
  console.error(stats.toString({
    all: false,
    errors: true,
    warnings: true,
    colors: true,
  }));
  process.exit(1);
}

console.log(stats.toString({
  preset: 'minimal',
  colors: true,
  timings: true,
}));
WEBPACKTEST
}

webpack_guard(){
  clean_generated_caches

  if [ "$FORCE_WEBPACK_HOTFIX" = "1" ]; then
    warn "Forced Webpack hotfix enabled."
    apply_webpack_hotfix
  fi

  if run_webpack_test; then
    ok "Frontend Webpack build test passed."
    return 0
  fi

  warn "Frontend Webpack build failed. This is the same class of error that causes missing data/_webpack/.../output/lib.js."
  warn "Trying automatic Termux Webpack hotfix, then rebuilding once."

  apply_webpack_hotfix
  clean_generated_caches

  if run_webpack_test; then
    ok "Frontend Webpack build passed after hotfix."
    return 0
  fi

  die "Frontend Webpack build still fails after hotfix. Staging may currently be broken, or this Node build is incompatible."
}

write_start_script(){
  cat > "$ST_DIR/start-yarn.sh" <<'STARTYARN'
#!/usr/bin/env bash
set -e
cd "$(dirname "$0")"

export NODE_ENV="${NODE_ENV:-production}"

if [ "${ST_CLEAR_WEBPACK_CACHE:-0}" = "1" ]; then
  rm -rf data/_webpack
  rm -rf dist/_webpack
  rm -rf node_modules/.cache
fi

if [ "${ST_GLOBAL:-0}" = "1" ]; then
  exec node server.js --global "$@"
else
  exec node server.js "$@"
fi
STARTYARN

  chmod +x "$ST_DIR/start-yarn.sh"
}

launch_or_finish(){
  printf "%b\n" "${GREEN}==============================================${NC}"
  printf "%b\n" "${GREEN}DONE. SillyTavern installed/repaired with Yarn.${NC}"
  printf "%b\n" "${CYAN}Branch:${NC} $ST_BRANCH"
  printf "%b\n" "${CYAN}Start:${NC} cd \"$ST_DIR\" && bash start-yarn.sh"
  printf "%b\n" "${CYAN}Force cache rebuild:${NC} cd \"$ST_DIR\" && ST_CLEAR_WEBPACK_CACHE=1 bash start-yarn.sh"
  printf "%b\n" "${CYAN}Open:${NC} http://127.0.0.1:8000/"
  printf "%b\n" "${GREEN}==============================================${NC}"

  [ "$ST_LAUNCH" = "1" ] || return 0

  info "Launching SillyTavern."
  cd "$ST_DIR"

  if [ "$ST_GLOBAL" = "1" ]; then
    ST_GLOBAL=1 bash ./start-yarn.sh
  else
    bash ./start-yarn.sh
  fi
}

main(){
  banner

  command -v apt >/dev/null 2>&1 || die "apt not found. This script is for Termux/Debian-like systems."
  command -v dpkg >/dev/null 2>&1 || die "dpkg not found."

  setup_apt
  install_packages
  stack_health
  handle_existing
  clone_or_update
  stack_health
  project_health
  yarn_install
  verify_modules
  webpack_guard
  write_start_script
  launch_or_finish
}

main "$@"
