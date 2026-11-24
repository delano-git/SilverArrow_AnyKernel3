#!/usr/bin/env bash
# Publish a built SilverArrow zip as a GitHub release.
#
#   ./release.sh <tag> [zip] [--draft]
#
# <tag> is the version, e.g. v1. Its notes are the "## <tag>" section of
# CHANGELOG.md plus checksums and install pointers. The zip defaults to the
# newest one in out/dist. The KernelSU-Next manager is downloaded, checked
# against GitHub's digest and attached: from KernelSU-Next's "Build Manager CI"
# run KSUN_MANAGER_RUN, or from the official release KSUN_MANAGER when
# KSUN_MANAGER_RUN is empty. Running it again for an existing tag updates that
# release.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
REPO=${SILVERARROW_REPO:-delano-git/SilverArrow_AnyKernel3}
KSUN_REPO=KernelSU-Next/KernelSU-Next
# Manager for the KernelSU-Next imported into the kernel: v3.4.2 + 200 dev
# commits (32e25d58), which raise KERNEL_SU_UAPI_VERSION to 6. The v3.4.2
# release manager only speaks UAPI 5, so take the manager KernelSU-Next's CI
# built from that commit (versionCode 33555, signed with the release key).
KSUN_MANAGER_RUN=${KSUN_MANAGER_RUN-44888862619}
KSUN_MANAGER=${KSUN_MANAGER:-v3.4.2}

DRAFT=()
ARGS=()
for a in "$@"; do
    case $a in --draft) DRAFT=(--draft) ;; *) ARGS+=("$a") ;; esac
done
TAG=${ARGS[0]:-}
[ -n "$TAG" ] || { echo "usage: $0 <tag> [zip] [--draft]" >&2; exit 1; }
ZIP=${ARGS[1]:-$(ls -t "$HERE"/out/dist/SilverArrow-KSUN-SUSFS-uke-*.zip 2>/dev/null | head -1)}
[ -f "$ZIP" ] || { echo "no zip to release, run ./build.sh first" >&2; exit 1; }

# KernelSU-Next manager, the plain (not spoofed) APK
if [ -n "$KSUN_MANAGER_RUN" ]; then
    MGR_DIR=$HERE/out/manager/run-$KSUN_MANAGER_RUN
    MGR_URL=https://github.com/$KSUN_REPO/actions/runs/$KSUN_MANAGER_RUN
    MGR_FROM="KernelSU-Next's [Build Manager CI run]($MGR_URL) for the imported commit"
    mkdir -p "$MGR_DIR"
    ART=$(gh api "repos/$KSUN_REPO/actions/runs/$KSUN_MANAGER_RUN/artifacts" \
        -q '.artifacts[] | select(.name == "manager") | "\(.id) \(.digest)"')
    [ -n "$ART" ] || { echo "no manager artifact in run $KSUN_MANAGER_RUN" >&2; exit 1; }
    ART_ID=${ART%% *}; WANT=${ART#* }; WANT=${WANT#sha256:}
    ART_ZIP=$MGR_DIR/manager.zip
    [ -f "$ART_ZIP" ] || gh api "repos/$KSUN_REPO/actions/artifacts/$ART_ID/zip" > "$ART_ZIP"
    [ "$(sha256sum "$ART_ZIP" | cut -d' ' -f1)" = "$WANT" ] || { echo "manager artifact does not match GitHub's digest" >&2; exit 1; }
    APK_NAME=$(unzip -Z1 "$ART_ZIP" | grep -m1 '^KernelSU_Next_.*-release\.apk$')
    unzip -o -q "$ART_ZIP" "$APK_NAME" -d "$MGR_DIR"
else
    MGR_DIR=$HERE/out/manager/$KSUN_MANAGER
    MGR_FROM="the official [$KSUN_MANAGER](https://github.com/$KSUN_REPO/releases/tag/$KSUN_MANAGER) release"
    mkdir -p "$MGR_DIR"
    APK_NAME=$(gh release view "$KSUN_MANAGER" --repo "$KSUN_REPO" --json assets \
        -q '.assets[].name | select(test("^KernelSU_Next_.*-release\\.apk$")) | select(test("spoofed") | not)')
    [ -f "$MGR_DIR/$APK_NAME" ] || gh release download "$KSUN_MANAGER" --repo "$KSUN_REPO" -p "$APK_NAME" -D "$MGR_DIR"
    WANT=$(gh api "repos/$KSUN_REPO/releases/tags/$KSUN_MANAGER" \
        -q ".assets[] | select(.name == \"$APK_NAME\") | .digest" | sed 's/^sha256://')
fi
APK=$MGR_DIR/$APK_NAME
(cd "$MGR_DIR" && sha256sum "$APK_NAME" > "$APK_NAME.sha256sum")
[ -n "$KSUN_MANAGER_RUN" ] || [ "$(cut -d' ' -f1 "$APK.sha256sum")" = "$WANT" ] || { echo "$APK_NAME does not match GitHub's digest" >&2; exit 1; }

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

Install the KernelSU-Next manager attached here (\`$APK_NAME\`, from
$MGR_FROM, signed with KernelSU-Next's release key) to manage root. The
kernel needs a manager that supports KernelSU UAPI 6: the v3.4.2 release
manager doesn't.

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
