# Changelog

## v1 (2026-11-24)

First standalone release of SilverArrow for the Xiaomi Pad 7 (uke).

Kernel `6.1.182-SilverArrow-android14-11-14485-gd153dc47cbdb`

- Linux 6.1.182 from Android's `android14-6.1-lts` branch (stock HyperOS ships 6.1.138)
- Qualcomm `KERNEL.PLATFORM.3.0.r1-13600` merged
- KernelSU-Next v3.4.2 (version 33555) built in. No `init_boot` patching or LKM needed
- SUSFS v2.4.0 built in, with all its features on. KernelSU-Next's separate
  SUSFS module isn't needed and won't load
- Built with clang 21, ThinLTO and `-O3`
- BBR TCP congestion control as the default
- New `pm_async=off` boot parameter to turn off asynchronous suspend/resume
- Xiaomi's MIHW powersave, perf_helper, NTAG (FM19511) and charger_partition drivers from the uke kernel source
- Production builds: PMIC GLINK client, PM advanced and CIFS debug turned off
- Keeps the android14-6.1 GKI module interface, so it loads the modules stock
  HyperOS OS3.0.304.0 and other GKI ROMs ship (all 3612 kernel symbols checked)
- AnyKernel3 installer that replaces only the kernel in the active slot's `boot`
  (with arm64 busybox and magiskboot from Magisk v31.1: uke can't run
  AnyKernel3's 32-bit tools)
- KernelSU-Next manager v3.4.2 (official build) attached to the release
