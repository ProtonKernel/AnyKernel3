### AnyKernel3 Ramdisk Mod Script
## osm0sis @ xda-developers

### AnyKernel setup
# global properties
properties() { '
kernel.string=Proton+ Kernel (Exynos 2100)
do.devicecheck=1
do.modules=0
do.systemless=1
do.cleanup=1
do.cleanuponabort=0
device.name1=r9s
device.name2=o1s
device.name3=p3s
device.name4=t2s
supported.versions=
supported.patchlevels=
supported.vendorpatchlevels=
'; } # end properties


### AnyKernel install
## boot files attributes
boot_attributes() {
set_perm_recursive 0 0 755 644 $RAMDISK/*;
set_perm_recursive 0 0 750 750 $RAMDISK/init* $RAMDISK/sbin;
} # end attributes

# boot shell variables
BLOCK=/dev/block/by-name/boot;
IS_SLOT_DEVICE=0;
RAMDISK_COMPRESSION=auto;
PATCH_VBMETA_FLAG=auto;

# import functions/variables and setup patching - see for reference (DO NOT REMOVE)
. tools/ak3-core.sh;

# Detect Android release and patch kernel cmdline default if needed
ui_print "Detecting Android release for uname_bpf_spoof patch..."

if [ -f /system/build.prop ]; then
  android_release="$(file_getprop /system/build.prop ro.build.version.release)"
  android_sdk="$(file_getprop /system/build.prop ro.build.version.sdk)"
elif [ -f /system_root/system/build.prop ]; then
  android_release="$(file_getprop /system_root/system/build.prop ro.build.version.release)"
  android_sdk="$(file_getprop /system_root/system/build.prop ro.build.version.sdk)"
else
  mount -o ro /system_root 2>/dev/null || mount -o ro /dev/block/mapper/system /system_root 2>/dev/null
  if [ -f /system_root/system/build.prop ]; then
    android_release="$(file_getprop /system_root/system/build.prop ro.build.version.release)"
    android_sdk="$(file_getprop /system_root/system/build.prop ro.build.version.sdk)"
  fi
fi

# Normalize and decide using release major or SDK fallback
android_major="${android_release%%.*}"
patch_needed=0
if [ -n "$android_major" ] && echo "$android_major" | grep -Eq '^[0-9]+$'; then
  if [ "$android_major" -ge 16 ]; then
    patch_needed=1
  fi
else
  # Fallback: if sdk is available and numeric, treat SDK >= 36 as Android 16+
  if echo "$android_sdk" | grep -Eq '^[0-9]+$' && [ "$android_sdk" -ge 36 ]; then
    patch_needed=1
  fi
fi

if [ "$patch_needed" -eq 1 ]; then
  ui_print "=> Detected Android >=16 (release: $android_release, sdk: $android_sdk). Enabling uname spoof."

  old_hex="756e616d655f6270665f73706f6f663d30"  # "uname_bpf_spoof=0"
  new_hex="756e616d655f6270665f73706f6f663d31"  # "uname_bpf_spoof=1"

  $BIN/magiskboot hexpatch $AKHOME/Image "$old_hex" "$new_hex"

  if [ $? -eq 0 ]; then
    ui_print "Kernel successfully patched to enable uname_bpf_spoof."
  else
    # if hexpatch failed, check if already patched
    if hexdump -C $AKHOME/Image 2>/dev/null | grep -qi "$new_hex" 2>/dev/null; then
      ui_print "Kernel already has uname_bpf_spoof=1 set."
    else
      ui_print "Warning: uname_bpf_spoof patch failed or string not present in Image. Skipping."
    fi
  fi
else
  ui_print "=> Skipping uname spoof patch (release: $android_release, sdk: $android_sdk)."
fi

# boot install
split_boot; # use split_boot to skip ramdisk unpack, e.g. for devices with init_boot ramdisk

flash_boot; # use flash_boot to skip ramdisk repack, e.g. for devices with init_boot ramdisk
## end boot install

flash_generic vendor_boot;
