#!/usr/bin/env bash
set -e

echo -e "\n--- Node version ---"
node -v

echo -e "\n--- NPM version ---"
npm -v

echo -e "\n--- Free memory (in MB) ---"
free -m

echo -e "\n--- Termux info ---"
termux-info

echo -e "\n--- Disk space for home directory ---"
df -h ~/

echo -e "\n--- End of check ---"
