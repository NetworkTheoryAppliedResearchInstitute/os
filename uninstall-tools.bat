@echo off
REM NTARI OS - Tool Uninstallation Launcher
REM This batch file will launch the PowerShell uninstall script with Administrator privileges

echo.
echo ╔══════════════════════════════════════════════════════╗
echo ║                                                      ║
echo ║        NTARI OS Tool Uninstallation                 ║
echo ║                                                      ║
echo ╚══════════════════════════════════════════════════════╝
echo.
echo This will uninstall:
echo   • Docker Desktop
echo   • VirtualBox
echo   • Packer
echo.
echo WARNING: This will remove all installed tools!
echo.
pause

REM Launch PowerShell script as Administrator
powershell -Command "Start-Process PowerShell -ArgumentList '-ExecutionPolicy Bypass -File ""%~dp0uninstall-tools.ps1""' -Verb RunAs"
