#!/data/data/com.termux/files/usr/bin/bash
set -e

echo -e "\e[92m=============================="
echo -e " AUTO INSTALL ST.  V1.0 🚀"
echo -e "==============================\e[0m"

# STEP 1: Update Termux
echo -e "\n\e[94m[Step 1/6] Updating Termux...\e[0m"
apt update -y && apt upgrade -y

# STEP 2: Install dependencies
echo -e "\n\e[94m[Step 2/6] Installing required packages (nodejs, git, esbuild)...\e[0m"
pkg install -y nodejs git esbuild

# STEP 3: Clone SillyTavern
echo -e "\n\e[94m[Step 3/6] Cloning SillyTavern repository...\e[0m"
cd ~
[ -d SillyTavern ] && rm -rf SillyTavern
git clone https://github.com/SillyTavern/SillyTavern
cd SillyTavern

# STEP 4: Switch to staging branch
echo -e "\n\e[94m[Step 4/6] Switching to 'staging' branch...\e[0m"
git fetch
if git switch staging 2>/dev/null; then
  echo -e "\e[92m[✓] Switched to staging using 'git switch'\e[0m"
else
  echo -e "\e[93m[*] 'git switch' not available, using 'git checkout'...\e[0m"
  git checkout staging
fi
git pull

# STEP 5: Install node_modules
echo -e "\n\e[94m[Step 5/6] Installing node_modules...\e[0m"
npm install

# STEP 6: Run SillyTavern
echo -e "\n\e[94m[Step 6/6] Launching SillyTavern...\e[0m"
bash start.sh || {
  echo -e "\n\e[91m[!] Launch failed. Try restarting Termux and running:\e[0m"
  echo "cd ~/SillyTavern && bash start.sh"
  exit 1
}

# Final message
echo -e "\n\e[92m✅ DONE! SillyTavern (staging) is installed and running!\e[0m"
echo -e "\n\e[96m📘 Read this doc to learn the basics:\e[0m"
echo -e "https://sillytavern.rnsv.xyz/basics/editor\n"
