# NTARI OS - Tool Uninstallation Script
# Run as Administrator in PowerShell

param(
    [switch]$SkipDocker,
    [switch]$SkipVirtualBox,
    [switch]$SkipPacker,
    [switch]$Force
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
Write-ColorOutput "╔══════════════════════════════════════════════════════╗" -Color Red
Write-ColorOutput "║                                                      ║" -Color Red
Write-ColorOutput "║        NTARI OS Tool Uninstallation Script          ║" -Color Red
Write-ColorOutput "║                                                      ║" -Color Red
Write-ColorOutput "╚══════════════════════════════════════════════════════╝" -Color Red
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

# Show what will be uninstalled
Write-ColorOutput "This script will uninstall:" -Color Yellow
if (-not $SkipDocker) { Write-Host "  • Docker Desktop" }
if (-not $SkipVirtualBox) { Write-Host "  • Oracle VirtualBox" }
if (-not $SkipPacker) { Write-Host "  • HashiCorp Packer" }
Write-Host ""

Write-ColorOutput "WARNING: This will remove all installed tools!" -Color Red
Write-Host ""

if (-not $Force) {
    $continue = Read-Host "Continue with uninstallation? (yes/no)"
    if ($continue -ne "yes") {
        Write-ColorOutput "Uninstallation cancelled." -Color Yellow
        exit 0
    }
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

# Uninstall Docker Desktop
if (-not $SkipDocker) {
    Write-ColorOutput "=== Uninstalling Docker Desktop ===" -Color Cyan
    Write-Host ""

    # Check if Docker is installed
    $dockerInstalled = Get-Command docker -ErrorAction SilentlyContinue
    $dockerPath = "C:\Program Files\Docker\Docker\Docker Desktop Installer.exe"

    if ($dockerInstalled -or (Test-Path $dockerPath)) {
        Write-ColorOutput "Docker Desktop found. Uninstalling..." -Color Yellow

        # Try Chocolatey first
        if (Get-Command choco -ErrorAction SilentlyContinue) {
            Write-ColorOutput "Using Chocolatey to uninstall..." -Color Yellow
            try {
                choco uninstall docker-desktop -y
                Write-ColorOutput "Docker Desktop uninstalled via Chocolatey ✓" -Color Green
            } catch {
                Write-ColorOutput "Chocolatey uninstall failed, trying Windows uninstaller..." -Color Yellow
            }
        }

        # Try Windows Apps & Features
        Write-ColorOutput "Checking Windows uninstaller..." -Color Yellow
        $docker = Get-Package -Name "Docker Desktop" -ErrorAction SilentlyContinue
        if ($docker) {
            try {
                Uninstall-Package -Name "Docker Desktop" -Force
                Write-ColorOutput "Docker Desktop uninstalled ✓" -Color Green
            } catch {
                Write-ColorOutput "Failed to uninstall Docker Desktop: $_" -Color Red
                Write-ColorOutput "Please uninstall manually via Settings → Apps" -Color Yellow
            }
        }

        # Manual cleanup
        Write-ColorOutput "Cleaning up Docker files..." -Color Yellow
        $dockerDirs = @(
            "$env:APPDATA\Docker",
            "$env:LOCALAPPDATA\Docker",
            "C:\Program Files\Docker",
            "$env:USERPROFILE\.docker"
        )

        foreach ($dir in $dockerDirs) {
            if (Test-Path $dir) {
                try {
                    Remove-Item -Path $dir -Recurse -Force -ErrorAction SilentlyContinue
                    Write-ColorOutput "Removed: $dir" -Color Green
                } catch {
                    Write-ColorOutput "Could not remove: $dir" -Color Yellow
                }
            }
        }
    } else {
        Write-ColorOutput "Docker Desktop not found (already uninstalled)" -Color Green
    }
    Write-Host ""
}

# Uninstall VirtualBox
if (-not $SkipVirtualBox) {
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-ColorOutput "=== Uninstalling VirtualBox ===" -Color Cyan
    Write-Host ""

    $vboxPath = "C:\Program Files\Oracle\VirtualBox"

    if (Test-Path $vboxPath) {
        Write-ColorOutput "VirtualBox found. Uninstalling..." -Color Yellow

        # Try Chocolatey first
        if (Get-Command choco -ErrorAction SilentlyContinue) {
            Write-ColorOutput "Using Chocolatey to uninstall..." -Color Yellow
            try {
                choco uninstall virtualbox -y
                Write-ColorOutput "VirtualBox uninstalled via Chocolatey ✓" -Color Green
            } catch {
                Write-ColorOutput "Chocolatey uninstall failed, trying Windows uninstaller..." -Color Yellow
            }
        }

        # Try Windows uninstaller
        $vbox = Get-Package -Name "*VirtualBox*" -ErrorAction SilentlyContinue
        if ($vbox) {
            try {
                Uninstall-Package -Name $vbox.Name -Force
                Write-ColorOutput "VirtualBox uninstalled ✓" -Color Green
            } catch {
                Write-ColorOutput "Failed to uninstall VirtualBox: $_" -Color Red
                Write-ColorOutput "Please uninstall manually via Settings → Apps" -Color Yellow
            }
        }

        # Manual cleanup
        Write-ColorOutput "Cleaning up VirtualBox files..." -Color Yellow
        if (Test-Path $vboxPath) {
            try {
                Remove-Item -Path $vboxPath -Recurse -Force -ErrorAction SilentlyContinue
                Write-ColorOutput "Removed: $vboxPath" -Color Green
            } catch {
                Write-ColorOutput "Could not remove: $vboxPath" -Color Yellow
            }
        }
    } else {
        Write-ColorOutput "VirtualBox not found (already uninstalled)" -Color Green
    }
    Write-Host ""
}

# Uninstall Packer
if (-not $SkipPacker) {
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-ColorOutput "=== Uninstalling Packer ===" -Color Cyan
    Write-Host ""

    # Check if Packer is installed
    $packerInstalled = Get-Command packer -ErrorAction SilentlyContinue

    if ($packerInstalled) {
        Write-ColorOutput "Packer found. Uninstalling..." -Color Yellow

        # Try Chocolatey first
        if (Get-Command choco -ErrorAction SilentlyContinue) {
            Write-ColorOutput "Using Chocolatey to uninstall..." -Color Yellow
            try {
                choco uninstall packer -y
                Write-ColorOutput "Packer uninstalled via Chocolatey ✓" -Color Green
            } catch {
                Write-ColorOutput "Chocolatey uninstall failed, trying manual removal..." -Color Yellow
            }
        }

        # Manual removal
        $packerLocations = @(
            "C:\Program Files\Packer",
            "C:\HashiCorp\Packer",
            "$env:LOCALAPPDATA\Packer"
        )

        foreach ($location in $packerLocations) {
            if (Test-Path $location) {
                try {
                    Remove-Item -Path $location -Recurse -Force
                    Write-ColorOutput "Removed: $location" -Color Green
                } catch {
                    Write-ColorOutput "Could not remove: $location" -Color Yellow
                }
            }
        }

        # Remove from PATH
        Write-ColorOutput "Cleaning up PATH..." -Color Yellow
        $currentPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
        $pathsToRemove = @("C:\Program Files\Packer", "C:\HashiCorp\Packer")

        foreach ($pathToRemove in $pathsToRemove) {
            if ($currentPath -like "*$pathToRemove*") {
                $newPath = ($currentPath -split ';' | Where-Object { $_ -ne $pathToRemove }) -join ';'
                try {
                    [Environment]::SetEnvironmentVariable("Path", $newPath, "Machine")
                    Write-ColorOutput "Removed from PATH: $pathToRemove" -Color Green
                } catch {
                    Write-ColorOutput "Could not update PATH" -Color Yellow
                }
            }
        }
    } else {
        Write-ColorOutput "Packer not found (already uninstalled)" -Color Green
    }
    Write-Host ""
}

# Clean up WSL 2 (optional)
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-ColorOutput "=== WSL 2 Cleanup (Optional) ===" -Color Cyan
Write-Host ""

$cleanWSL = Read-Host "Remove WSL 2 as well? (yes/no)"
if ($cleanWSL -eq "yes") {
    Write-ColorOutput "Uninstalling WSL 2..." -Color Yellow
    try {
        wsl --unregister Ubuntu
        wsl --unregister docker-desktop
        wsl --unregister docker-desktop-data
        Write-ColorOutput "WSL distributions removed ✓" -Color Green
    } catch {
        Write-ColorOutput "Some WSL distributions could not be removed" -Color Yellow
    }
}

# Summary
Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-ColorOutput "=== Uninstallation Summary ===" -Color Green
Write-Host ""

# Check what's left
Write-Host "Docker Desktop: " -NoNewline
if (Get-Command docker -ErrorAction SilentlyContinue) {
    Write-ColorOutput "✗ Still installed" -Color Yellow
} else {
    Write-ColorOutput "✓ Removed" -Color Green
}

Write-Host "VirtualBox:     " -NoNewline
if (Test-Path "C:\Program Files\Oracle\VirtualBox\VirtualBox.exe") {
    Write-ColorOutput "✗ Still installed" -Color Yellow
} else {
    Write-ColorOutput "✓ Removed" -Color Green
}

Write-Host "Packer:         " -NoNewline
if (Get-Command packer -ErrorAction SilentlyContinue) {
    Write-ColorOutput "✗ Still installed" -Color Yellow
} else {
    Write-ColorOutput "✓ Removed" -Color Green
}

Write-Host ""
Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""

Write-ColorOutput "Uninstallation complete!" -Color Green
Write-Host ""
Write-ColorOutput "Note:" -Color Cyan
Write-Host "  • Restart your computer to complete cleanup"
Write-Host "  • Some files may require manual removal"
Write-Host "  • VM files in VirtualBox remain (if any)"
Write-Host ""

Write-ColorOutput "Manual cleanup locations:" -Color Yellow
Write-Host "  • %APPDATA%\Docker"
Write-Host "  • %USERPROFILE%\.docker"
Write-Host "  • %USERPROFILE%\VirtualBox VMs"
Write-Host ""

Read-Host "Press Enter to exit"
