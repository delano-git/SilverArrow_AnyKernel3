# SilverArrow for Xiaomi Pad 7 (uke)

SilverArrow is a performance and battery kernel for the Xiaomi Pad 7 (uke)
with KernelSU-Next built in. It's released as an AnyKernel3 zip that can be
flashed from recovery or from the KernelSU / KernelSU-Next manager.

The zip replaces only the kernel in the active slot's `boot` partition.
On uke, `boot` holds just the kernel (boot header v4): the ramdisk is in
`init_boot` and the DTBs and first-stage modules are in `vendor_boot`.

## Which ROMs it works on

SilverArrow keeps the android14-6.1 GKI module interface (KMI generation 11),
so it loads the modules any GKI ROM already ships. The installer checks that
the device is `uke` and that the kernel being replaced is a `6.1.x-android14`
GKI kernel, and stops otherwise.

Every build is checked against the kernel symbols that stock HyperOS
OS3.0.304.0.WOZMIXM's 788 modules import (`kmi/`). If a symbol's CRC changes
or goes missing, `build.sh` stops before packaging.

An unlocked bootloader is required. If a KernelSU LKM-patched `init_boot` is
installed, restore the stock `init_boot` first: KernelSU-Next is already in
this kernel.

## Building

The kernel source and config come from the AxionOS tree this repo lives in
(`kernel/xiaomi/sm8635` on the `SilverArrow` branch,
`device/xiaomi/uke/configs/kernel`, and `prebuilts/clang` r563880c).

```bash
./build.sh            # kernel + KMI check + out/dist/SilverArrow-KSUN-uke-<date>.zip
./build.sh --clean    # same, from an empty object dir
./release.sh          # draft GitHub release with the newest zip
```

`build.sh` builds from a git worktree at `out/src`, so the ROM tree can stay
on `sixteen`.

To add another ROM's modules to the KMI check:

```bash
kmi/kmi_check.py dump kmi/<rom>.txt <extracted vendor_boot> <vendor_dlkm> <system_dlkm>
```

## Credits

AnyKernel3 by osm0sis (see `AnyKernel3.md`), KernelSU-Next.
