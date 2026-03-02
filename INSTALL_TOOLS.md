# Installing Required Tools for NTARI OS

This guide will help you install Docker Desktop, VirtualBox, and Packer on Windows.

## Quick Links

- **Docker Desktop**: https://www.docker.com/products/docker-desktop
- **VirtualBox**: https://www.virtualbox.org/wiki/Downloads
- **Packer**: https://www.packer.io/downloads

## System Requirements

### Minimum Requirements
- Windows 10/11 (64-bit)
- 8GB RAM (16GB recommended)
- 20GB free disk space
- Virtualization enabled in BIOS

### Check Virtualization

Run in PowerShell as Administrator:
```powershell
Get-ComputerInfo | Select-Object -Property HyperV*
```

Or check in Task Manager:
- Open Task Manager (Ctrl+Shift+Esc)
- Go to Performance tab
- Click CPU
- Look for "Virtualization: Enabled"

---

## Installation Options

### Option A: Automated Installation (Recommended)

Use the provided PowerShell script:

```powershell
# Run PowerShell as Administrator
cd "C:\Users\Jodson Graves\Documents\NTARI OS"
.\install-tools.ps1
```

### Option B: Manual Installation

Follow the detailed steps below for each tool.

---

## 1. Docker Desktop

### Download and Install

1. **Visit the download page**:
   ```
   https://www.docker.com/products/docker-desktop
   ```

2. **Click "Download for Windows"**
   - File: `Docker Desktop Installer.exe` (~500MB)

3. **Run the installer**
   - Double-click the downloaded file
   - Check "Use WSL 2 instead of Hyper-V" (recommended)
   - Click "Ok" to begin installation

4. **Wait for installation**
   - Takes 5-10 minutes
   - May require restart

5. **Start Docker Desktop**
   - Launch from Start Menu
   - Accept service agreement
   - Skip sign-in (optional)
   - Wait for Docker Engine to start

### Verify Installation

```bash
docker --version
docker run hello-world
```

Expected output:
```
Docker version 24.x.x, build xxxxx
Hello from Docker!
```

### Troubleshooting

**Issue**: "WSL 2 installation is incomplete"
```powershell
# Run in PowerShell as Administrator
wsl --install
wsl --set-default-version 2
# Restart computer
```

**Issue**: "Docker Desktop failed to start"
- Ensure virtualization is enabled in BIOS
- Check Windows Features: Hyper-V or WSL2 enabled
- Restart computer

---

## 2. VirtualBox

### Download and Install

1. **Visit the download page**:
   ```
   https://www.virtualbox.org/wiki/Downloads
   ```

2. **Download for Windows**
   - Click "Windows hosts"
   - File: `VirtualBox-7.x.x-Win.exe` (~100MB)

3. **Run the installer**
   - Double-click the downloaded file
   - Click "Next" through the wizard
   - Accept default installation location
   - Keep all features selected
   - Click "Yes" to network interface warning
   - Click "Install"

4. **Complete installation**
   - May install device drivers
   - Click "Finish"

5. **Launch VirtualBox**
   - Open from Start Menu
   - Should see VirtualBox Manager window

### Verify Installation

```bash
"C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" --version
```

Expected output:
```
7.x.x
```

### Add to PATH (Optional)

Add VirtualBox to your PATH for easier command-line access:

```powershell
# Run in PowerShell as Administrator
[Environment]::SetEnvironmentVariable(
    "Path",
    "$env:Path;C:\Program Files\Oracle\VirtualBox",
    "Machine"
)
```

Restart your terminal after this.

---

## 3. Packer

### Download and Install

1. **Visit the download page**:
   ```
   https://www.packer.io/downloads
   ```

2. **Download for Windows (AMD64)**
   - Click the Windows AMD64 link
   - File: `packer_x.x.x_windows_amd64.zip` (~50MB)

