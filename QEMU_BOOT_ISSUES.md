# QEMU Boot Issues - NTARIOS Testing

**Date:** February 17, 2026
**Status:** Unresolved - Emergency Shell on Boot

---

## Summary

NTARIOS ISO builds successfully (906MB) but fails to boot in QEMU, dropping to an initramfs emergency recovery shell with the error:
```
Mounting boot media failed.
initramfs emergency recovery shell launched. Type 'exit' to continue boot
sh: can't access tty; job control turned off
```

---

## System Information

- **Host OS:** Windows
- **QEMU Version:** 10.2.0
- **Docker:** 29.2.0
- **Alpine Linux Base:** 3.19.9
- **Build System:** Docker-based Alpine build environment

---

## Build Process

### Successful Steps:
1. ✅ Docker image built (`ntari-builder`)
2. ✅ Base Alpine minirootfs downloaded (3.19.0)
3. ✅ Packages installed (388 packages, 2.4GB total)
4. ✅ SquashFS root filesystem created (868.3MB compressed)
5. ✅ Kernel and initramfs copied to ISO
6. ✅ GRUB bootloader installed (with grub-bios)
7. ✅ ISO image created successfully

### ISO Details:
- **Name:** `ntari-server-alpine-style.iso`
- **Size:** ~906MB
- **Format:** ISO9660 with El Torito boot
- **Bootloader:** GRUB 2.06
- **Kernel:** vmlinuz-lts (6.6.117-0-lts)
- **Initramfs:** initramfs-lts (18MB)
- **Root FS:** /ntari/rootfs.squashfs (868MB SquashFS)

---

## Boot Attempts and Results

### Attempt 1: Initial GRUB Config
**GRUB Boot Parameters:**
```
linux /boot/vmlinuz modules=loop,squashfs,sd-mod,usb-storage quiet
initrd /boot/initramfs
```

**Result:** ❌ Emergency shell - "Mounting boot media failed"

**Issue:** Alpine's initramfs doesn't know where to find the root filesystem

---

### Attempt 2: Added modloop Parameter
**GRUB Boot Parameters:**
```
linux /boot/vmlinuz modules=loop,squashfs,sd-mod,usb-storage modloop=/ntari/rootfs.squashfs quiet
```

**Result:** ❌ Emergency shell - Same error

**Issue:** `modloop` is for kernel modules, not root filesystem

---

### Attempt 3: Alpine-style Parameters
**GRUB Boot Parameters:**
```
linux /boot/vmlinuz modules=loop,squashfs,sd-mod,usb-storage alpine_dev=cdrom:iso9660 alpine_root=/ntari/rootfs.squashfs quiet
```

**Result:** ❌ Emergency shell - Same error

**Issue:** Parameters don't match Alpine's actual initramfs expectations

---

### Attempt 4: Direct Root Mount
**GRUB Boot Parameters:**
```
linux /boot/vmlinuz root=/dev/sr0 rootfstype=iso9660 init=/bin/sh quiet
```

**Result:** ❌ Emergency shell - Same error

**Issue:** Trying to use ISO filesystem as root doesn't work

---

### Attempt 5: Exact Alpine Boot Parameters (Current)
**Analysis:** Booted official Alpine ISO successfully in QEMU to study structure

**Alpine's Boot Command Line:**
```
BOOT_IMAGE=/boot/vmlinuz-lts modules=loop,squashfs,sd-mod,usb-storage quiet initrd=/boot/initramfs-lts
```

**Alpine's ISO Structure:**
```
/media/cdrom/
  ├── .alpine-release
  ├── apks/           # Alpine package repository
  ├── boot/
  │   ├── vmlinuz-lts
  │   └── initramfs-lts
  └── efi/
```

**Key Finding:** Alpine does NOT use a SquashFS root filesystem for Live CDs!

**NTARI's GRUB Config (Matching Alpine):**
```
linux /boot/vmlinuz modules=loop,squashfs,sd-mod,usb-storage quiet
initrd /boot/initramfs
```

