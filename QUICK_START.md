# NTARI OS - Quick Start Guide for Developers

**Welcome!** This guide gets you from zero to building NTARI OS in 30 minutes.

---

## Prerequisites

Choose your development path:

### Path A: Core System Development (Alpine Linux)
- **OS**: Linux (Ubuntu/Debian recommended) or macOS
- **Tools**: Docker, Git, 10GB free space
- **Knowledge**: Basic Linux, shell scripting

### Path B: USB Installer Development
- **OS**: Windows, macOS, or Linux
- **Tools**: Node.js 18+, Git
- **Knowledge**: JavaScript/React basics

### Path C: Documentation/Design
- **OS**: Any
- **Tools**: Markdown editor, Git
- **Knowledge**: Technical writing or design

---

## Quick Setup (5 minutes)

### 1. Clone Repository

```bash
# Clone the repo
git clone https://github.com/ntari/ntari-os.git
cd ntari-os

# Set up your git identity
git config user.name "Your Name"
git config user.email "your.email@example.com"
```

### 2. Choose Your Component

```bash
# For core system development
cd core
cat README.md  # Read Alpine build instructions

# For USB installer development
cd installer
npm install    # Install dependencies

# For documentation
cd docs
# Create or edit markdown files
```

---

## Path A: Building Alpine Base System

**Goal**: Create bootable NTARI OS Server Edition ISO

### Step 1: Set Up Alpine Build Environment

```bash
cd core

# Using Docker (recommended)
docker run -it --rm \
  -v $(pwd):/work \
  alpine:3.19 \
  /bin/sh

# Inside container
apk add alpine-sdk build-base
```

### Step 2: Create Build Configuration

```bash
# Create package list file
cat > alpine-packages.txt <<EOF
# Base system
alpine-base
linux-lts
syslinux
openrc

# Networking
openntpd
openssh
iproute2

# NTARI-specific
# (will add P2P networking later)
EOF
```

### Step 3: Build Your First ISO

```bash
# Create minimal build script
cat > build.sh <<'EOF'
#!/bin/sh
set -e

echo "Building NTARI OS Server Edition..."

# Create work directory
mkdir -p work

# This is a placeholder - full build script coming soon
echo "✓ Build environment ready"
echo "Next: Define complete package list"
EOF

chmod +x build.sh
./build.sh
```

### Step 4: Test in VM

```bash
# Install QEMU
# Ubuntu/Debian:
sudo apt install qemu-system-x86

# macOS:
brew install qemu

# Test boot (once ISO is built)
qemu-system-x86_64 -cdrom ntari-server.iso -m 1024
```

**Expected Time**: 2-3 hours for first build

---

## Path B: USB Installer Development

**Goal**: Create working USB installer prototype

### Step 1: Set Up Installer Project

```bash
cd installer

# Install dependencies (takes 2-3 minutes)
npm install

# Verify installation
npm list electron react
```

### Step 2: Create Basic UI Structure

```bash
# Create source directory
mkdir -p src/{main,renderer}

# Create entry point
cat > src/main/main.js <<'EOF'
const { app, BrowserWindow } = require('electron');

function createWindow() {
  const win = new BrowserWindow({
    width: 800,
    height: 600,
    webPreferences: {
      nodeIntegration: true
    }
  });

  win.loadFile('src/renderer/index.html');
}

app.whenReady().then(createWindow);
EOF

# Create basic HTML
cat > src/renderer/index.html <<'EOF'
<!DOCTYPE html>
<html>
<head>
  <title>NTARI Installer</title>
  <style>
    body {
      font-family: system-ui;
      max-width: 600px;
      margin: 50px auto;
    }
  </style>
</head>
<body>
  <h1>🌐 NTARI OS Installer</h1>
  <p>Cross-platform USB installer tool</p>
</body>
</html>
EOF
```

### Step 3: Run Development Server

```bash
# Add dev script to package.json if not present
# Then run:
npm run dev

# This opens the installer in development mode
```

### Step 4: Build for Your Platform

```bash
# Build for current platform only
npm run build

# Output will be in dist/ folder
```

**Expected Time**: 1 hour to get running

---

## Path C: Documentation

**Goal**: Create installation guide

### Step 1: Set Up Documentation Structure

```bash
cd docs

# Create guide template
cat > installation-guide-template.md <<'EOF'
# NTARI OS Installation Guide

## What You'll Need
- USB drive (8GB minimum)
- Computer to install NTARI on
- 30 minutes of time

## Step 1: Download NTARI Installer
Visit ntari.org/download...

## Step 2: Create Bootable USB
...

(Continue with clear, step-by-step instructions)
EOF
```

### Step 2: Add Screenshots/Photos

```bash
# Create assets directory
mkdir -p assets/screenshots
mkdir -p assets/bios-screens

# Add images with clear names
# Example:
# assets/screenshots/01-installer-welcome.png
# assets/bios-screens/dell-f12-boot-menu.jpg
```

### Step 3: Test Your Instructions