3. **Extract the ZIP file**
   - Right-click → Extract All
   - Extract to: `C:\Program Files\Packer\`
   - Create folder if it doesn't exist

4. **Add to PATH**

   **Option 1: PowerShell (as Administrator)**
   ```powershell
   [Environment]::SetEnvironmentVariable(
       "Path",
       "$env:Path;C:\Program Files\Packer",
       "Machine"
   )
   ```

   **Option 2: GUI Method**
   - Right-click "This PC" → Properties
   - Click "Advanced system settings"
   - Click "Environment Variables"
   - Under "System variables", select "Path"
   - Click "Edit"
   - Click "New"
   - Add: `C:\Program Files\Packer`
   - Click "OK" on all dialogs

5. **Restart terminal**
   - Close and reopen Git Bash or PowerShell

### Verify Installation

```bash
packer --version
```

Expected output:
```
Packer v1.x.x
```

### Install QEMU Plugin (Required for Packer)

```bash
packer plugins install github.com/hashicorp/qemu
```

---

## 4. QEMU (Optional but Recommended)

QEMU is needed for Packer to create VM images.

### Download and Install

1. **Visit the download page**:
   ```
   https://www.qemu.org/download/#windows
   ```

2. **Download Windows installer**
   - Use the link to QEMU for Windows builds
   - Or download from: https://qemu.weilnetz.de/w64/
   - File: `qemu-w64-setup-xxxxxxxx.exe`

3. **Run installer**
   - Install to default location
   - Install all components

4. **Add to PATH**
   ```powershell
   # Run in PowerShell as Administrator
   [Environment]::SetEnvironmentVariable(
       "Path",
       "$env:Path;C:\Program Files\qemu",
       "Machine"
   )
   ```

### Verify Installation

```bash
qemu-system-x86_64 --version
```

---

## Quick Installation Script

Save this as `install-tools.ps1` and run as Administrator:

```powershell
# NTARI OS - Quick Tool Installation Script
# Run as Administrator

Write-Host "NTARI OS - Installing Required Tools" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Host "ERROR: This script must be run as Administrator!" -ForegroundColor Red
    Write-Host "Right-click PowerShell and select 'Run as Administrator'" -ForegroundColor Yellow
    pause
    exit 1
}

# Function to download file
function Download-File {
    param($url, $output)
    Write-Host "Downloading: $output" -ForegroundColor Yellow
    Invoke-WebRequest -Uri $url -OutFile $output -UseBasicParsing
}

Write-Host "This script will help install:" -ForegroundColor Green
Write-Host "  1. Docker Desktop"
Write-Host "  2. VirtualBox"
Write-Host "  3. Packer"
Write-Host ""
Write-Host "NOTE: Some installers must be run manually." -ForegroundColor Yellow
Write-Host ""

$continue = Read-Host "Continue? (Y/N)"
if ($continue -ne "Y" -and $continue -ne "y") {
    exit 0
}

# Create download directory
$downloadDir = "$env:USERPROFILE\Downloads\NTARI-Tools"
New-Item -ItemType Directory -Force -Path $downloadDir | Out-Null
Set-Location $downloadDir

Write-Host ""
Write-Host "=== Installing Chocolatey (Package Manager) ===" -ForegroundColor Cyan

# Install Chocolatey if not present
if (-not (Get-Command choco -ErrorAction SilentlyContinue)) {
    Write-Host "Installing Chocolatey..." -ForegroundColor Yellow
    Set-ExecutionPolicy Bypass -Scope Process -Force
    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
    refreshenv
} else {
    Write-Host "Chocolatey already installed." -ForegroundColor Green
}

Write-Host ""
Write-Host "=== Installing Docker Desktop ===" -ForegroundColor Cyan

if (Get-Command docker -ErrorAction SilentlyContinue) {
    Write-Host "Docker already installed." -ForegroundColor Green
} else {
    Write-Host "Installing Docker Desktop via Chocolatey..." -ForegroundColor Yellow
    choco install docker-desktop -y
    Write-Host "Docker Desktop installed. Please start it from the Start Menu." -ForegroundColor Green
}

Write-Host ""
Write-Host "=== Installing VirtualBox ===" -ForegroundColor Cyan

