#!/usr/bin/env bash
# Publish a built SilverArrow zip as a GitHub release.
#
#   ./release.sh <tag> [zip] [--draft]
#
# <tag> is the version, e.g. v1. Its notes are the "## <tag>" section of
# CHANGELOG.md plus checksums and install pointers. The zip defaults to the
# newest one in out/dist. The KernelSU-Next manager from the official release
# KSUN_MANAGER (default below) is downloaded, checked against GitHub's digest
# and attached. Running it again for an existing tag updates that release.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=${SILVERARROW_REPO:-delano-git/SilverArrow_AnyKernel3}
KSUN_REPO=KernelSU-Next/KernelSU-Next
# Manager for the KernelSU-Next imported into the kernel (v3.4.2 + dev commits
# that only add new supercalls, so the v3.4.2 manager works with it)
KSUN_MANAGER=${KSUN_MANAGER:-v3.4.2}

DRAFT=()
ARGS=()
for a in "$@"; do
    case $a in --draft) DRAFT=(--draft) ;; *) ARGS+=("$a") ;; esac
done
TAG=${ARGS[0]:-}
[ -n "$TAG" ] || { echo "usage: $0 <tag> [zip] [--draft]" >&2; exit 1; }
ZIP=${ARGS[1]:-$(ls -t "$HERE"/out/dist/SilverArrow-KSUN-uke-*.zip 2>/dev/null | head -1)}
[ -f "$ZIP" ] || { echo "no zip to release, run ./build.sh first" >&2; exit 1; }

# KernelSU-Next manager, the plain (not spoofed) release APK
MGR_DIR=$HERE/out/manager/$KSUN_MANAGER
mkdir -p "$MGR_DIR"
APK_NAME=$(gh release view "$KSUN_MANAGER" --repo "$KSUN_REPO" --json assets \
    -q '.assets[].name | select(test("^KernelSU_Next_.*-release\\.apk$")) | select(test("spoofed") | not)')
APK=$MGR_DIR/$APK_NAME
[ -f "$APK" ] || gh release download "$KSUN_MANAGER" --repo "$KSUN_REPO" -p "$APK_NAME" -D "$MGR_DIR"
WANT=$(gh api "repos/$KSUN_REPO/releases/tags/$KSUN_MANAGER" \
    -q ".assets[] | select(.name == \"$APK_NAME\") | .digest" | sed 's/^sha256://')
(cd "$MGR_DIR" && sha256sum "$APK_NAME" > "$APK_NAME.sha256sum")
[ "$(cut -d' ' -f1 "$APK.sha256sum")" = "$WANT" ] || { echo "$APK_NAME does not match GitHub's digest" >&2; exit 1; }

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

Install the KernelSU-Next manager (\`$APK_NAME\`, the official
[$KSUN_MANAGER](https://github.com/$KSUN_REPO/releases/tag/$KSUN_MANAGER) release,
attached here) to manage root.

## SHA-256

- \`$(basename "$ZIP")\`: \`$(cut -d' ' -f1 "$ZIP.sha256sum")\`
- \`$APK_NAME\`: \`$(cut -d' ' -f1 "$APK.sha256sum")\`
NOTES_EOF

FILES=("$ZIP" "$ZIP.sha256sum" "$APK" "$APK.sha256sum")
if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
    gh release upload "$TAG" "${FILES[@]}" --repo "$REPO" --clobber
    gh release edit "$TAG" --repo "$REPO" --title "SilverArrow $TAG" --notes-file "$NOTES"
    gh release view "$TAG" --repo "$REPO" --json url -q .url
else
    gh release create "$TAG" "${FILES[@]}" \
        --repo "$REPO" --target "$(git -C "$HERE" rev-parse HEAD)" \
        --title "SilverArrow $TAG" --notes-file "$NOTES" "${DRAFT[@]}"
fi
