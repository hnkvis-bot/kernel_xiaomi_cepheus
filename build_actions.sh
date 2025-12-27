#!/bin/bash
set -ex

# Force script to run from the directory where THIS script lives
cd "$(dirname "$0")"

# Verify that the top-level kernel Makefile exists here
if [ ! -f Makefile ] || [ ! -d arch ]; then
    echo "ERROR: This directory does not contain the kernel source tree."
    echo "Expected to find Makefile and arch/ here."
    exit 1
fi

echo ">>> Using kernel root: $PWD"

# -----------------------------
# CONFIG
# -----------------------------
TIMESTAMP=$(date +"%Y%m%d_%H%M")
KERNEL_DEFCONFIG=cepheus_defconfig
ANYKERNEL3_DIR=$PWD/AnyKernel3
FINAL_KERNEL_ZIP="InfiniR_cepheus_v1.39_HNKSUN-${TIMESTAMP}.zip"

# -----------------------------
# TOOLCHAIN (system LLVM/Clang)
# -----------------------------
export ARCH=arm64
export SUBARCH=arm64
export LLVM=1
export CC=clang
export LD=ld.lld
export AR=llvm-ar
export NM=llvm-nm
export OBJCOPY=llvm-objcopy
export OBJDUMP=llvm-objdump
export STRIP=llvm-strip
export CROSS_COMPILE=aarch64-linux-gnu-

# -----------------------------
# CLEAN + DEFCONFIG
# -----------------------------
echo ">>> Running defconfig"
rm -rf out && mkdir out
make ARCH=arm64 O=out mrproper
make ARCH=arm64 O=out $KERNEL_DEFCONFIG

START=$(date +"%s")

# -----------------------------
# BUILD
# -----------------------------
echo ">>> Building kernel"
make -j"$(nproc --all)" \
    O=out \
    CC=clang \
    LD=ld.lld \
    AR=llvm-ar \
    NM=llvm-nm \
    OBJCOPY=llvm-objcopy \
    OBJDUMP=llvm-objdump \
    STRIP=llvm-strip

# -----------------------------
# VERIFY OUTPUT
# -----------------------------
IMG=out/arch/arm64/boot/Image.gz-dtb

if [ ! -f "$IMG" ]; then
    echo "ERROR: Image.gz-dtb not found!"
    exit 1
fi

echo ">>> Kernel image found: $IMG"

# -----------------------------
# ANYKERNEL3 PACKAGING
# -----------------------------
echo ">>> Preparing AnyKernel3"
rm -f "$ANYKERNEL3_DIR/Image.gz-dtb"
rm -f "$ANYKERNEL3_DIR/$FINAL_KERNEL_ZIP"

cp "$IMG" "$ANYKERNEL3_DIR/"

echo ">>> Creating flashable zip"
cd "$ANYKERNEL3_DIR"
zip -r9 "$FINAL_KERNEL_ZIP" . -x README "$FINAL_KERNEL_ZIP"

# Copy zip to repo root for GitHub Actions
cp "$FINAL_KERNEL_ZIP" "$PWD/.."

cd ..

# -----------------------------
# CLEANUP
# -----------------------------
rm -f "$ANYKERNEL3_DIR/Image.gz-dtb"
rm -f "$ANYKERNEL3_DIR/$FINAL_KERNEL_ZIP"

END=$(date +"%s")
DIFF=$((END - START))

echo "Kernel compiled successfully in $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds"
echo "SHA1:"
sha1sum "$FINAL_KERNEL_ZIP"
