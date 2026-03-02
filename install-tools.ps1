# NTARI OS - Automated Tool Installation Script
# Run as Administrator in PowerShell

param(
    [switch]$SkipDocker,
    [switch]$SkipVirtualBox,
    [switch]$SkipPacker,
    [switch]$UseChocolatey = $true
)

# Colors for output
function Write-ColorOutput {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [ValidateSet('Green','Yellow','Red','Cyan','White')]
        [string]$Color = 'White'
    )
    Write-Host $Message -ForegroundColor $Color
}

# Banner
Clear-Host
Write-ColorOutput "╔══════════════════════════════════════════════════════╗" -Color Cyan
Write-ColorOutput "║                                                      ║" -Color Cyan
Write-ColorOutput "║        NTARI OS Tool Installation Script            ║" -Color Cyan
Write-ColorOutput "║                                                      ║" -Color Cyan
Write-ColorOutput "╚══════════════════════════════════════════════════════╝" -Color Cyan
Write-Host ""

# Check Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-ColorOutput "ERROR: This script must be run as Administrator!" -Color Red
    Write-ColorOutput "Right-click PowerShell and select 'Run as Administrator'" -Color Yellow
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

Write-ColorOutput "Running as Administrator ✓" -Color Green
Write-Host ""

# Check Windows version
$osVersion = [System.Environment]::OSVersion.Version
Write-ColorOutput "Windows Version: $($osVersion.Major).$($osVersion.Minor).$($osVersion.Build)" -Color Cyan

if ($osVersion.Major -lt 10) {
    Write-ColorOutput "WARNING: Windows 10 or later is recommended" -Color Yellow
}
Write-Host ""

# Check virtualization
Write-ColorOutput "Checking virtualization support..." -Color Cyan
try {
    $vmEnabled = (Get-ComputerInfo).HyperVisorPresent
    if ($vmEnabled) {
        Write-ColorOutput "Virtualization: Enabled ✓" -Color Green
    } else {
        Write-ColorOutput "Virtualization: Not detected" -Color Yellow
        Write-ColorOutput "You may need to enable VT-x/AMD-V in BIOS" -Color Yellow
    }
} catch {
    Write-ColorOutput "Could not detect virtualization status" -Color Yellow
}
Write-Host ""

# Show what will be installed
Write-ColorOutput "This script will install:" -Color Green
if (-not $SkipDocker) { Write-Host "  • Docker Desktop (for building NTARI OS)" }
if (-not $SkipVirtualBox) { Write-Host "  • Oracle VirtualBox (for testing VMs)" }
if (-not $SkipPacker) { Write-Host "  • HashiCorp Packer (for VM image creation)" }
Write-Host ""

Write-ColorOutput "Installation method: " -Color Cyan -NoNewline
if ($UseChocolatey) {
    Write-ColorOutput "Chocolatey Package Manager" -Color Yellow
} else {
    Write-ColorOutput "Manual downloads" -Color Yellow
}
Write-Host ""

