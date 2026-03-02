# Quick NTARIOS Build Script
$projectPath = "C:\Users\Jodson Graves\Documents\NTARIOS\ntari-os"
Write-Host "Building NTARIOS Server ISO..." -ForegroundColor Green
docker run --rm --user root -v "${projectPath}:/build" -w /build/build ntari-builder sh -c "apk add --no-cache xorriso squashfs-tools grub grub-efi syslinux mtools dosfstools; ./build-iso.sh server"
if ($LASTEXITCODE -eq 0) {
    Write-Host "Build successful!" -ForegroundColor Green
    Get-ChildItem -Path "$projectPath\build\build-output\*.iso"
}
