
# 🚀 SillyTavern Auto-Installer for Termux (STAGING)

**One-line installer for SillyTavern on Android Termux**, with staging branch, color logging, and zero brainpower required.

> Made for the Thai SillyTavern community — perfect for users who hate reading or just want things to *work*.

---

## 📋 Table of Contents
1. [About](#about)  
2. [Requirements](#requirements)  
3. [Quickstart](#quickstart)  
4. [Manual Usage](#manual-usage)  
5. [Troubleshooting](#troubleshooting)  
6. [Credits](#credits)  
7. [License](#license)

---

## 🧠 About

This script automates setting up **SillyTavern** on Termux:

- Updates Termux  
- Installs `nodejs`, `git`, `esbuild`  
- Clones repository  
- Switches to `staging` branch  
- Installs dependencies  
- Launches the app  
- Shows doc link for editor basics 😎

---

## 🟢 Requirements

**If you get errors like**  

bash: not found
curl: not found

**run this first in Termux:**

```bash
pkg update && pkg install -y curl bash
```

⸻

🚀 Quickstart

Paste this in Termux:
```bash
curl -sL https://raw.githubusercontent.com/Rawi1005/st-autoinstall/main/install.sh | bash
```
Sit back and watch it do everything. When it’s done:
```bash
✅ DONE! SillyTavern (staging) is installed and running!

📘 Read this doc to learn the basics:
https://sillytavern.rnsv.xyz/editor
```

---
🙌 Credits

Created by Rane

