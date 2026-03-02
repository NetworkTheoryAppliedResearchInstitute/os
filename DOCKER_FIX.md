# Docker Desktop Won't Start - Quick Fix

## The Issue
Docker Desktop is installed but unable to start. This is a common Windows issue.

---

## Quick Fixes (Try in Order)

### Fix 1: Restart Docker Desktop (2 minutes)

1. **Close Docker Desktop completely:**
   - Right-click Docker icon in system tray
   - Click "Quit Docker Desktop"
   - Wait 10 seconds

2. **Restart Docker Desktop:**
   - Press Windows key
   - Type "Docker Desktop"
   - Open Docker Desktop
   - Wait 30-60 seconds for it to start

3. **Verify it's running:**
   ```bash
   docker ps
   ```
   Should show: `CONTAINER ID   IMAGE   ...` (even if empty)

---

### Fix 2: Restart WSL 2 (3 minutes)

Docker Desktop uses WSL 2 (Windows Subsystem for Linux).

**PowerShell (Run as Administrator):**

```powershell
# Stop WSL
wsl --shutdown

# Wait 5 seconds

# Start Docker Desktop again
# It will restart WSL automatically
```

Then start Docker Desktop from Start menu.

---

### Fix 3: Restart Computer (5 minutes)

Sometimes Windows just needs a restart.

1. Save your work
2. Restart computer
3. Start Docker Desktop after restart
4. Test: `docker ps`

---

### Fix 4: Check Hyper-V/WSL 2 (5 minutes)

**PowerShell (Run as Administrator):**

```powershell
# Enable WSL 2
wsl --set-default-version 2

# Check Windows features
Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
Get-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform

# If disabled, enable them:
Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Windows-Subsystem-Linux
Enable-WindowsOptionalFeature -Online -FeatureName VirtualMachinePlatform

# Restart computer
```

---

### Fix 5: Reset Docker Desktop (10 minutes)

**Warning:** This will delete all Docker images and containers.

1. Open Docker Desktop
2. Click Settings (gear icon)
3. Go to "Troubleshoot"
4. Click "Reset to factory defaults"
5. Confirm and wait
6. Restart Docker Desktop

---

## Alternative: Use VirtualBox Instead

If Docker keeps failing, you can skip Docker and use VirtualBox:

### Install VirtualBox

1. Download: https://www.virtualbox.org/wiki/Downloads
2. Install VirtualBox
3. Restart if prompted

### Build ISO Using Alpine Linux VM

Instead of Docker, we can:
1. Create an Alpine Linux VM in VirtualBox
2. Build NTARI OS natively in Alpine
3. This actually works better for OS development!

**Would you like instructions for this approach?**

---

## Check Docker Status

```bash
# Check if Docker daemon is running
docker info

# If you see version info, Docker is running
# If you see "Cannot connect to daemon", Docker is not running

# List containers (tests connection)
docker ps

# Check Docker Desktop logs
# Docker Desktop → Settings → Troubleshoot → View Logs
```

---

## Quick Decision Tree

```
Is Docker Desktop in your system tray?
├─ NO → Start Docker Desktop from Start menu
└─ YES → Does the icon look normal (not spinning/red)?
    ├─ NO → Wait 60 seconds, then try Fix 2 (WSL restart)
    └─ YES → Try: docker ps
        ├─ Works → Docker is fine, run build script
        └─ Fails → Try Fix 2 (WSL restart)
```

---

## What to Do Now

**Recommended approach:**

1. Try Fix 2 (WSL restart) - fastest
2. If that doesn't work, try Fix 3 (restart computer)
3. If still broken, install VirtualBox (easier alternative)

Let me know which approach you'd like to try!
