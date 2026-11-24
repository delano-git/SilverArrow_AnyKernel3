#!/usr/bin/env bash
# Publish a built SilverArrow zip as a GitHub release.
#
#   ./release.sh <tag> [zip] [--draft]
#
# <tag> is the version, e.g. v1. Its notes are the "## <tag>" section of
# CHANGELOG.md plus the kernel version, checksum and install pointers. The
# zip defaults to the newest one in out/dist.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=${SILVERARROW_REPO:-delano-git/SilverArrow_AnyKernel3}

DRAFT=()
ARGS=()
for a in "$@"; do
    case $a in --draft) DRAFT=(--draft) ;; *) ARGS+=("$a") ;; esac
done
TAG=${ARGS[0]:-}
[ -n "$TAG" ] || { echo "usage: $0 <tag> [zip] [--draft]" >&2; exit 1; }
ZIP=${ARGS[1]:-$(ls -t "$HERE"/out/dist/SilverArrow-KSUN-uke-*.zip 2>/dev/null | head -1)}
[ -f "$ZIP" ] || { echo "no zip to release, run ./build.sh first" >&2; exit 1; }
KVER=$(cat "${ZIP%.zip}.kver")

CHANGES=$(awk -v t="## $TAG " 'index($0, t) == 1 {f = 1; next} /^## / {f = 0} f' "$HERE/CHANGELOG.md")
[ -n "$CHANGES" ] || { echo "no \"## $TAG\" section in CHANGELOG.md" >&2; exit 1; }

NOTES=$(mktemp)
trap 'rm -f "$NOTES"' EXIT
cat > "$NOTES" <<NOTES_EOF
$CHANGES

## Install

Flash the zip from the KernelSU / KernelSU-Next manager or from recovery. It
replaces only the kernel in the active slot's \`boot\` partition, on any ROM
with a 6.1 android14 GKI kernel (stock HyperOS, AxionOS, other GKI ROMs).
Needs an unlocked bootloader. Full steps and how to go back:
[INSTALL.md](https://github.com/$REPO/blob/$TAG/INSTALL.md)

SHA-256: \`$(cut -d' ' -f1 "$ZIP.sha256sum")\`
NOTES_EOF

gh release create "$TAG" "$ZIP" "$ZIP.sha256sum" \
    --repo "$REPO" --target "$(git -C "$HERE" rev-parse HEAD)" \
    --title "SilverArrow $TAG" --notes-file "$NOTES" "${DRAFT[@]}"