**Result:** ❌ Emergency shell - Still fails

**Root Cause:** Alpine's initramfs expects either:
- Package-based boot with `/apks` directory
- Overlay-based boot with `.apkovl.tar.gz`
- NOT a custom SquashFS root filesystem

---

## Root Cause Analysis

### The Fundamental Problem:

NTARIOS uses a **custom boot structure** that doesn't match Alpine's expected Live CD layout:

**NTARI Structure:**
```
iso-server/
  ├── boot/
  │   ├── grub/
  │   ├── vmlinuz
  │   └── initramfs
  └── ntari/
      └── rootfs.squashfs  # Custom SquashFS root
```

**Alpine Structure:**
```
cdrom/
  ├── boot/
  ├── apks/              # Package repository
  └── .alpine-release
```

### Why It Fails:

1. **Alpine's initramfs boot process:**
   - Mounts CD-ROM at `/media/cdrom`
   - Looks for `/apks` directory or `.apkovl.tar.gz`
   - Expects to build system from packages, not mount a pre-built root
   - Doesn't know how to handle custom SquashFS at `/ntari/rootfs.squashfs`

2. **No custom init hooks:**
   - Our initramfs is stock Alpine
   - It has no instructions for mounting our custom SquashFS
   - It fails and drops to emergency shell

3. **Architectural mismatch:**
   - We're trying to use Alpine's bootloader with a custom structure
   - Alpine's tools expect Alpine's conventions

---

## Comparison: Alpine Official ISO vs NTARIOS

| Aspect | Alpine Official | NTARIOS |
|--------|----------------|---------|
| **Boot method** | Package-based | SquashFS root |
| **Root FS** | Built at runtime from `/apks` | Pre-built SquashFS |
| **Initramfs** | Stock Alpine | Stock Alpine |
| **CD-ROM mount** | `/media/cdrom` | Expected at `/media/cdrom` |
| **Root location** | N/A (built dynamically) | `/ntari/rootfs.squashfs` |
| **Boot params** | `modules=...` only | `modules=...` + custom params needed |
| **Works in QEMU** | ✅ Yes | ❌ No |

---

## Attempted Solutions

### What We Tried:
1. ✅ Different GRUB boot parameters (5 variations)
2. ✅ Installing grub-bios for proper BIOS support
3. ✅ Matching Alpine's exact boot parameters
4. ✅ Testing official Alpine ISO (worked perfectly)
5. ❌ Custom initramfs hooks (not attempted - too complex)
6. ❌ Converting to Alpine's package-based structure (not attempted)

---

## Possible Solutions

### Option 1: Custom Initramfs (Complex - 30+ min)
**Approach:** Modify initramfs to mount our SquashFS
- Extract initramfs
- Add custom init script to mount `/ntari/rootfs.squashfs` as root
- Repack initramfs
- Rebuild ISO

**Pros:** Keeps our SquashFS structure
**Cons:** Complex, error-prone, non-standard

---

### Option 2: Use Alpine's Standard Method (Medium - 20-30 min)
**Approach:** Convert to Alpine Live CD structure
- Create `/apks` directory with packages
- Use Alpine's overlay system
- Let Alpine boot normally, install NTARI at runtime

**Pros:** Works with standard Alpine tools
**Cons:** Different architecture than planned

---

### Option 3: Try VirtualBox (Quick - 5 min)
**Approach:** Test in VirtualBox instead of QEMU
- Different BIOS implementation
- Might handle boot differently
- Could work without changes

**Pros:** Quick to test, minimal changes
**Cons:** Might have same issue (unknown)

---

### Option 4: Use Different Bootloader (Medium - 15-20 min)
**Approach:** Switch from GRUB to SYSLINUX (like Alpine uses)
- SYSLINUX might be more flexible
- Matches Alpine's actual bootloader
- Could pass different parameters