if (Test-Path "C:\Program Files\Oracle\VirtualBox\VirtualBox.exe") {
    Write-Host "VirtualBox already installed." -ForegroundColor Green
} else {
    Write-Host "Installing VirtualBox via Chocolatey..." -ForegroundColor Yellow
    choco install virtualbox -y
    Write-Host "VirtualBox installed." -ForegroundColor Green
}

Write-Host ""
Write-Host "=== Installing Packer ===" -ForegroundColor Cyan

if (Get-Command packer -ErrorAction SilentlyContinue) {
    Write-Host "Packer already installed." -ForegroundColor Green
} else {
    Write-Host "Installing Packer via Chocolatey..." -ForegroundColor Yellow
    choco install packer -y
    refreshenv
    Write-Host "Packer installed." -ForegroundColor Green
}

Write-Host ""
Write-Host "=== Installation Complete ===" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "  1. Restart your computer"
Write-Host "  2. Start Docker Desktop"
Write-Host "  3. Open a new terminal"
Write-Host "  4. Run: docker --version"
Write-Host "  5. Run: cd 'C:\Users\Jodson Graves\Documents\NTARI OS'"
Write-Host "  6. Run: make iso"
Write-Host ""

pause
```

---

## Post-Installation Verification

After installing all tools, verify they work:

```bash
# Check Docker
docker --version
docker run hello-world

# Check VirtualBox
VBoxManage --version

# Check Packer
packer --version

# Optional: Check QEMU
qemu-system-x86_64 --version
```

---

## Building NTARI OS

Once all tools are installed:

```bash
cd "C:\Users\Jodson Graves\Documents\NTARI OS"

# Clean previous builds
make clean

# Build the ISO
make iso

# Build VM images (requires Packer + QEMU)
make vm
```

---

## Troubleshooting

### Docker Issues

**"Cannot connect to Docker daemon"**
```bash
# Ensure Docker Desktop is running
# Look for Docker icon in system tray
# Start Docker Desktop from Start Menu
```

**"WSL 2 required"**
```powershell
# Enable WSL 2
wsl --install
wsl --set-default-version 2
# Restart computer
```

### VirtualBox Issues

**"Installation failed"**
- Disable Hyper-V temporarily:
  ```powershell
  bcdedit /set hypervisorlaunchtype off
  # Restart computer
  ```

**"VT-x is not available"**
- Enable virtualization in BIOS
- Restart and enter BIOS (usually F2, F12, or Del)
- Enable Intel VT-x or AMD-V

### Packer Issues

**"packer not found"**
- Ensure PATH is updated
- Restart terminal
- Verify with: `echo $env:Path` (PowerShell)

**"QEMU plugin not found"**
```bash
packer plugins install github.com/hashicorp/qemu
```

### General Issues

**"Command not found after install"**
- Restart terminal
- Restart computer
- Check PATH environment variable

---

## Alternative: Use WSL2

If you prefer a Linux environment:

```powershell
# Install WSL2
wsl --install -d Ubuntu

# Launch Ubuntu
wsl

# Inside WSL2, install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Access Windows files
cd "/mnt/c/Users/Jodson Graves/Documents/NTARI OS"

# Build
make iso
```

---

## Download Size Summary

- Docker Desktop: ~500MB
- VirtualBox: ~100MB
- Packer: ~50MB
- QEMU: ~200MB (optional)

**Total**: ~850MB download

**Time**: ~30-60 minutes including downloads and installation

---

## Next Steps

After installation:

1. ✅ Verify all tools work
2. ✅ Start Docker Desktop
3. ✅ Build NTARI OS: `make iso`
4. ✅ Create test VM in VirtualBox
5. ✅ Test the ISO

See `QUICKSTART.md` for building instructions.

---

## Support

If you encounter issues:

1. Check this troubleshooting section
2. Restart computer (fixes most PATH issues)
3. Check tool-specific documentation
4. Create GitHub issue with error details

---

**Ready to build NTARI OS!** 🚀
