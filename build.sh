#!/usr/bin/env bash
# Build the SilverArrow kernel for uke and package it as an AnyKernel3 zip.
#
#   ./build.sh            build the SilverArrow branch, check KMI, make the zip
#   ./build.sh --clean    remove the kernel object dir first
#
# The kernel is built from a git worktree of the SilverArrow branch so the
# ROM tree (kernel/xiaomi/sm8635) can stay on sixteen. Config, toolchain and
# make flags follow the ROM build (device/xiaomi/uke/BoardConfig.mk and
# vendor/lineage/build/tasks/kernel.mk), so the Image matches what the ROM
# builds from the same commit.
set -euo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
TOP=${AXION_TOP:-$(cd "$HERE/.." && pwd)}
KERNEL_REPO=$TOP/kernel/xiaomi/sm8635
KERNEL_BRANCH=${KERNEL_BRANCH:-SilverArrow}
DEVICE_CONFIGS=$TOP/device/xiaomi/uke/configs/kernel
CLANG=$TOP/prebuilts/clang/host/linux-x86/clang-r563880c

OUT=$HERE/out
SRC=$OUT/src
OBJ=$OUT/obj
DIST=$OUT/dist

CONFIGS=(
    arch/arm64/configs/vendor/pineapple_GKI.config
    "$DEVICE_CONFIGS/uke_GKI.config"
    "$DEVICE_CONFIGS/uke_consolidate.config"
    "$DEVICE_CONFIGS/uke_recovered.config"
    "$DEVICE_CONFIGS/uke_perf.config"
)

KMI_REFS=("$HERE"/kmi/*.txt)

[ "${1:-}" = "--clean" ] && rm -rf "$OBJ"

RUST=$TOP/prebuilts/rust/linux-x86/1.88.0
KBT=$TOP/prebuilts/kernel-build-tools/linux-x86
SYSROOT=$TOP/prebuilts/gcc/linux-x86/host/x86_64-linux-glibc2.17-4.8/sysroot

export PATH=$TOP/prebuilts/tools-lineage/linux-x86/bin:$TOP/prebuilts/build-tools/linux-x86/bin:$CLANG/bin:$RUST/bin:$TOP/prebuilts/clang-tools/linux-x86/bin:$KBT/bin:$PATH
for d in "$KERNEL_REPO" "$CLANG" "$DEVICE_CONFIGS" "$RUST" "$KBT" "$SYSROOT"; do
    [ -d "$d" ] || { echo "missing $d" >&2; exit 1; }
done

export HIP_PATH=none PERL5LIB=$TOP/prebuilts/tools-lineage/common/perl-base

MAKE_FLAGS=(
    -j"$(nproc)" -C "$SRC" O="$OBJ" ARCH=arm64
    CC=clang LD=ld.lld AR=llvm-ar LLVM=1 LLVM_IAS=1
    HOSTCC=clang HOSTCXX=clang++ HOSTLD=ld.lld HOSTAR=llvm-ar
    HOSTCFLAGS="--sysroot=$SYSROOT -I$KBT/include"
    HOSTLDFLAGS="--sysroot=$SYSROOT -Wl,-rpath,$KBT/lib64 -L $KBT/lib64 -fuse-ld=lld --rtlib=compiler-rt"
    BRANCH=android14-6.1 KMI_GENERATION=11
    KBUILD_BUILD_USER=delano KBUILD_BUILD_HOST=axion
)
kmake() { make "${MAKE_FLAGS[@]}" "$@"; }

# Kernel source: a detached worktree at the tip of KERNEL_BRANCH
if [ ! -e "$SRC/.git" ]; then
    mkdir -p "$OUT"
    git -C "$KERNEL_REPO" worktree add --detach "$SRC" "$KERNEL_BRANCH"
else
    git -C "$SRC" checkout -q --detach "$KERNEL_BRANCH"
fi
COMMIT=$(git -C "$SRC" rev-parse --short=12 HEAD)
echo "SilverArrow: $KERNEL_BRANCH at $COMMIT"

# Config, merged the same way as the ROM build
mkdir -p "$OBJ"
cp "$SRC/arch/arm64/configs/gki_defconfig" "$OBJ/.config"
kmake olddefconfig
for c in "${CONFIGS[@]}"; do
    case $c in /*) f=$c ;; *) f=$SRC/$c ;; esac
    "$SRC/scripts/kconfig/merge_config.sh" -m -O "$OBJ" "$OBJ/.config" "$f"
    kmake olddefconfig
done
"$SRC/scripts/config" --file "$OBJ/.config" \
    -e LTO_CLANG -d LTO_NONE -e LTO_CLANG_THIN -d LTO_CLANG_FULL -e THINLTO
kmake olddefconfig

# Kernel
kmake Image
IMAGE=$OBJ/arch/arm64/boot/Image
KVER=$(cat "$OBJ/include/config/kernel.release")
echo "Built $KVER"

# The zip is only safe if every module a ROM ships still matches our CRCs
for ref in "${KMI_REFS[@]}"; do
    python3 -I "$HERE/kmi/kmi_check.py" check "$OBJ/vmlinux.symvers" "$ref" || {
        echo "KMI check failed against $(basename "$ref"): not packaging" >&2
        exit 1
    }
done

# AnyKernel3 zip
DATE=$(date +%Y%m%d)
NAME=SilverArrow-KSUN-uke-$DATE
STAGE=$OUT/stage
rm -rf "$STAGE" && mkdir -p "$STAGE" "$DIST"
cp -r "$HERE/META-INF" "$HERE/tools" "$HERE/anykernel.sh" "$HERE/LICENSE" "$STAGE/"
cp "$IMAGE" "$STAGE/Image"
printf '%s\n%s\n' "$KVER" "$KERNEL_BRANCH $COMMIT" > "$STAGE/version"
rm -f "$DIST/$NAME.zip"
(cd "$STAGE" && zip -r9q "$DIST/$NAME.zip" .)
(cd "$DIST" && sha256sum "$NAME.zip" > "$NAME.zip.sha256sum")
printf '%s\n' "$KVER" > "$DIST/$NAME.kver"
echo "$DIST/$NAME.zip"
