# QEMU Boot Issues — NTARI OS ISO Testing

**Date:** February 17, 2026
**Status:** Analyzed — Root cause identified; v1.5 build system resolves this

---

## Summary

The v1.0/v1.4 ISO builder (`build/build-iso.sh`) produces ISOs that fail to boot
in QEMU, dropping to an initramfs emergency recovery shell:

```
Mounting boot media failed.
initramfs emergency recovery shell launched. Type 'exit' to continue boot
sh: can't access tty; job control turned off
```

This is a **known architectural issue** with the v1.0 build approach.
It does not affect the v1.5 build system (`make iso`), which follows
Alpine's standard ISO build conventions.

---

## System Information (v1.0 Build)

- **Host OS:** Windows
- **QEMU Version:** 10.2.0
- **Docker:** 29.2.0
- **Alpine Linux Base:** 3.19.9
- **Build System:** Docker-based Alpine build environment

---

## Build Process (v1.0)

### Successful Steps:
1. ✅ Docker image built (`ntari-builder`)
2. ✅ Base Alpine minirootfs downloaded (3.19.0)
3. ✅ Packages installed (388 packages, 2.4GB total)
4. ✅ SquashFS root filesystem created (868.3MB compressed)
5. ✅ Kernel and initramfs copied to ISO
6. ✅ GRUB bootloader installed (with grub-bios)
7. ✅ ISO image created successfully — **906MB**

### ISO Details:
- **Name:** `ntari-server-alpine-style.iso`
- **Size:** ~906MB
- **Format:** ISO9660 with El Torito boot
- **Bootloader:** GRUB 2.06
- **Kernel:** vmlinuz-lts (6.6.117-0-lts)
- **Initramfs:** initramfs-lts (18MB)
- **Root FS:** /ntari/rootfs.squashfs (868MB SquashFS)

---

## Root Cause Analysis

### The Fundamental Problem

NTARI OS v1.0 uses a **custom boot structure** that doesn't match Alpine's
expected Live CD layout.

**NTARI v1.0 Structure:**
```
iso-server/
  ├── boot/
  │   ├── grub/
  │   ├── vmlinuz
  │   └── initramfs
  └── ntari/
      └── rootfs.squashfs  ← Custom SquashFS root
```

**Alpine Standard Structure:**
```
cdrom/
  ├── boot/
  ├── apks/              ← Package repository
  └── .alpine-release
```

### Why It Fails:

1. Alpine's initramfs mounts the CD-ROM at `/media/cdrom` and looks for
   `/apks` directory or `.apkovl.tar.gz`. It doesn't know how to mount
   a custom SquashFS at `/ntari/rootfs.squashfs`.

2. The stock Alpine initramfs has no custom init hooks for our layout.

3. We're using Alpine's bootloader with a non-Alpine root filesystem
   convention.

---

## Boot Parameter Attempts (All Failed)

| Attempt | GRUB Parameters | Result |
|---------|----------------|--------|
| 1 | `modules=loop,squashfs,sd-mod,usb-storage quiet` | ❌ Emergency shell |
| 2 | `+ modloop=/ntari/rootfs.squashfs` | ❌ Emergency shell |
| 3 | `+ alpine_dev=cdrom:iso9660 alpine_root=/ntari/rootfs.squashfs` | ❌ Emergency shell |
| 4 | `root=/dev/sr0 rootfstype=iso9660 init=/bin/sh` | ❌ Emergency shell |
| 5 | Exact Alpine official params | ❌ Emergency shell |

Official Alpine ISO boots correctly in same QEMU environment — confirming
the issue is structural, not hardware.

---

## Solutions

### Short-term (v1.0 Build System)

**Option A: Custom Initramfs** (Complex)
- Extract initramfs, add custom init script to mount `/ntari/rootfs.squashfs`
- Repack initramfs, rebuild ISO
- Non-standard, maintenance burden

**Option B: Alpine Standard Method** (Recommended for v1.0)
- Convert to `/apks` directory with packages
- Use Alpine's overlay system (`alpine-make-vm-image`)
- Works with standard Alpine tools

**Option C: Test in VirtualBox** (Quick)
- Different BIOS implementation may behave differently
- See [VIRTUALBOX_METHOD.md](./VIRTUALBOX_METHOD.md)

### Long-term (v1.5 Build System)

The v1.5 build system (`make iso`) resolves this by adopting Alpine's
standard `mkimage` / `alpine-make-vm-image` approach, which Alpine's
initramfs expects. This is tracked in Phase 6 of the development plan.

---

## Lessons Learned

1. **Standard conventions matter:** Fighting Alpine's expected structure
   causes problems. Use Alpine's own build tools.
2. **Test early:** Boot testing should happen before full package installation.
3. **Study references:** Booting the official Alpine ISO was critical to
   understanding the structural mismatch.
4. **Initramfs is key:** The initramfs dictates early boot behavior —
   the custom SquashFS approach requires custom initramfs hooks.

---

## ISOs Created (v1.0 Build Session, Feb 17, 2026)

All stored in: `build/build-output/`

1. `ntari-server-1.0.0-20260217.iso` (906MB) — Initial, no BIOS boot
2. `ntari-server-fixed.iso` (906MB) — Added BIOS boot
3. `ntari-server-bios.iso` (906MB) — With grub-bios
4. `ntari-server-working.iso` (906MB) — With modloop param
5. `ntari-server-v2.iso` (906MB) — With alpine_dev param
6. `ntari-server-alpine-style.iso` (906MB) — Matches Alpine params
7. `alpine-reference.iso` (207MB) — Official Alpine for reference

**Current Status:** All fail at boot with same emergency shell error.

---

## References

- Alpine Linux Documentation: https://wiki.alpinelinux.org/
- Alpine `mkimage` tool: https://github.com/alpinelinux/aports/tree/master/scripts
- GRUB Documentation: https://www.gnu.org/software/grub/manual/
- SquashFS Documentation: https://www.kernel.org/doc/Documentation/filesystems/squashfs.txt
