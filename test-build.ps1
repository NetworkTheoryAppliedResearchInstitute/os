# NTARI OS Build and Test Script for Windows
# PowerShell version for easy Windows testing
# Version: 1.0.0

param(
    [Parameter(Position=0)]
    [ValidateSet("server", "desktop", "lite")]
    [string]$Edition = "server",

    [switch]$SkipBuild,
    [switch]$OpenVirtualBox
)

# Colors
function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

Write-ColorOutput "═══════════════════════════════════════════════════════" "Cyan"
Write-ColorOutput "  NTARI OS Build & Test - Windows Edition" "Cyan"
Write-ColorOutput "  Edition: $Edition" "Cyan"
Write-ColorOutput "═══════════════════════════════════════════════════════" "Cyan"
Write-Host ""

# Check Docker
Write-Host "Checking prerequisites..."
Write-Host ""

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
    Write-ColorOutput "✗ Docker not found" "Red"
    Write-ColorOutput "Please install Docker Desktop: https://www.docker.com/products/docker-desktop/" "Yellow"
    exit 1
}
Write-ColorOutput "✓ Docker found" "Green"

# Check if Docker is running
try {
    docker info | Out-Null
    Write-ColorOutput "✓ Docker is running" "Green"
} catch {
    Write-ColorOutput "✗ Docker is not running" "Red"
    Write-ColorOutput "Please start Docker Desktop" "Yellow"
    exit 1
}

# Check for QEMU
$hasQemu = Get-Command qemu-system-x86_64 -ErrorAction SilentlyContinue
if ($hasQemu) {
    Write-ColorOutput "✓ QEMU available" "Green"
} else {
    Write-ColorOutput "○ QEMU not found (optional)" "Yellow"
}

# Check for VirtualBox
$hasVBox = Get-Command VBoxManage -ErrorAction SilentlyContinue
if ($hasVBox) {
    Write-ColorOutput "✓ VirtualBox available" "Green"
} else {
    Write-ColorOutput "○ VirtualBox not found (optional)" "Yellow"
}

Write-Host ""

# Build ISO if not skipped
if (-not $SkipBuild) {
    Write-ColorOutput "[STEP 1/3] Building ISO with Docker..." "Yellow"
    Write-Host "────────────────────────────────────────────────────────"
    Write-Host ""

    Push-Location build

    # Run build script
    Write-Host "Running: ./docker-build.sh $Edition"
    Write-Host ""

    bash ./docker-build.sh $Edition

    if ($LASTEXITCODE -ne 0) {
        Write-ColorOutput "✗ Build failed" "Red"
        Pop-Location
        exit 1
    }

    Pop-Location

    Write-ColorOutput "✓ Build completed successfully" "Green"
    Write-Host ""
} else {
    Write-ColorOutput "[STEP 1/3] Skipping build (using existing ISO)" "Yellow"
    Write-Host ""
}

# Find ISO
Write-ColorOutput "[STEP 2/3] Locating ISO file..." "Yellow"
Write-Host "────────────────────────────────────────────────────────"

$isoPath = Get-ChildItem -Path "build\build-output" -Filter "ntari-$Edition-*.iso" -File |
           Sort-Object LastWriteTime -Descending |
           Select-Object -First 1

if (-not $isoPath) {
    Write-ColorOutput "✗ No ISO found for edition: $Edition" "Red"
    Write-Host ""
    Write-Host "Please build the ISO first:"
    Write-Host "  .\test-build.ps1 $Edition"
    exit 1
}

$isoFullPath = $isoPath.FullName
$isoSize = [math]::Round($isoPath.Length / 1MB, 2)

Write-ColorOutput "✓ Found ISO: $($isoPath.Name)" "Green"
Write-Host "  Size: $isoSize MB"
Write-Host "  Path: $isoFullPath"
Write-Host ""

# Determine RAM
$ram = switch ($Edition) {
    "server" { 2048 }
    "desktop" { 4096 }
    "lite" { 2048 }
}

# Test options
Write-ColorOutput "[STEP 3/3] Testing Options" "Yellow"
Write-Host "────────────────────────────────────────────────────────"
Write-Host ""