**Pros:** More control over boot process
**Cons:** Requires understanding SYSLINUX config

---

### Option 5: Build Proper Live CD System (Long - 2-3 hours)
**Approach:** Use `alpine-make-vm-image` or similar tools
- Build proper Alpine Live CD structure
- Customize properly with NTARI components
- Follow Alpine's official build process

**Pros:** Proper, maintainable solution
**Cons:** Time-consuming, requires learning Alpine's build system

---

## Next Steps

### Immediate:
- **Test in VirtualBox** (Option 3) - Quick validation
- Different BIOS might work without changes

### If VirtualBox Fails:
- **Option 2:** Convert to Alpine package-based structure
- **Option 4:** Try SYSLINUX bootloader
- **Option 1:** Custom initramfs (last resort)

### Long-term:
- Study Alpine's `alpine-make-vm-image` tool
- Build proper Live CD infrastructure
- Document NTARIOS-specific boot process

---

## Lessons Learned

1. **Standard conventions matter:** Fighting against Alpine's expected structure causes problems
2. **Test early:** Should have tested boot before full package installation
3. **Study references:** Official Alpine ISO structure was critical to understanding
4. **QEMU is strict:** Different VMs might have different tolerances
5. **Initramfs is key:** The initramfs dictates early boot behavior

---

## Files Modified

### GRUB Config:
- `ntari-os/build/build-output/iso-server/boot/grub/grub.cfg`
- Modified 5 times with different boot parameters

### Build Scripts:
- `ntari-os/build/build-iso.sh` - Fixed wget compatibility
- `ntari-os/build/build-output/Dockerfile` - Added sudo package
- `ntari-os/build/docker-build.sh` - Fixed Windows path handling
- `build-quick.ps1` - Created for Windows builds

### Package Lists:
- `packages-server.txt` - Removed unavailable packages (lynis, nss-mdns)

---

## ISOs Created

All stored in: `ntari-os/build/build-output/`

1. `ntari-server-1.0.0-20260217.iso` (906MB) - Initial, no BIOS boot
2. `ntari-server-fixed.iso` (906MB) - Added BIOS boot
3. `ntari-server-bios.iso` (906MB) - With grub-bios
4. `ntari-server-working.iso` (906MB) - With modloop param
5. `ntari-server-v2.iso` (906MB) - With alpine_dev param
6. `ntari-server-alpine-style.iso` (906MB) - Current, matches Alpine params
7. `alpine-reference.iso` (207MB) - Official Alpine for reference

**Current Status:** All fail at boot with same emergency shell error

---

## Technical Details

### Error Message:
```
Mounting boot media failed.
initramfs emergency recovery shell launched. Type 'exit' to continue boot
sh: can't access tty; job control turned off
```

### What This Means:
- Initramfs successfully loaded
- Kernel started
- Initial modules loaded
- CD-ROM device detected (`/dev/sr0`)
- BUT: Initramfs doesn't know how to proceed
- No valid root filesystem found in expected location
- Drops to emergency shell for manual recovery

### Mount Status at Emergency Shell:
- `/dev/sr0` is available (CD-ROM device exists)
- ISO9660 filesystem readable
- Files accessible on CD if manually mounted
- Problem is AUTOMATIC mounting/boot process

---

## References

- Alpine Linux Documentation: https://wiki.alpinelinux.org/
- Alpine ISO Structure: Learned from `alpine-reference.iso`
- GRUB Documentation: https://www.gnu.org/software/grub/manual/
- SquashFS Documentation: https://www.kernel.org/doc/Documentation/filesystems/squashfs.txt

---

## Additional Notes

- QEMU mouse doesn't work in window (normal behavior - use Ctrl+Alt+G to release)
- Official Alpine ISO boots perfectly in QEMU with same hardware config
- Build process works flawlessly - only boot process fails
- All files are in correct locations on ISO (verified with manual mount)

---

**Next Action:** Test in VirtualBox to see if different BIOS implementation handles boot differently.
