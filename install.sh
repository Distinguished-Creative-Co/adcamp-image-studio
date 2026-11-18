#!/bin/bash
# Install AdCamp Image Studio as a Claude skill on this Mac.
#   bash install.sh
# It copies the skill, its helper and the look picker into ~/.claude/skills/image-studio.
# It downloads nothing and changes nothing else. Run it again to update.
set -euo pipefail
SRC="$(cd "$(dirname "$0")" && pwd)"
DST="$HOME/.claude/skills/image-studio"
[ "$(uname)" = "Darwin" ] || { echo "FAIL: Image Studio is for Mac only right now."; exit 1; }
[ -s "$SRC/skills/image-studio/SKILL.md" ] && [ -s "$SRC/tools/studio.sh" ] && [ -d "$SRC/picker/samples" ] || { echo "FAIL: this folder is not a full copy of Image Studio."; exit 1; }
mkdir -p "$DST/tools" "$DST/picker/samples"
cp "$SRC/skills/image-studio/SKILL.md" "$DST/SKILL.md"
cp "$SRC/tools/studio.sh" "$DST/tools/studio.sh"
cp "$SRC/picker/picker.html" "$DST/picker/picker.html"
cp "$SRC"/picker/samples/*.jpg "$DST/picker/samples/"
cp "$SRC/VERSION" "$DST/VERSION"
chmod +x "$DST/tools/studio.sh"
echo "OK: AdCamp Image Studio $(cat "$DST/VERSION") is installed."
echo "Next: start a new chat and say: Set up Image Studio"
