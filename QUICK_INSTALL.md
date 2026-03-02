# Quick Installation Guide

Get Docker, VirtualBox, and Packer installed in minutes!

## 🚀 Quick Start (Automated)

### Option 1: Double-Click Install (Easiest)

1. **Double-click**: `install-tools.bat`
2. Click **"Yes"** when prompted for Administrator access
3. Wait for installation to complete
4. **Restart your computer**

### Option 2: PowerShell (Manual)

1. **Right-click PowerShell** → Run as Administrator
2. Run these commands:
   ```powershell
   cd "C:\Users\Jodson Graves\Documents\NTARI OS"
   Set-ExecutionPolicy Bypass -Scope Process
   .\install-tools.ps1
   ```
3. **Restart your computer**

---

## 📥 Manual Installation (If Automated Fails)

### 1. Docker Desktop

**Download**: https://www.docker.com/products/docker-desktop

1. Click **"Download for Windows"**
2. Run installer
3. Choose **"Use WSL 2"** when prompted
4. Restart when prompted
5. Start Docker Desktop from Start Menu

**Verify**:
```bash
docker --version
```

### 2. VirtualBox

**Download**: https://www.virtualbox.org/wiki/Downloads

1. Click **"Windows hosts"**
2. Run installer
3. Accept all defaults
4. Complete installation

**Verify**:
```bash
"C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" --version
```

### 3. Packer

**Download**: https://www.packer.io/downloads

1. Download **Windows AMD64** ZIP
2. Extract to `C:\Program Files\Packer\`
3. Add to PATH:
   ```powershell
   # Run as Administrator
   [Environment]::SetEnvironmentVariable(
       "Path",
       "$env:Path;C:\Program Files\Packer",
       "Machine"
   )
   ```
4. Restart terminal

**Verify**:
```bash
packer --version
```

---

## ✅ Verification

After installation and restart, verify all tools:

```bash
# Check Docker
docker --version
docker run hello-world

# Check VirtualBox
VBoxManage --version

# Check Packer
packer --version
```

Expected output:
```
Docker version 24.x.x
VirtualBox 7.x.x
Packer v1.x.x
```

---

## 🏗️ Building NTARI OS

Once all tools are verified:

```bash
cd "C:\Users\Jodson Graves\Documents\NTARI OS"

# Start Docker Desktop first!

# Build the ISO
make iso

# Wait ~10-15 minutes for first build
# Output: build-output/ntari-os-1.0.0-x86_64.iso
```

---

## 🔧 Troubleshooting

### Docker not starting?

1. Ensure virtualization is enabled in BIOS
2. Enable WSL 2:
   ```powershell
   wsl --install
   wsl --set-default-version 2
   ```
3. Restart computer

### "Command not found"?

1. Restart terminal
2. Restart computer
3. Check PATH environment variable

### VirtualBox install fails?

1. Temporarily disable Hyper-V:
   ```powershell
   bcdedit /set hypervisorlaunchtype off
   ```
2. Restart computer
3. Install VirtualBox
4. Re-enable if needed

---

## 📊 Download Sizes

- Docker Desktop: ~500MB
- VirtualBox: ~100MB
- Packer: ~50MB

**Total**: ~650MB

**Time**: 30-60 minutes (including downloads)

---

## 🎯 Next Steps

After installation:

1. ✅ Verify all tools installed
2. ✅ Restart computer
3. ✅ Start Docker Desktop
4. ✅ Run: `make iso`
5. ✅ Test in VirtualBox

See **QUICKSTART.md** for complete build instructions.

---

## 📚 Additional Help

- Full guide: **INSTALL_TOOLS.md**
- Quick start: **QUICKSTART.md**
- Documentation: **docs/INSTALL.md**
- Troubleshooting: **TEST_REPORT.md**

---

**Questions?** Check INSTALL_TOOLS.md for detailed troubleshooting.
