@echo off
REM NTARI OS - Tool Installation Launcher
REM This batch file will launch the PowerShell script with Administrator privileges

echo.
echo ╔══════════════════════════════════════════════════════╗
echo ║                                                      ║
echo ║        NTARI OS Tool Installation                   ║
echo ║                                                      ║
echo ╚══════════════════════════════════════════════════════╝
echo.
echo This will install:
echo   • Docker Desktop
echo   • VirtualBox
echo   • Packer
echo.
echo Administrator privileges required.
echo.
pause

REM Launch PowerShell script as Administrator
powershell -Command "Start-Process PowerShell -ArgumentList '-ExecutionPolicy Bypass -File ""%~dp0install-tools.ps1""' -Verb RunAs"
