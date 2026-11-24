### AnyKernel3 Ramdisk Mod Script
## osm0sis @ xda-developers
## SilverArrow for the Xiaomi Pad 7 (uke)

### AnyKernel setup
# global properties
properties() { '
kernel.string=SilverArrow kernel for Xiaomi Pad 7 (uke)
do.devicecheck=1
do.modules=0
do.systemless=0
do.cleanup=1
do.cleanuponabort=0
device.name1=uke
device.name2=
supported.versions=
supported.patchlevels=
supported.vendorpatchlevels=
'; } # end properties


### AnyKernel install
# boot shell variables
BLOCK=boot;
IS_SLOT_DEVICE=1;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=auto;

# import functions/variables and setup patching - see for reference (DO NOT REMOVE)
. tools/ak3-core.sh;

# boot install
# uke uses boot header v4: boot holds only the kernel, the ramdisk is in
# init_boot and the DTBs are in vendor_boot, so only swap the kernel.
split_boot;

# SilverArrow keeps the android14-6.1 GKI module interface, so it loads the
# vendor modules of any ROM whose kernel is a 6.1 android14 GKI kernel
# (stock HyperOS, AxionOS and other GKI ROMs). Refuse anything else.
old_kernel=$(strings $SPLITIMG/kernel 2>/dev/null | grep -m1 '^Linux version ');
ui_print " " "Current kernel:" "  $(echo "$old_kernel" | cut -d' ' -f3)";
case "$old_kernel" in
  "Linux version 6.1."*-android14-*) ;;
  *) abort "Not a 6.1 android14 GKI kernel. Aborting...";;
esac;

flash_boot;
## end boot install
