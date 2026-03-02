# Uninstalling Docker, VirtualBox, and Packer

This guide will help you completely uninstall Docker Desktop, VirtualBox, and Packer from your Windows machine.

## Quick Uninstall (Automated)

### Option 1: Double-Click (Easiest)

1. **Double-click**: `uninstall-tools.bat`
2. Click **"Yes"** when prompted for Administrator access
3. Confirm uninstallation when asked
4. Wait for completion
5. **Restart your computer**

### Option 2: PowerShell

1. **Right-click PowerShell** → Run as Administrator
2. Run:
   ```powershell
   cd "C:\Users\Jodson Graves\Documents\NTARI OS"
   Set-ExecutionPolicy Bypass -Scope Process
   .\uninstall-tools.ps1
   ```
3. **Restart your computer**

---

## Manual Uninstallation

### 1. Uninstall Docker Desktop

#### Via Windows Settings

1. Open **Settings** → **Apps** → **Apps & features**
2. Search for **"Docker Desktop"**
3. Click **Uninstall**
4. Follow the prompts

#### Via Control Panel

1. Open **Control Panel** → **Programs and Features**
2. Find **"Docker Desktop"**
3. Right-click → **Uninstall**

#### Manual Cleanup

After uninstalling, remove remaining files:

```powershell
# Run as Administrator
Remove-Item -Path "$env:APPDATA\Docker" -Recurse -Force
Remove-Item -Path "$env:LOCALAPPDATA\Docker" -Recurse -Force
Remove-Item -Path "C:\Program Files\Docker" -Recurse -Force
Remove-Item -Path "$env:USERPROFILE\.docker" -Recurse -Force
```

#### WSL 2 Cleanup (Optional)

If you want to remove Docker's WSL distributions:

```powershell
wsl --unregister docker-desktop
wsl --unregister docker-desktop-data
```

---

### 2. Uninstall VirtualBox

#### Via Windows Settings

1. Open **Settings** → **Apps** → **Apps & features**
2. Search for **"VirtualBox"**
3. Click **Uninstall**
4. Follow the prompts

#### Via Control Panel

1. Open **Control Panel** → **Programs and Features**
2. Find **"Oracle VM VirtualBox"**
3. Right-click → **Uninstall**

#### Manual Cleanup

Remove remaining files:

```powershell
# Run as Administrator
Remove-Item -Path "C:\Program Files\Oracle\VirtualBox" -Recurse -Force
Remove-Item -Path "$env:USERPROFILE\.VirtualBox" -Recurse -Force
```

**Note**: VM files are typically stored in:
- `C:\Users\YourName\VirtualBox VMs`

Remove these manually if you want to delete all VMs.

---

### 3. Uninstall Packer

#### Via Chocolatey (if installed via Chocolatey)

```powershell
choco uninstall packer -y
```

#### Manual Removal

1. **Delete Packer directory**:
   ```powershell
   Remove-Item -Path "C:\Program Files\Packer" -Recurse -Force
   ```

2. **Remove from PATH**:
   - Right-click **This PC** → **Properties**
   - Click **Advanced system settings**
   - Click **Environment Variables**
   - Under **System variables**, select **Path**
   - Click **Edit**
   - Remove entry: `C:\Program Files\Packer`
   - Click **OK**

3. **Restart terminal** or computer

---

## Complete System Cleanup

### Remove All Tool-Related Files

```powershell
# Run as Administrator

# Docker
Remove-Item -Path "$env:APPDATA\Docker" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:LOCALAPPDATA\Docker" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "C:\Program Files\Docker" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:USERPROFILE\.docker" -Recurse -Force -ErrorAction SilentlyContinue

# VirtualBox
Remove-Item -Path "C:\Program Files\Oracle\VirtualBox" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:USERPROFILE\.VirtualBox" -Recurse -Force -ErrorAction SilentlyContinue

# Packer
Remove-Item -Path "C:\Program Files\Packer" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "$env:LOCALAPPDATA\Packer" -Recurse -Force -ErrorAction SilentlyContinue
```

### Remove Chocolatey (Optional)

If you installed Chocolatey only for these tools:

```powershell
# Run as Administrator
Remove-Item -Path "$env:ChocolateyInstall" -Recurse -Force
[Environment]::SetEnvironmentVariable("ChocolateyInstall", $null, "Machine")
```

### Remove WSL 2 (Optional)

If you no longer need WSL 2:

