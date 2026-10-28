#!/bin/sh
# Install the Sensor Table face for Plasma 6 (current user only)
set -e
cd "$(dirname "$0")"
DEST="$HOME/.local/share/ksysguard/sensorfaces"
mkdir -p "$DEST"
rm -rf "$DEST/org.example.sensortable"
cp -r org.example.sensortable "$DEST/"
echo "Installed to $DEST/org.example.sensortable"
echo "Now restart: kquitapp6 plasmashell; kstart plasmashell"
