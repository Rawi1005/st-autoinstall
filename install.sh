#!/usr/bin/env bash
set -e

# ─── Detect Termux PREFIX ────────────────────────────────────────────────────
# If $PREFIX is already set (Termux does this for you), use it.
# Otherwise fall back to known paths or derive it from where 'bash' lives.
if [ -n "$PREFIX" ]; then
  TERMUX_PREFIX="$PREFIX"
elif [ -d "/data/data/com.termux/files/usr" ]; then
  TERMUX_PREFIX="/data/data/com.termux/files/usr"
elif [ -d "/data/user/0/com.termux/files/usr" ]; then
  TERMUX_PREFIX="/data/user/0/com.termux/files/usr"
else
  # readlink -f may not exist everywhere; if it doesn’t, you can omit it
  TERMUX_PREFIX="$(dirname "$(dirname "$(readlink -f "$(which bash)")")")"
fi

# ─── 0) Repair broken dpkg state ────────────────────────────────────────────
echo -e "\e[93m[Fixing] Repairing broken dpkg state...\e[0m"
dpkg --configure -a || {
  echo -e "\e[93m[Fixing] Running apt install -f to resolve deps...\e[0m"
  apt install -f -y
}

# ─── Force non-interactive installs & keep old conffiles ────────────────────
export DEBIAN_FRONTEND=noninteractive
mkdir -p "$TERMUX_PREFIX/etc/apt/apt.conf.d"
cat <<EOF > "$TERMUX_PREFIX/etc/apt/apt.conf.d/99noconf"
APT::Get::Assume-Yes "true";
APT::Install-Recommends "false";
APT::Install-Suggests "false";
DPkg::Options {
   "--force-confdef";
   "--force-confold";
};
EOF

echo -e "\e[92m=============================="
echo -e "  AUTO INSTALL ST.  V1.0 🚀"
echo -e "==============================\e[0m"

# ─── STEP 1: Update Termux ───────────────────────────────────────────────────
echo -e "\n\e[94m[Step 1/6] Updating packages...\e[0m"
apt update && apt upgrade -y

# ─── STEP 2: Install dependencies ────────────────────────────────────────────
echo -e "\n\e[94m[Step 2/6] Installing nodejs, git, esbuild...\e[0m"
apt install nodejs git esbuild -y

# ─── STEP 3: Clone SillyTavern ───────────────────────────────────────────────
echo -e "\n\e[94m[Step 3/6] Cloning SillyTavern repo...\e[0m"
cd "$HOME"
rm -rf SillyTavern
git clone https://github.com/SillyTavern/SillyTavern.git
cd SillyTavern

# ─── STEP 4: Switch to staging branch ────────────────────────────────────────
echo -e "\n\e[94m[Step 4/6] Switching to 'staging' branch...\e[0m"
git fetch --all
if git switch staging 2>/dev/null; then
  echo -e "\e[92m[✓] Switched to staging via git switch\e[0m"
else
  echo -e "\e[93m[*] Falling back to git checkout staging...\e[0m"
  git checkout staging
fi
git pull --ff-only

# ─── STEP 5: Install node_modules ───────────────────────────────────────────
echo -e "\n\e[94m[Step 5/6] Installing node_modules...\e[0m"
npm ci --no-optional

# ─── STEP 6: Launch SillyTavern ─────────────────────────────────────────────
echo -e "\n\e[94m[Step 6/6] Launching SillyTavern...\e[0m"
bash start.sh || {
  echo -e "\n\e[91m[!] Launch failed. Try restarting Termux and running:\e[0m"
  echo "    cd ~/SillyTavern && bash start.sh"
  exit 1
}

echo -e "\n\e[92m✅ DONE! SillyTavern (staging) is installed and running!\e[0m"
echo -e "\n\e[96m📘 Learn the basics here:\e[0m"
echo -e "https://sillytavern.rnsv.xyz/basics/editor\n"
