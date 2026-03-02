# NTARI USB Installer Tool

Cross-platform GUI application for creating bootable NTARI OS USB drives.

## Overview

The NTARI Installer makes it easy to create bootable USB drives for installing NTARI OS. It handles:
- Automatic ISO download
- USB drive detection and validation
- Safe disk writing with verification
- Computer-specific boot instructions
- Edition selection (Desktop, Lite, Server)

## Supported Platforms

- **Windows**: Windows 7 and later (32-bit and 64-bit)
- **macOS**: macOS 10.13 High Sierra and later
- **Linux**: Most distributions (via AppImage)

## Tech Stack

- **Framework**: Electron 28
- **UI**: React 18 + Tailwind CSS
- **Disk Writing**: Etcher SDK (balena-io)
- **Build System**: electron-builder

## Development

### Prerequisites

```bash
# Install Node.js 18+ and npm
node --version  # Should be 18.0.0 or higher
npm --version   # Should be 9.0.0 or higher
```

### Setup

```bash
cd installer
npm install
```

### Run in Development

```bash
npm run dev
# Opens installer in development mode
```

### Build for Production

```bash
# Build for all platforms
npm run build

# Build for specific platform
npm run build:windows   # Creates .exe
npm run build:mac       # Creates .dmg
npm run build:linux     # Creates .AppImage
```

## Architecture

```
installer/
├── src/
│   ├── main/              # Electron main process
│   │   ├── main.js        # App entry point
│   │   ├── download.js    # ISO download manager
│   │   └── writer.js      # USB write operations
│   ├── renderer/          # React UI
│   │   ├── App.jsx        # Main app component
│   │   ├── screens/       # Wizard screens
│   │   │   ├── Welcome.jsx
│   │   │   ├── SelectUSB.jsx
│   │   │   ├── SelectEdition.jsx
│   │   │   ├── Warning.jsx
│   │   │   ├── Writing.jsx
│   │   │   └── Complete.jsx
│   │   └── components/    # Reusable components
│   └── shared/            # Shared utilities
├── assets/                # Images, icons
├── build/                 # Build configuration
└── package.json
```

## Installer Flow

```
┌─────────────┐
│   Welcome   │ → Explain what NTARI is
└──────┬──────┘
       ↓
┌─────────────┐
│ Select USB  │ → Detect drives, show sizes
└──────┬──────┘
       ↓
┌─────────────┐
│   Edition   │ → Desktop (1.2GB), Lite (400MB), Server (180MB)
└──────┬──────┘
       ↓
┌─────────────┐
│   Warning   │ → Critical data loss warning
└──────┬──────┘
       ↓
┌─────────────┐
│   Writing   │ → Download ISO → Write → Verify (8 min)
└──────┬──────┘
       ↓
┌─────────────┐
│  Complete   │ → Boot instructions, brand-specific guides
└─────────────┘
```

## Key Features

### 1. Automatic ISO Download
- Fetches latest ISO from releases.ntari.org
- Shows download progress
- Verifies checksums
- Caches downloads

### 2. Smart USB Detection
- Lists all connected USB drives
- Shows size, name, vendor
- Highlights drives too small
- Prevents selection of system drives

### 3. Edition Selection
```javascript
const editions = [
  {
    name: 'Desktop Edition',
    size: '1.2 GB',
    description: 'Full graphical interface with XFCE',
    recommended: true
  },
  {
    name: 'Lite Edition',
    size: '400 MB',
    description: 'Minimal GUI for older computers'
  },
  {
    name: 'Server Edition',
    size: '180 MB',
    description: 'Headless, terminal-only'
  }
]
```

### 4. Critical Warning Screen
- Forces user acknowledgment
- Checklist of preparations
- Dual-boot option
- Cannot skip

### 5. Safe Writing
- Unmounts drive automatically
- Uses verified write library (Etcher SDK)
- Checksums after write
- Safe eject

### 6. Computer-Specific Instructions
```javascript
const bootInstructions = {
  'Dell': { key: 'F12', alternative: 'F2' },
  'HP': { key: 'F9', alternative: 'Esc' },
  'Lenovo': { key: 'F12', alternative: 'F1' },
  'ASUS': { key: 'F8', alternative: 'Del' },
  'Acer': { key: 'F12', alternative: 'F2' },
  'Generic': { key: 'F12', alternative: 'F2, F10, Del, Esc' }
}
```

## Security

- **Checksum Verification**: SHA256 for all downloads
- **Safe Drive Selection**: System drives cannot be selected
- **Confirmation Required**: Multiple warnings before write
- **No Telemetry**: Zero data collection

## Testing

```bash
# Unit tests
npm test

# E2E tests (requires USB drive)
npm run test:e2e

# Manual testing checklist
npm run test:manual  # Opens checklist
```

## Distribution

Built installers are published to:
- **Website**: https://ntari.org/download
- **GitHub Releases**: https://github.com/ntari/ntari-os/releases
- **Direct Links**:
  - Windows: `releases.ntari.org/installer/NTARI-Installer-Windows.exe`
  - macOS: `releases.ntari.org/installer/NTARI-Installer-Mac.dmg`
  - Linux: `releases.ntari.org/installer/NTARI-Installer-Linux.AppImage`

## File Sizes

- **Installer Tool**: ~50MB (each platform)
- **Desktop ISO**: 1.2GB
- **Lite ISO**: 400MB
- **Server ISO**: 180MB

## Roadmap

- [x] Basic USB writing
- [x] Edition selection
- [x] Download management
- [ ] Brand detection (auto-detect computer manufacturer)
- [ ] Offline mode (pre-downloaded ISO)
- [ ] Multi-language support
- [ ] Accessibility features
- [ ] Advanced options (custom partitioning)

## Support

Users having issues? Direct them to:
- Video guide: https://ntari.org/install/video
- Web guide: https://install.ntari.org
- Discord: #installation-help
- Forum: community.ntari.org/installation
