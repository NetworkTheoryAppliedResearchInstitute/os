#!/bin/bash
# NTARI OS VM Testing Script
# Automated testing for QEMU and VirtualBox
# Version: 1.0.0

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
EDITION="${1:-server}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build/build-output"

# Test settings
RAM_SERVER=2048
RAM_DESKTOP=4096
RAM_LITE=2048

echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  NTARI OS VM Testing Suite${NC}"
echo -e "${BLUE}  Edition: ${EDITION}${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""

# Function to find the latest ISO
find_iso() {
    local edition=$1
    local iso=$(ls -t "${BUILD_DIR}/ntari-${edition}"-*.iso 2>/dev/null | head -1)
    echo "$iso"
}

# Function to test with QEMU
test_qemu() {
    local iso=$1
    local ram=$2

    echo -e "${YELLOW}[QEMU TEST]${NC} Starting QEMU boot test..."
    echo "────────────────────────────────────────────────────────"
    echo "ISO: $(basename "$iso")"
    echo "RAM: ${ram}MB"
    echo ""
    echo "Controls:"
    echo "  - Ctrl+Alt+G: Release mouse"
    echo "  - Ctrl+Alt+F: Toggle fullscreen"
    echo "  - Ctrl+A, X: Quit QEMU"
    echo ""

    # Check for KVM support (Linux only)
    KVM_FLAG=""
    if [ "$(uname)" == "Linux" ] && [ -e /dev/kvm ]; then
        KVM_FLAG="-enable-kvm"
        echo -e "${GREEN}✓${NC} KVM acceleration enabled"
    fi

    # Create a small virtual disk for testing installation
    DISK_IMG="${BUILD_DIR}/test-disk.img"
    if [ ! -f "$DISK_IMG" ]; then
        echo "Creating test virtual disk (20GB)..."
        qemu-img create -f qcow2 "$DISK_IMG" 20G
    fi

    echo ""
    echo "Starting VM..."
    echo ""

    # Run QEMU with network support
    qemu-system-x86_64 \
        -cdrom "$iso" \
        -m "$ram" \
        $KVM_FLAG \
        -boot d \
        -drive file="$DISK_IMG",format=qcow2 \
        -netdev user,id=net0 \
        -device e1000,netdev=net0 \
        -vga std \
        -display sdl \
        -name "NTARI OS ${EDITION}" \
        2>&1 | tee "${BUILD_DIR}/qemu-test.log"

    echo ""
    echo -e "${GREEN}QEMU test completed${NC}"
}

# Function to create VirtualBox VM
test_virtualbox() {
    local iso=$1
    local ram=$2

    echo -e "${YELLOW}[VIRTUALBOX]${NC} Creating VirtualBox VM..."
    echo "────────────────────────────────────────────────────────"

    VM_NAME="NTARI-OS-${EDITION}-Test"

    # Check if VM already exists
    if VBoxManage list vms | grep -q "$VM_NAME"; then
        echo "VM already exists. Removing old VM..."
        VBoxManage unregistervm "$VM_NAME" --delete 2>/dev/null || true
    fi

    # Create VM
    echo "Creating VM: $VM_NAME"
    VBoxManage createvm --name "$VM_NAME" --ostype "Linux_64" --register

    # Configure VM
    echo "Configuring VM settings..."
    VBoxManage modifyvm "$VM_NAME" \
        --memory "$ram" \
        --cpus 2 \
        --vram 128 \
        --nic1 nat \
        --boot1 dvd \
        --boot2 disk \
        --boot3 none \
        --boot4 none \
        --firmware efi

    # Create and attach virtual disk
    DISK_PATH="${BUILD_DIR}/${VM_NAME}.vdi"
    echo "Creating virtual disk..."
    VBoxManage createmedium disk \
        --filename "$DISK_PATH" \
        --size 20480 \
        --format VDI

    # Add storage controllers
    echo "Adding storage controllers..."
    VBoxManage storagectl "$VM_NAME" \
        --name "SATA" \
        --add sata \
        --bootable on

    VBoxManage storagectl "$VM_NAME" \
        --name "IDE" \
        --add ide \
        --bootable on

    # Attach disk
    VBoxManage storageattach "$VM_NAME" \
        --storagectl "SATA" \
        --port 0 \
        --device 0 \
        --type hdd \
        --medium "$DISK_PATH"

    # Attach ISO
    echo "Attaching ISO..."
    VBoxManage storageattach "$VM_NAME" \
        --storagectl "IDE" \
        --port 0 \
        --device 0 \
        --type dvddrive \
        --medium "$iso"

    echo ""
    echo -e "${GREEN}✓${NC} VirtualBox VM created successfully!"
    echo ""
    echo "VM Name: $VM_NAME"
    echo "RAM: ${ram}MB"
    echo "Disk: 20GB"
    echo "ISO: $(basename "$iso")"
    echo ""
    echo "Starting VM..."

    # Start VM with GUI
    VBoxManage startvm "$VM_NAME" --type gui

    echo ""
    echo -e "${GREEN}VirtualBox test started${NC}"
    echo ""
    echo "To remove this test VM later, run:"
    echo "  VBoxManage unregistervm \"$VM_NAME\" --delete"
}

