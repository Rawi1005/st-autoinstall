# 🚀 SillyTavern Auto-Installer for Termux (STAGING)

Install **SillyTavern** (staging branch) on Android with Termux in one step—no experience needed!

---

## 📋 What Does This Script Do?

- Updates Termux
- Installs required packages: `nodejs`, `git`, `esbuild`
- Downloads SillyTavern (staging branch)
- Installs all dependencies
- Starts SillyTavern automatically
- Links you to a quick-start guide

---

## 🟢 Requirements

**If you see errors like:**
- `bash: not found`
- `curl: not found`

**Use Termux from [F-Droid](https://f-droid.org/packages/com.termux/) or [GitHub](https://github.com/termux/termux-app/releases).**
The old Google Play version uses shut-down package repos (errors mentioning `bintray.com` or `termux-packages-24`), and installs will fail.

Run this in Termux first:
```bash
pkg update && pkg install -y curl bash
```

---

## 🚀 Quick Install

Copy and paste this command into Termux:
```bash
curl -sL https://raw.githubusercontent.com/Rawi1005/st-autoinstall/main/install.sh | bash
```
Sit back and let it finish.  
SillyTavern will start automatically when done!

---

## 📘 Learn the Basics

Check out the basics here:  
[https://sillytavern.rnsv.xyz/editor](https://sillytavern.rnsv.xyz/basics/editor)

---

## 🙌 Credits

Made by Rane  

---