```powershell
# List all distributions
wsl --list

# Unregister all
wsl --unregister Ubuntu
wsl --unregister docker-desktop
wsl --unregister docker-desktop-data

# Disable WSL feature (optional)
dism.exe /online /disable-feature /featurename:Microsoft-Windows-Subsystem-Linux /norestart
dism.exe /online /disable-feature /featurename:VirtualMachinePlatform /norestart
```

---

## Verification

After uninstallation, verify tools are removed:

```bash
# These should all return "command not found"
docker --version
VBoxManage --version
packer --version
```

---

## Troubleshooting

### Docker Won't Uninstall

**Issue**: "Docker Desktop is still running"

**Solution**:
1. Open Task Manager (Ctrl+Shift+Esc)
2. Find "Docker Desktop" processes
3. Right-click → End task
4. Try uninstalling again

**Issue**: "Access denied"

**Solution**:
1. Run PowerShell as Administrator
2. Stop Docker service:
   ```powershell
   Stop-Service docker
   ```
3. Try uninstalling again

### VirtualBox Won't Uninstall

**Issue**: "VirtualBox is in use"

**Solution**:
1. Close all VirtualBox windows
2. Open Task Manager
3. End all "VirtualBox" processes
4. Try again

**Issue**: Driver issues

**Solution**:
1. Uninstall VirtualBox
2. Restart computer
3. Use Driver Store Explorer to remove VirtualBox drivers
4. Restart again

### Leftover Files

**Issue**: Some files remain after uninstall

**Solution**:
1. Run the cleanup script:
   ```powershell
   .\uninstall-tools.ps1
   ```
2. Manually delete remaining folders (see Manual Cleanup sections)
3. Restart computer

---

## What Gets Removed

### Docker Desktop
- Application files
- Docker images and containers
- WSL 2 distributions (docker-desktop, docker-desktop-data)
- User settings and configurations
- Docker CLI and daemon

### VirtualBox
- VirtualBox application
- VirtualBox drivers and kernel modules
- VirtualBox settings
- **Note**: VM files in `VirtualBox VMs` folder remain unless manually deleted

### Packer
- Packer binary
- Packer plugins
- PATH entry

---

## Keeping Your Data

### Before Uninstalling

If you want to keep your work:

**Docker**:
```bash
# Export Docker images
docker save my-image:tag > my-image.tar

# Export containers
docker export container-name > container.tar
```

**VirtualBox**:
- Export VMs as OVA files: File → Export Appliance
- Or copy VM folders from `C:\Users\YourName\VirtualBox VMs`

**NTARI OS Build**:
- Keep the `build-output/` folder
- Keep your ISO and VM images

---

## Reinstalling Later

If you want to reinstall these tools later:

1. Run `install-tools.bat` again
2. Or download manually:
   - Docker: https://www.docker.com/products/docker-desktop
   - VirtualBox: https://www.virtualbox.org/wiki/Downloads
   - Packer: https://www.packer.io/downloads

---

## Alternative: Disable Without Uninstalling

If you just want to free up resources temporarily:

### Docker Desktop
- Right-click Docker icon → Quit Docker Desktop
- Disable startup: Settings → General → Uncheck "Start Docker Desktop when you log in"

### VirtualBox
- Close VirtualBox
- VMs only use resources when running

---

## Post-Uninstall

### Restart Required

After uninstallation:
1. **Restart your computer**
2. This ensures:
   - All services are stopped
   - PATH is updated
   - Drivers are removed
   - Files can be deleted

### Check Disk Space

After uninstall and restart:
```powershell
# Check how much space was freed
Get-PSDrive C | Select-Object Used,Free
```

You should see several GB of space freed.

---

## Summary

### Quick Uninstall Steps

1. ✅ Double-click `uninstall-tools.bat`
2. ✅ Confirm uninstallation
3. ✅ Wait for completion
4. ✅ Restart computer
5. ✅ Verify removal

### Manual Uninstall Steps

1. ✅ Uninstall via Settings/Control Panel
2. ✅ Run cleanup script
3. ✅ Remove leftover files
4. ✅ Clean PATH variable
5. ✅ Restart computer

### Complete Cleanup

1. ✅ Remove all tools
2. ✅ Delete user data folders
3. ✅ Remove WSL distributions (optional)
4. ✅ Remove Chocolatey (optional)
5. ✅ Restart computer

---

## Support

If you encounter issues:
- Check the Troubleshooting section above
- Run `uninstall-tools.ps1` as Administrator
- Manually remove files as documented
- Restart computer between attempts

---

**Need to reinstall?** See `INSTALL_TOOLS.md`

**Questions?** Check the troubleshooting section or create a GitHub issue.
