# Installing SilverArrow

## Before you start

- Xiaomi Pad 7 (uke) only. The installer refuses other devices.
- Bootloader unlocked.
- A ROM with a 6.1 android14 GKI kernel: stock HyperOS, AxionOS or another GKI
  ROM. The installer checks this and stops if the current kernel is anything else.
- KernelSU-Next is built in. If you rooted with a patched `init_boot` (KernelSU
  LKM, KernelSU-Next LKM or Magisk), flash your ROM's stock `init_boot` first,
  so two root solutions don't load at once.
- Keep a copy of your current `boot.img` so you can go back (see below).

## Flash from the KernelSU / KernelSU-Next manager

1. Download `SilverArrow-KSUN-uke-<date>.zip` from the
   [releases](../../releases) and check its SHA-256 against the `.sha256sum` file.
2. Open the manager, then **Install** (KernelSU) or **Flash** (KernelSU-Next),
   and pick the zip. Root apps that flash AnyKernel3 zips (e.g. Kernel Flasher)
   also work.
3. Wait for `Done!`, then reboot.

## Flash from recovery

1. Copy the zip to the tablet, or have it on the PC for sideloading.
2. Reboot to recovery (OrangeFox, TWRP or the ROM's recovery if it can flash
   zips).
3. Install the zip, or choose **Apply update > Apply from ADB** and run:

   ```bash
   adb sideload SilverArrow-KSUN-uke-<date>.zip
   ```

   Some recoveries warn that the zip's signature can't be verified. Choose
   **Yes** to continue: AnyKernel3 zips aren't signed with the ROM's keys.
4. Reboot to system.

If you flash a new ROM update in recovery, flash SilverArrow again afterwards:
the ROM update brings its own kernel.

## After booting

- **About tablet > Kernel version** shows `6.1.182-SilverArrow-...`, or run
  `adb shell uname -r`.
- Install the [KernelSU-Next manager](https://github.com/KernelSU-Next/KernelSU-Next/releases)
  to manage root.

## Going back

Flash your ROM's `boot.img` again:

```bash
fastboot flash boot boot.img
```

For stock HyperOS, `boot.img` is in the fastboot ROM's `images` folder. For
AxionOS, use the `boot.img` in the build's fastboot zip, or flash the ROM
update again.
