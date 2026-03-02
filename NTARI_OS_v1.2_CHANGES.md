# NTARI OS Specification v1.2 - Changes

## February 15, 2026

---

## NEW: Section 1.5 - Distribution & Installation Strategy

This update adds comprehensive distribution and installation documentation to make NTARI OS accessible to mainstream users.

---

## What's New

### Desktop Linux Distribution Methods

**1. USB Installer (NEW) - Recommended for Beginners**

The "Rufus for NTARI" approach - dead simple installation:

```
Download → Double-click → Insert USB → Click "Create" → Reboot → Install
```

**Platform Coverage**:
- Windows: NTARI-USB-Installer.exe (50MB)
- macOS: NTARI-USB-Installer.dmg (50MB)
- Linux: NTARI-USB-Installer.AppImage (50MB)

**What It Does**:
- Creates bootable USB drive from ISO
- Embedded USB writing engine (based on balenaEtcher)
- Verifies write integrity
- One-click process
- Supports all three NTARI editions (Desktop, Lite, Server)

**User Interface**:
```
┌─────────────────────────────────────────┐
│ NTARI OS USB Installer                  │
├─────────────────────────────────────────┤
│ Step 1: Select USB Drive                │
│ [●] Kingston (16 GB)    Drive E:        │
│ ⚠️  All data will be erased!             │
│                                         │
│ Step 2: Choose Edition                  │
│ [●] Desktop (Recommended) - 1.2 GB      │
│ [ ] Lite - 400 MB                       │
│ [ ] Server - 180 MB                     │
│                                         │
│ Progress: ▓▓▓▓▓░░░░░ 65%                │
│                                         │
│ [Cancel]            [Create USB]        │
└─────────────────────────────────────────┘
```

**2. Package Managers (NEW) - For Linux Users**

Native package management integration:

**Debian/Ubuntu (.deb)**:
```bash
curl -fsSL https://repo.ntari.org/gpg | sudo gpg --dearmor -o /usr/share/keyrings/ntari.gpg
echo "deb [signed-by=/usr/share/keyrings/ntari.gpg] https://repo.ntari.org/apt stable main" | \
  sudo tee /etc/apt/sources.list.d/ntari.list
sudo apt update
sudo apt install ntari-desktop
```

**Arch Linux (.pkg.tar.zst)**:
```bash
yay -S ntari-desktop
```

**Fedora/RHEL (.rpm)**:
```bash
sudo dnf config-manager --add-repo https://repo.ntari.org/rpm/ntari.repo
sudo dnf install ntari-desktop
```

**3. Universal Formats (NEW)**

**AppImage** (Universal Linux):
```bash
wget https://releases.ntari.org/desktop/ntari-desktop-1.0.AppImage
chmod +x ntari-desktop-1.0.AppImage
./ntari-desktop-1.0.AppImage  # No installation needed
```

**4. Virtual Machine Images (NEW)**

For users who want to test without touching their main OS:

- **VirtualBox**: NTARI-Desktop-VirtualBox.ova (2.5GB)
- **VMware**: NTARI-Desktop-VMware.vmx
- **Hyper-V**: NTARI-Desktop-Hyper-V.vhdx
- **Docker**: `docker pull ntari/ntari-server:latest`

**Import & Run**:
```
1. Download .ova file
2. VirtualBox → Import Appliance
3. Start VM
4. NTARI boots, wizard appears
```

### Mobile Distribution

**Android**:
- **Google Play Store**: "NTARI Network" app (25MB)
- **F-Droid**: Open source app store version
- **Direct APK**: For regions without Play Store

**iOS**:
- **Apple App Store**: "NTARI Network" app (30MB)
- **TestFlight**: Beta testing program

**Installation Flow**: App Store → Install → 5-minute setup wizard → Done

### Auto-Update Mechanism (NEW)

**Background Updates**:
- Daily check for new versions
- Downloads in background
- User-initiated restart to apply
- Zero downtime updates

**Update Channels**:
- **Stable**: Well-tested, production-ready (default)
- **Beta**: New features, early access
- **Dev**: Cutting edge, for developers

**User Experience**:
```
System Tray Notification:
┌────────────────────────────────────┐
│ NTARI OS Update Available          │
│ Version 1.1 is ready to install    │
│                                    │
│ [Restart Now] [Tonight] [Skip]     │
└────────────────────────────────────┘
```

### First-Run Experience (NEW)

**Quick Setup (5 minutes)**:
1. **About You**: Name, location (with privacy level)
2. **Your Computer**: Auto-detected hardware, choose what to share
3. **Skills**: Optional, for job matching
4. **Privacy**: Camera/sensor access controls
5. **Network Discovery**: Auto-connect to nearby nodes
6. **Done**: Start earning

**Advanced Setup (15 minutes)**: Full customization for power users

**Example Screen**:
```
┌─────────────────────────────────────────┐
│ 🌐 Welcome to NTARI OS                  │
├─────────────────────────────────────────┤
│ This computer will become part of a     │
│ network where:                          │
│                                         │
│ 💾 You share storage ($5-50/month)     │
│ 💻 You share processing ($5-30/month)  │
│ 💼 You find freelance work ($0-500+)   │
│ 🗳️ You vote on network decisions        │
│                                         │
│ 100% of what you earn stays with you.  │
│                                         │
│ How do you want to set up?             │
│                                         │
│ [⚡ Quick Setup]  [🔧 Advanced Setup]   │
│                                         │
│ [Take a Tour First]                     │
└─────────────────────────────────────────┘
```

### Distribution Repository Structure (NEW)