# Prepare test commands
$qemuCmd = "qemu-system-x86_64 -cdrom `"$isoFullPath`" -m $ram -boot d"

if (-not $hasQemu -and -not $hasVBox) {
    Write-ColorOutput "No virtualization software found!" "Red"
    Write-Host ""
    Write-Host "ISO is ready at: $isoFullPath"
    Write-Host ""
    Write-Host "To test, install one of:"
    Write-Host "  1. QEMU (fast, lightweight)"
    Write-Host "     Download: https://www.qemu.org/download/#windows"
    Write-Host ""
    Write-Host "  2. VirtualBox (full-featured)"
    Write-Host "     Download: https://www.virtualbox.org/wiki/Downloads"
    Write-Host ""
    exit 0
}

# Show options
Write-Host "ISO built successfully! Choose a test method:"
Write-Host ""

$choice = $null

if ($hasQemu -and $hasVBox) {
    Write-Host "1) Test with QEMU (fast, temporary)"
    Write-Host "2) Test with VirtualBox (full VM)"
    Write-Host "3) Just show ISO location"
    Write-Host ""
    $choice = Read-Host "Choose [1-3]"
} elseif ($hasQemu) {
    Write-Host "1) Test with QEMU"
    Write-Host "2) Just show ISO location"
    Write-Host ""
    $choice = Read-Host "Choose [1-2]"
    if ($choice -eq "2") { $choice = "3" }
} elseif ($hasVBox) {
    Write-Host "1) Test with VirtualBox"
    Write-Host "2) Just show ISO location"
    Write-Host ""
    $choice = Read-Host "Choose [1-2]"
    if ($choice -eq "1") { $choice = "2" }
    if ($choice -eq "2") { $choice = "3" }
}

Write-Host ""

switch ($choice) {
    "1" {
        # QEMU test
        Write-ColorOutput "Starting QEMU..." "Green"
        Write-Host ""
        Write-Host "Controls:"
        Write-Host "  - Ctrl+Alt+G: Release mouse"
        Write-Host "  - Ctrl+Alt+F: Toggle fullscreen"
        Write-Host "  - Ctrl+Alt+2: QEMU monitor"
        Write-Host ""
        Write-Host "Command: $qemuCmd"
        Write-Host ""

        Start-Process "qemu-system-x86_64" -ArgumentList "-cdrom `"$isoFullPath`" -m $ram -boot d" -NoNewWindow -Wait
    }

    "2" {
        # VirtualBox test
        Write-ColorOutput "Setting up VirtualBox VM..." "Green"
        Write-Host ""

        $vmName = "NTARI-OS-$Edition-Test"

        # Remove existing VM if present
        $existingVM = VBoxManage list vms | Select-String $vmName
        if ($existingVM) {
            Write-Host "Removing existing VM..."
            VBoxManage unregistervm $vmName --delete 2>$null
        }

        # Create VM
        Write-Host "Creating VM: $vmName"
        VBoxManage createvm --name $vmName --ostype "Linux_64" --register

        # Configure VM
        Write-Host "Configuring VM..."
        VBoxManage modifyvm $vmName `
            --memory $ram `
            --cpus 2 `
            --vram 128 `
            --nic1 nat `
            --boot1 dvd `
            --boot2 disk `
            --firmware efi

        # Create disk
        $diskPath = Join-Path (Get-Location) "build\build-output\$vmName.vdi"
        Write-Host "Creating virtual disk..."
        VBoxManage createmedium disk `
            --filename $diskPath `
            --size 20480 `
            --format VDI

        # Add controllers
        Write-Host "Adding storage..."
        VBoxManage storagectl $vmName --name "SATA" --add sata --bootable on
        VBoxManage storagectl $vmName --name "IDE" --add ide --bootable on

        # Attach disk
        VBoxManage storageattach $vmName `
            --storagectl "SATA" `
            --port 0 `
            --device 0 `
            --type hdd `
            --medium $diskPath

        # Attach ISO
        Write-Host "Attaching ISO..."
        VBoxManage storageattach $vmName `
            --storagectl "IDE" `
            --port 0 `
            --device 0 `
            --type dvddrive `
            --medium $isoFullPath

        Write-ColorOutput "✓ VM created successfully!" "Green"
        Write-Host ""
        Write-Host "Starting VM..."

        # Start VM
        VBoxManage startvm $vmName --type gui

        Write-Host ""
        Write-ColorOutput "VM started!" "Green"
        Write-Host "To remove this test VM later:"
        Write-Host "  VBoxManage unregistervm `"$vmName`" --delete"
    }

    "3" {
        # Just show location
        Write-ColorOutput "ISO Location:" "Green"
        Write-Host $isoFullPath
        Write-Host ""
        Write-Host "You can test this ISO with:"
        Write-Host "  - QEMU: qemu-system-x86_64 -cdrom `"$isoFullPath`" -m $ram"
        Write-Host "  - VirtualBox: Create new VM and attach ISO"
        Write-Host "  - Physical USB: Use Rufus or Etcher to create bootable USB"
    }

    default {
        Write-ColorOutput "Invalid choice" "Red"
        exit 1
    }
}

Write-Host ""
Write-ColorOutput "═══════════════════════════════════════════════════════" "Cyan"
Write-ColorOutput "  Testing Checklist" "Cyan"
Write-ColorOutput "═══════════════════════════════════════════════════════" "Cyan"
Write-Host ""
Write-Host "Inside the VM, test:"
Write-Host ""
Write-Host "  [ ] GRUB menu displays"
Write-Host "  [ ] System boots to login"
Write-Host "  [ ] Login works"
Write-Host "  [ ] Run: ntari"
Write-Host "  [ ] Run: rc-status"
Write-Host "  [ ] Run: ip addr show"
Write-Host "  [ ] Run: ping 8.8.8.8"
Write-Host ""
Write-Host "See QUICK_TEST.md for full testing guide"
Write-Host ""