# Function to show test checklist
show_checklist() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  Testing Checklist${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Boot & System:"
    echo "  [ ] GRUB menu displays"
    echo "  [ ] System boots to login"
    echo "  [ ] Login works (check credentials)"
    echo "  [ ] Shell is responsive"
    echo ""
    echo "NTARI Components:"
    echo "  [ ] Run: ntari"
    echo "  [ ] Check: ls -la /opt/ntari/"
    echo "  [ ] Check: cat /etc/ntari/version"
    echo "  [ ] Check: rc-status"
    echo ""
    echo "Network:"
    echo "  [ ] Run: ip link show"
    echo "  [ ] Run: ip addr show"
    echo "  [ ] Run: ping -c 4 8.8.8.8"
    echo "  [ ] Test DNS: ping google.com"
    echo ""

    if [ "$EDITION" == "desktop" ]; then
        echo "Desktop Edition:"
        echo "  [ ] XFCE desktop loads"
        echo "  [ ] Mouse and keyboard work"
        echo "  [ ] Terminal launches"
        echo "  [ ] File manager works"
        echo "  [ ] Network manager shows"
        echo ""
    fi

    echo "Performance:"
    echo "  [ ] Note boot time"
    echo "  [ ] Check RAM usage: free -h"
    echo "  [ ] Check disk usage: df -h"
    echo ""
}

# Main execution
main() {
    # Determine RAM based on edition
    case "$EDITION" in
        server)
            RAM=$RAM_SERVER
            ;;
        desktop)
            RAM=$RAM_DESKTOP
            ;;
        lite)
            RAM=$RAM_LITE
            ;;
        *)
            echo -e "${RED}Invalid edition: $EDITION${NC}"
            echo "Usage: $0 [server|desktop|lite]"
            exit 1
            ;;
    esac

    # Find ISO
    ISO=$(find_iso "$EDITION")

    if [ -z "$ISO" ]; then
        echo -e "${RED}✗${NC} No ISO found for edition: $EDITION"
        echo ""
        echo "Build ISO first with:"
        echo "  cd build"
        echo "  ./docker-build.sh $EDITION"
        exit 1
    fi

    echo -e "${GREEN}✓${NC} Found ISO: $(basename "$ISO")"
    echo "  Size: $(du -h "$ISO" | cut -f1)"
    echo ""

    # Check available virtualization tools
    HAS_QEMU=false
    HAS_VBOX=false

    if command -v qemu-system-x86_64 &> /dev/null; then
        HAS_QEMU=true
        echo -e "${GREEN}✓${NC} QEMU available"
    else
        echo -e "${YELLOW}○${NC} QEMU not found"
    fi

    if command -v VBoxManage &> /dev/null; then
        HAS_VBOX=true
        echo -e "${GREEN}✓${NC} VirtualBox available"
    else
        echo -e "${YELLOW}○${NC} VirtualBox not found"
    fi

    echo ""

    # Prompt user for testing method
    if [ "$HAS_QEMU" == false ] && [ "$HAS_VBOX" == false ]; then
        echo -e "${RED}✗${NC} No virtualization software found!"
        echo ""
        echo "Please install one of:"
        echo "  - QEMU: https://www.qemu.org/download/"
        echo "  - VirtualBox: https://www.virtualbox.org/wiki/Downloads"
        exit 1
    fi

    # Choose test method
    if [ "$HAS_QEMU" == true ] && [ "$HAS_VBOX" == true ]; then
        echo "Available test methods:"
        echo "  1) QEMU (fast, lightweight)"
        echo "  2) VirtualBox (full-featured, persistent)"
        echo ""
        read -p "Choose [1/2]: " choice
        case $choice in
            1)
                test_qemu "$ISO" "$RAM"
                ;;
            2)
                test_virtualbox "$ISO" "$RAM"
                ;;
            *)
                echo "Invalid choice"
                exit 1
                ;;
        esac
    elif [ "$HAS_QEMU" == true ]; then
        test_qemu "$ISO" "$RAM"
    elif [ "$HAS_VBOX" == true ]; then
        test_virtualbox "$ISO" "$RAM"
    fi

    # Show checklist after test
    show_checklist
}

# Run main
main
