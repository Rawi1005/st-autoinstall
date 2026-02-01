#!/usr/bin/env bash
set -e

# ─── Detect Termux PREFIX ────────────────────────────────────────────────────
if [ -n "$PREFIX" ]; then
  TERMUX_PREFIX="$PREFIX"
elif [ -d "/data/data/com.termux/files/usr" ]; then
  TERMUX_PREFIX="/data/data/com.termux/files/usr"
elif [ -d "/data/user/0/com.termux/files/usr" ]; then
  TERMUX_PREFIX="/data/user/0/com.termux/files/usr"
else
  TERMUX_PREFIX="$(dirname "$(dirname "$(readlink -f "$(which bash)")")")"
fi

# ─── Gather system info for "potato phone" detection ────────────────────────
ARCH="$(uname -m)"
MEM_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
MEM_GB=$(( MEM_KB / 1024 / 1024 ))
echo -e "\e[94m[Info] Architecture: $ARCH, Memory: ${MEM_GB}GB\e[0m"

# ─── 0) Repair broken dpkg state ───────────────────────────────────────────
echo -e "\e[93m[Fixing] Repairing broken dpkg state... / กำลังซ่อมแซมสถานะ dpkg...\e[0m"
dpkg --configure -a || {
  echo -e "\e[93m[Fixing] Running apt install -f to resolve deps... / กำลังแก้ไข dependencies...\e[0m"
  apt install -f -y
}

# ─── Force non-interactive installs & keep old conffiles ───────────────────
export DEBIAN_FRONTEND=noninteractive
mkdir -p "$TERMUX_PREFIX/etc/apt/apt.conf.d"

# Updated syntax to be more editor-friendly
cat > "$TERMUX_PREFIX/etc/apt/apt.conf.d/99noconf" <<'EOF'
APT::Get::Assume-Yes "true";
APT::Install-Recommends "false";
APT::Install-Suggests "false";
DPkg::Options {
   "--force-confdef";
   "--force-confold";
};
EOF

echo -e "\e[92m=============================================="
echo -e "  AUTO INSTALL ST.  V1.1 🚀"
echo -e "  โปรแกรมติดตั้งอัตโนมัติ SillyTavern"
echo -e "==============================================\e[0m"

# ─── PRE-CHECK: Look for existing installation ─────────────────────────────
ST_DIR="$HOME/SillyTavern"

if [ -d "$ST_DIR" ]; then
    echo -e "\n\e[91m⚠️  WARNING / คำเตือน ⚠️\e[0m"
    echo -e "\e[93mFound an existing SillyTavern folder at $ST_DIR"
    echo -e "ตรวจพบโฟลเดอร์ SillyTavern ที่ติดตั้งอยู่แล้ว\e[0m"
    echo -e ""
    echo -e "Do you want to reinstall? \e[91mTHIS WILL DELETE ALL YOUR DATA (Characters, Chats, etc)!"
    echo -e "\e[0mคุณต้องการติดตั้งใหม่หรือไม่? \e[91mการกระทำนี้จะลบข้อมูลทั้งหมดของคุณ (ตัวละคร, แชท, ฯลฯ)!\e[0m"
    echo -e ""
    
    read -p "Type 'y' to Reinstall (Delete Data) or 'n' to Cancel [y/n]: " -r REPLY
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "\e[91m[Deleting] Removing old installation... / กำลังลบการติดตั้งเก่า...\e[0m"
        rm -rf "$ST_DIR"
    else
        echo -e "\e[92m[Cancelled] Installation cancelled. Your data is safe."
        echo -e "ยกเลิกการติดตั้ง ข้อมูลของคุณปลอดภัย\e[0m"
        exit 0
    fi
fi

# ─── STEP 1: Update Termux ─────────────────────────────────────────────────
echo -e "\n\e[94m[Step 1/6] Updating packages... / กำลังอัปเดตแพ็กเกจ...\e[0m"
apt update && apt upgrade -y

# ─── STEP 2: Install dependencies ─────────────────────────────────────────
echo -e "\n\e[94m[Step 2/6] Installing nodejs, git, esbuild... / กำลังติดตั้ง dependencies...\e[0m"
apt install nodejs git esbuild -y

# ─── STEP 3: Clone SillyTavern ────────────────────────────────────────────
echo -e "\n\e[94m[Step 3/6] Cloning SillyTavern repo... / กำลังโคลนข้อมูลจาก GitHub...\e[0m"
cd "$HOME"
# Double check to ensure we don't error if folder exists (handled above, but safe to force)
rm -rf SillyTavern 
git clone https://github.com/SillyTavern/SillyTavern.git
cd SillyTavern

# ─── STEP 4: Switch to staging branch ──────────────────────────────────────
echo -e "\n\e[94m[Step 4/6] Switching to 'staging' branch... / กำลังสลับไปยัง staging branch...\e[0m"
git fetch --all
if git switch staging 2>/dev/null; then
  echo -e "\e[92m[✓] Switched to staging via git switch\e[0m"
else
  echo -e "\e[93m[*] Falling back to git checkout staging...\e[0m"
  git checkout staging
fi
git pull --ff-only

# ─── STEP 5: Install node_modules ─────────────────────────────────────────
echo -e "\n\e[94m[Step 5/6] Installing node_modules... / กำลังติดตั้งโมดูล Node.js...\e[0m"
if [ "$MEM_GB" -lt 1 ] || [[ "$ARCH" =~ ^(arm|i686)$ ]]; then
  echo -e "\e[93m[⚙️] Low-memory/ARM detected; using optimized install..."
  echo -e "ตรวจพบหน่วยความจำต่ำ/ARM; กำลังใช้การติดตั้งแบบเหมาะสม...\e[0m"
  # only cap memory, remove unstable GC flag
  export NODE_OPTIONS="--max-old-space-size=2048"
  npm ci --no-optional
else
  npm ci
fi

# ─── STEP 6: Launch SillyTavern ───────────────────────────────────────────
echo -e "\n\e[94m[Step 6/6] Launching SillyTavern... / กำลังเปิด SillyTavern...\e[0m"
bash start.sh || {
  echo -e "\n\e[91m[!] Launch failed. Try restarting Termux and running:"
  echo -e "การเปิดโปรแกรมล้มเหลว ลองรีสตาร์ท Termux แล้วรันคำสั่ง:\e[0m"
  echo "    cd ~/SillyTavern && bash start.sh"
  exit 1
}

echo -e "\n\e[92m✅ DONE! SillyTavern (staging) is installed and running!"
echo -e "เสร็จสิ้น! SillyTavern ติดตั้งและกำลังทำงาน!\e[0m"
echo -e "\n\e[96m📘 Learn the basics here / เรียนรู้พื้นฐานได้ที่นี่:\e[0m"
echo -e "https://sillytavern.rnsv.xyz/basics/editor\n"