$continue = Read-Host "Continue with installation? (Y/N)"
if ($continue -ne "Y" -and $continue -ne "y") {
    Write-ColorOutput "Installation cancelled." -Color Yellow
    exit 0
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Install Chocolatey if using that method
if ($UseChocolatey) {
    Write-ColorOutput "=== Step 1: Installing Chocolatey ===" -Color Cyan
    Write-Host ""

    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-ColorOutput "Chocolatey already installed ✓" -Color Green
    } else {
        Write-ColorOutput "Installing Chocolatey package manager..." -Color Yellow
        try {
            Set-ExecutionPolicy Bypass -Scope Process -Force
            [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
            Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

            # Refresh environment
            $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

            Write-ColorOutput "Chocolatey installed successfully ✓" -Color Green
        } catch {
            Write-ColorOutput "Failed to install Chocolatey: $_" -Color Red
            Write-ColorOutput "Switching to manual installation..." -Color Yellow
            $UseChocolatey = $false
        }
    }
    Write-Host ""
}

# Install Docker Desktop
if (-not $SkipDocker) {
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-ColorOutput "=== Step 2: Installing Docker Desktop ===" -Color Cyan
    Write-Host ""

    if (Get-Command docker -ErrorAction SilentlyContinue) {
        Write-ColorOutput "Docker already installed ✓" -Color Green
        docker --version
    } else {
        if ($UseChocolatey) {
            Write-ColorOutput "Installing Docker Desktop via Chocolatey..." -Color Yellow
            Write-ColorOutput "This may take 10-15 minutes..." -Color Yellow
            try {
                choco install docker-desktop -y
                Write-ColorOutput "Docker Desktop installed ✓" -Color Green
                Write-ColorOutput "Please start Docker Desktop from the Start Menu" -Color Yellow
            } catch {
                Write-ColorOutput "Failed to install Docker Desktop via Chocolatey" -Color Red
                Write-ColorOutput "Please download manually from: https://www.docker.com/products/docker-desktop" -Color Yellow
            }
        } else {
            Write-ColorOutput "Please download Docker Desktop manually:" -Color Yellow
            Write-ColorOutput "https://www.docker.com/products/docker-desktop" -Color Cyan
            $open = Read-Host "Open download page in browser? (Y/N)"
            if ($open -eq "Y" -or $open -eq "y") {
                Start-Process "https://www.docker.com/products/docker-desktop"
            }
        }
    }
    Write-Host ""
}

# Install VirtualBox
if (-not $SkipVirtualBox) {
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-ColorOutput "=== Step 3: Installing VirtualBox ===" -Color Cyan
    Write-Host ""

    if (Test-Path "C:\Program Files\Oracle\VirtualBox\VirtualBox.exe") {
        Write-ColorOutput "VirtualBox already installed ✓" -Color Green
        & "C:\Program Files\Oracle\VirtualBox\VBoxManage.exe" --version
    } else {
        if ($UseChocolatey) {
            Write-ColorOutput "Installing VirtualBox via Chocolatey..." -Color Yellow
            try {
                choco install virtualbox -y
                Write-ColorOutput "VirtualBox installed ✓" -Color Green
            } catch {
                Write-ColorOutput "Failed to install VirtualBox via Chocolatey" -Color Red
                Write-ColorOutput "Please download manually from: https://www.virtualbox.org" -Color Yellow
            }
        } else {
            Write-ColorOutput "Please download VirtualBox manually:" -Color Yellow
            Write-ColorOutput "https://www.virtualbox.org/wiki/Downloads" -Color Cyan
            $open = Read-Host "Open download page in browser? (Y/N)"
            if ($open -eq "Y" -or $open -eq "y") {
                Start-Process "https://www.virtualbox.org/wiki/Downloads"
            }
        }
    }
    Write-Host ""
}

# Install Packer
if (-not $SkipPacker) {
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-ColorOutput "=== Step 4: Installing Packer ===" -Color Cyan
    Write-Host ""

    if (Get-Command packer -ErrorAction SilentlyContinue) {
        Write-ColorOutput "Packer already installed ✓" -Color Green
        packer --version
    } else {
        if ($UseChocolatey) {
            Write-ColorOutput "Installing Packer via Chocolatey..." -Color Yellow
            try {
                choco install packer -y

                # Refresh environment
                $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

                Write-ColorOutput "Packer installed ✓" -Color Green
            } catch {
                Write-ColorOutput "Failed to install Packer via Chocolatey" -Color Red
                Write-ColorOutput "Please download manually from: https://www.packer.io/downloads" -Color Yellow
            }
        } else {
            Write-ColorOutput "Please download Packer manually:" -Color Yellow
            Write-ColorOutput "https://www.packer.io/downloads" -Color Cyan
            $open = Read-Host "Open download page in browser? (Y/N)"
            if ($open -eq "Y" -or $open -eq "y") {
                Start-Process "https://www.packer.io/downloads"
            }
        }
    }
    Write-Host ""
}

# Summary
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-ColorOutput "=== Installation Summary ===" -Color Green
Write-Host ""

$allInstalled = $true

# Check Docker
Write-Host "Docker Desktop: " -NoNewline
if (Get-Command docker -ErrorAction SilentlyContinue) {
    Write-ColorOutput "✓ Installed" -Color Green
} else {
    Write-ColorOutput "✗ Not found" -Color Red
    $allInstalled = $false
}

# Check VirtualBox
Write-Host "VirtualBox:     " -NoNewline
if (Test-Path "C:\Program Files\Oracle\VirtualBox\VirtualBox.exe") {
    Write-ColorOutput "✓ Installed" -Color Green
} else {
    Write-ColorOutput "✗ Not found" -Color Red
    $allInstalled = $false
}

# Check Packer
Write-Host "Packer:         " -NoNewline
if (Get-Command packer -ErrorAction SilentlyContinue) {
    Write-ColorOutput "✓ Installed" -Color Green
} else {
    Write-ColorOutput "✗ Not found" -Color Red
    $allInstalled = $false
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

if ($allInstalled) {
    Write-ColorOutput "✓ All tools installed successfully!" -Color Green
    Write-Host ""
    Write-ColorOutput "Next steps:" -Color Cyan
    Write-Host "  1. Restart your computer (recommended)"
    Write-Host "  2. Start Docker Desktop from the Start Menu"
    Write-Host "  3. Open a new PowerShell or Git Bash terminal"
    Write-Host "  4. Navigate to: C:\Users\Jodson Graves\Documents\NTARI OS"
    Write-Host "  5. Run: make iso"
    Write-Host ""
} else {
    Write-ColorOutput "⚠ Some tools were not installed" -Color Yellow
    Write-Host ""
    Write-ColorOutput "Please:" -Color Cyan
    Write-Host "  1. Install missing tools manually (see above)"
    Write-Host "  2. Restart your computer"
    Write-Host "  3. Run this script again to verify"
    Write-Host ""
}

Write-ColorOutput "Documentation:" -Color Cyan
Write-Host "  • Installation guide: INSTALL_TOOLS.md"
Write-Host "  • Quick start: QUICKSTART.md"
Write-Host "  • Full docs: docs/INSTALL.md"
Write-Host ""

Read-Host "Press Enter to exit"
