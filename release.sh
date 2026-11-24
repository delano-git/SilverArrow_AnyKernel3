#!/usr/bin/env bash
# Publish a built SilverArrow zip as a GitHub release.
#
#   ./release.sh [out/dist/SilverArrow-KSUN-uke-<date>.zip] [notes.md]
#
# Defaults to the newest zip in out/dist. The release is created as a draft;
# check it on GitHub and publish it from there.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=${SILVERARROW_REPO:-delano-git/SilverArrow_AnyKernel3}

ZIP=${1:-$(ls -t "$HERE"/out/dist/SilverArrow-KSUN-uke-*.zip 2>/dev/null | head -1)}
[ -f "$ZIP" ] || { echo "no zip to release, run ./build.sh first" >&2; exit 1; }
NAME=$(basename "$ZIP" .zip)
KVER=$(cat "${ZIP%.zip}.kver")
TAG=${NAME#SilverArrow-KSUN-uke-}

NOTES=${2:-}
if [ -z "$NOTES" ]; then
    NOTES=$(mktemp)
    cat > "$NOTES" <<EOF
SilverArrow kernel for the Xiaomi Pad 7 (uke), with KernelSU-Next built in.

Kernel: \`$KVER\`

Flash from recovery or the KernelSU / KernelSU-Next manager. It replaces only
the kernel in the active slot's boot partition and works on any ROM with a 6.1
android14 GKI kernel (stock HyperOS, AxionOS, other GKI ROMs). Needs an
unlocked bootloader.

SHA-256: \`$(cut -d' ' -f1 "$ZIP.sha256sum")\`
EOF
fi

gh release create "$TAG" "$ZIP" "$ZIP.sha256sum" \
    --repo "$REPO" --draft --title "SilverArrow $TAG" --notes-file "$NOTES"
