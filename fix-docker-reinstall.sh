#!/usr/bin/env bash
# Fix broken Docker Desktop after failed update: remove broken app and open installer.
# Your Docker config is backed up in ~/.docker/backup-before-reinstall/

set -e
ARCH=$(uname -m)
DOWNLOAD_ARM="https://desktop.docker.com/mac/main/arm64/Docker.dmg"
DOWNLOAD_INTEL="https://desktop.docker.com/mac/main/amd64/Docker.dmg"

echo "Docker Desktop reinstall helper"
echo "  - Removes broken /Applications/Docker.app"
echo "  - Opens the correct Docker.dmg download for your Mac"
echo ""

if [[ ! -d /Applications/Docker.app ]]; then
  echo "Docker.app not found in /Applications. Opening download page anyway."
  if [[ "$ARCH" == "arm64" ]]; then open "$DOWNLOAD_ARM"; else open "$DOWNLOAD_INTEL"; fi
  exit 0
fi

echo "Remove /Applications/Docker.app? (y/N)"
read -r ans
if [[ "$ans" != "y" && "$ans" != "Y" ]]; then
  echo "Skipped. To reinstall manually, see docker/DOCKER_REINSTALL_FIX.md"
  exit 0
fi

echo "Removing Docker.app..."
rm -rf /Applications/Docker.app
echo "Done. Opening Docker Desktop download..."
if [[ "$ARCH" == "arm64" ]]; then open "$DOWNLOAD_ARM"; else open "$DOWNLOAD_INTEL"; fi
echo "After installing, start Docker from Applications. Config backup: ~/.docker/backup-before-reinstall/"