```
releases.ntari.org/
├── desktop/
│   ├── ntari-desktop-1.0.iso
│   ├── ntari-desktop-1.0.AppImage
│   ├── ntari-desktop_1.0_amd64.deb
│   ├── ntari-desktop-1.0.rpm
│   ├── ntari-desktop-1.0.pkg.tar.zst
│   └── checksums.sha256
│
├── lite/
│   ├── ntari-lite-1.0.iso
│   └── ...
│
├── server/
│   ├── ntari-server-1.0.iso
│   └── docker/Dockerfile
│
├── installers/
│   ├── NTARI-USB-Installer.exe
│   ├── NTARI-USB-Installer.dmg
│   └── NTARI-USB-Installer.AppImage
│
├── vm/
│   ├── NTARI-Desktop-VirtualBox.ova
│   ├── NTARI-Desktop-VMware.vmx
│   └── NTARI-Desktop-Hyper-V.vhdx
│
├── android/
│   ├── ntari-v1.0.apk
│   └── fdroid-repo/
│
└── docs/
    ├── installation-guide.pdf
    ├── INSTALL-es.pdf (Spanish)
    ├── INSTALL-pt.pdf (Portuguese)
    ├── INSTALL-zh.pdf (Chinese)
    ├── INSTALL-ar.pdf (Arabic)
    └── INSTALL-hi.pdf (Hindi)
```

### Download Page Design (NEW)

**https://ntari.org/download**

```
┌─────────────────────────────────────────────────────┐
│         Download NTARI OS                           │
│    Build cooperative infrastructure                 │
│                                                     │
│ ┌────────────┐ ┌────────────┐ ┌────────────┐      │
│ │ 🖥️ Desktop  │ │ 📱 Mobile  │ │ 🏢 Server  │      │
│ │ Graphical  │ │ Android/iOS│ │ Terminal   │      │
│ │ [Download] │ │ [Download] │ │ [Download] │      │
│ └────────────┘ └────────────┘ └────────────┘      │
│                                                     │
│ 🪟 Windows/Mac Users: Use USB Installer            │
│ [Windows Installer] [Mac Installer]                │
│                                                     │
│ Advanced:                                           │
│ • Lite Edition • VM Image • Docker                  │
└─────────────────────────────────────────────────────┘
```

---

## Design Principle

**"My grandmother can install this with a YouTube tutorial"**

All installation methods prioritize:
- **Simplicity**: Download → Run → Done
- **Safety**: Live USB mode for testing before installation
- **Guidance**: Step-by-step wizards with plain language
- **Multilingual**: Installation guides in 6+ languages
- **Verification**: SHA256 checksums and PGP signatures

---

## Target User Experience

### Complete Beginner (Windows User):
1. Download NTARI-USB-Installer.exe (2 minutes)
2. Run installer, insert USB, click "Create" (5 minutes)
3. Reboot computer, select USB drive (1 minute)
4. Click "Install NTARI OS" (10 minutes automated)
5. Follow first-run wizard (5 minutes)
6. **Total: 23 minutes**

### Linux User:
1. Add NTARI repository (30 seconds)
2. `sudo apt install ntari-desktop` (5 minutes)
3. Reboot (1 minute)
4. Follow first-run wizard (5 minutes)
5. **Total: 11.5 minutes**

### Mobile User:
1. Open App Store, search "NTARI" (30 seconds)
2. Tap Install (2 minutes)
3. Open app, complete setup wizard (5 minutes)
4. **Total: 7.5 minutes**

---

## Technical Implementation Notes

**USB Installer**:
- Built with Electron (cross-platform GUI)
- Embeds balenaEtcher SDK for USB writing
- Automatically downloads ISO if not present
- Verifies write integrity
- ~50MB download size

**Package Repositories**:
- APT repository for Debian/Ubuntu
- RPM repository for Fedora/RHEL
- AUR for Arch Linux
- Automatic dependency resolution

**Auto-Updater**:
- Background service checks every 24 hours
- Downloads updates automatically
- User controls when to apply
- Graceful service migration
- Rollback capability

**First-Run Wizard**:
- Detects all hardware automatically
- Provides smart defaults
- Explains every choice in plain language
- Skippable for advanced users
- Saves configuration to `/etc/ntari/ntari.conf`

---

## File Changes

**Modified**:
- Section 1.4: Added distribution strategy to key innovations list
- Section 1: Added new section 1.5 (Distribution & Installation Strategy)
- Document History: Added v1.2 entry

**New Content**:
- USB installer specification
- Package manager integration
- Virtual machine images
- Mobile app distribution
- Auto-update mechanism
- First-run wizard screens
- Repository structure
- Download page design

**Lines Added**: ~75 lines in section 1.5

---

## Impact

**For Users**:
- Multiple installation options for all skill levels
- As easy as installing any mainstream app
- Safe testing via VM or live USB
- Multilingual support from day one

**For Developers**:
- Clear packaging requirements
- Multiple distribution channels
- Auto-update infrastructure
- First-run onboarding system

**For Adoption**:
- Removes technical barrier to entry
- "Grandmother-friendly" installation
- Familiar distribution methods
- Trust through app stores

---

## Next Steps

After this update, the specification covers:
- ✅ System architecture
- ✅ Multi-platform support
- ✅ User interface design
- ✅ **Distribution & installation**
- ⏳ Bootstrap problem (how first 100 nodes find each other)

---

**Version**: 1.2  
**Date**: February 15, 2026  
**Changes**: Distribution & Installation Strategy  
**Lines**: 4,106 (was 4,030)  
**New Sections**: 1 (section 1.5)