- Follow your own guide exactly
- Note any confusion points
- Add clarifying details
- Include common problems

**Expected Time**: 2-4 hours for comprehensive guide

---

## Common Commands

### Git Workflow

```bash
# Create feature branch
git checkout -b feature/your-feature-name

# Make changes, then:
git add .
git commit -m "[component] Brief description"

# Push to your fork
git push origin feature/your-feature-name

# Create Pull Request on GitHub
```

### Testing

```bash
# Core system
cd core
./test-vm.sh

# Installer
cd installer
npm test

# Documentation
cd docs
# Read through guides, check links
```

### Getting Help

```bash
# Read component README
cat README.md

# Check roadmap for context
cat ../ROADMAP.md

# See what's needed next
cat ../DEVELOPMENT_STATUS.md
```

---

## What to Work On

### High Priority (Phase 1)

1. **Alpine Build Script** (core/)
   - Define complete package list
   - Create automated build
   - Test on multiple platforms

2. **USB Installer Wizard** (installer/)
   - Welcome screen
   - USB detection
   - Edition selection
   - Writing progress

3. **Installation Documentation** (docs/)
   - Step-by-step guides
   - BIOS screenshots
   - Video tutorial script
   - Troubleshooting

### How to Choose

- **New to project?** Start with documentation
- **Systems programmer?** Work on core Alpine build
- **Web developer?** Build USB installer UI
- **Designer?** Create branding and mockups

---

## Project Structure Reference

```
ntari-os/
├── README.md              ← Start here
├── ROADMAP.md             ← 24-month plan
├── CONTRIBUTING.md        ← How to contribute
├── QUICK_START.md         ← This file
│
├── core/                  ← Alpine Linux system
│   ├── README.md          ← Build instructions
│   └── build.sh           ← Build script (create this)
│
├── installer/             ← USB installer tool
│   ├── README.md          ← Architecture docs
│   ├── package.json       ← Dependencies
│   └── src/               ← Source code (create this)
│
├── docs/                  ← Documentation
│   └── (create guides)
│
├── hardware/              ← Raspberry Pi configs
├── network/               ← P2P networking (Phase 2)
├── governance/            ← Democratic systems (Phase 5)
└── apps/                  ← Applications
```

---

## Development Cycle

### Typical Week

**Monday**: Pick task from roadmap
**Tuesday-Thursday**: Development
**Friday**: Testing, documentation
**Weekend**: Optional community support

### Workflow

1. **Plan**: Choose task from ROADMAP.md
2. **Branch**: Create feature branch
3. **Develop**: Write code, commit often
4. **Test**: Verify functionality
5. **Document**: Update relevant docs
6. **Submit**: Create Pull Request
7. **Review**: Address feedback
8. **Merge**: Celebrate! 🎉

---

## Tips for Success

### Do:
- ✅ Read the specification (v1.3)
- ✅ Follow existing patterns
- ✅ Write clear commit messages
- ✅ Test on multiple platforms
- ✅ Ask questions early
- ✅ Update documentation

### Don't:
- ❌ Work on features from Phase 2+ yet
- ❌ Skip testing
- ❌ Forget to update docs
- ❌ Reinvent the wheel
- ❌ Break existing functionality

---

## Getting Unstuck

### Problem: "I don't know where to start"
→ Start with documentation - write an installation guide

### Problem: "Build doesn't work"
→ Check you have all prerequisites installed
→ Read error messages carefully
→ Ask in Discord #development

### Problem: "My change conflicts with main"
→ Rebase: `git pull --rebase upstream main`
→ Resolve conflicts
→ Force push: `git push -f origin your-branch`

### Problem: "I have an idea not in the roadmap"
→ Great! Open a GitHub Discussion
→ Explain the idea
→ Get community feedback

---

## Resources

### Documentation
- **Specification**: ../NTARI_OS_Specification_v1.3.txt
- **Roadmap**: ROADMAP.md
- **Contributing**: CONTRIBUTING.md
- **Status**: ../DEVELOPMENT_STATUS.md

### External Resources
- **Alpine Linux**: alpinelinux.org/documentation
- **Electron**: electronjs.org/docs
- **React**: react.dev
- **Docker**: docs.docker.com

### Community
- **Discord**: discord.gg/ntari
- **Forum**: community.ntari.org
- **Email**: info@ntari.org

---

## Your First Contribution

### Absolute Beginner? Try This:

1. **Fix a typo** in documentation
2. **Add a comment** to code
3. **Report a bug** you found
4. **Suggest an improvement** to docs

### Ready for More? Try This:

1. **Write BIOS guide** for your computer brand
2. **Create welcome screen** for installer
3. **Build Alpine ISO** on your machine
4. **Translate docs** to your language

---

## Next Steps

**You're ready to contribute!**

1. Pick a task from Phase 1 in ROADMAP.md
2. Create a feature branch
3. Make your changes
4. Submit a Pull Request
5. Join the NTARI community

**Welcome aboard! 🚀**

---

*Last Updated: February 15, 2026*
*Questions? Email info@ntari.org*
