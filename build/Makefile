# NTARI OS v1.5 Makefile
# Network-First Cooperative Infrastructure OS
# Alpine 3.23 + ROS2 Jazzy + Cyclone DDS

NTARI_VERSION  := 1.5.0
ALPINE_VERSION := 3.23
ARCH           := x86_64
EDITION        := server
BUILD_DATE     := $(shell date +%Y%m%d)

ISO_NAME       := ntari-os-$(NTARI_VERSION)-$(ARCH)-$(EDITION)-$(BUILD_DATE).iso
BUILD_DIR      := $(CURDIR)/build-output
PROJECT_DIR    := $(abspath $(CURDIR)/..)

DOCKER_IMAGE   := ntari-builder:1.5
DOCKER_RUN     := docker run --rm --privileged \
                    -v "$(PROJECT_DIR):/workspace" \
                    -w /workspace \
                    $(DOCKER_IMAGE)

.PHONY: all iso test clean clean-all docker-build docker-run vbox-test vbox-clean help

# ─────────────────────────────────────────────────────────
# Default target
# ─────────────────────────────────────────────────────────

all: iso

# ─────────────────────────────────────────────────────────
# Build Docker image (build environment)
# ─────────────────────────────────────────────────────────

docker-build:
	@echo "→ Building NTARI OS build environment (Alpine 3.23)..."
	docker build -t $(DOCKER_IMAGE) $(CURDIR)/
	@echo "✓ Docker image ready: $(DOCKER_IMAGE)"

# ─────────────────────────────────────────────────────────
# Build ISO (inside Docker — uses mkimage, proper boot)
# ─────────────────────────────────────────────────────────

iso: docker-build
	@echo ""
	@echo "══════════════════════════════════════════════════"
	@echo "  Building NTARI OS v$(NTARI_VERSION) ISO"
	@echo "  Edition : $(EDITION)"
	@echo "  Alpine  : $(ALPINE_VERSION)"
	@echo "  Arch    : $(ARCH)"
	@echo "══════════════════════════════════════════════════"
	@echo ""
	$(DOCKER_RUN) /workspace/build/build-iso.sh $(EDITION)
	@echo ""
	@echo "✓ ISO build complete: $(BUILD_DIR)/$(ISO_NAME)"

# ─────────────────────────────────────────────────────────
# Run integration tests
# ─────────────────────────────────────────────────────────

test:
	@echo "Run: sh tests/integration/test-ros2-phase6.sh"
	@echo "Run: sh tests/ixp/test_bgp_node.sh"

# ─────────────────────────────────────────────────────────
# Interactive Docker shell (for debugging)
# ─────────────────────────────────────────────────────────

docker-run: docker-build
	@echo "→ Opening interactive build shell..."
	@echo "   Run: /workspace/build/build-iso.sh server"
	docker run --rm -it --privileged \
		-v "$(PROJECT_DIR):/workspace" \
		-w /workspace \
		$(DOCKER_IMAGE) /bin/bash

# ─────────────────────────────────────────────────────────
# VirtualBox boot test (requires VBoxManage)
# ─────────────────────────────────────────────────────────

VBOXMANAGE := "C:/Program Files/Oracle/VirtualBox/VBoxManage.exe"

vbox-test:
	@ISO="$(BUILD_DIR)/$(ISO_NAME)"; \
	if [ ! -f "$$ISO" ]; then \
		echo "✗ ISO not found. Run: make iso"; exit 1; \
	fi; \
	echo "→ Creating VirtualBox test VM (NTARI-OS-Test)..."; \
	$(VBOXMANAGE) createvm \
		--name "NTARI-OS-Test" --ostype "Linux_64" --register; \
	$(VBOXMANAGE) modifyvm \
		"NTARI-OS-Test" --memory 2048 --cpus 2 --vram 16 \
		--boot1 dvd --boot2 none --audio none --usb off; \
	$(VBOXMANAGE) storagectl \
		"NTARI-OS-Test" --name "IDE" --add ide; \
	$(VBOXMANAGE) storageattach \
		"NTARI-OS-Test" --storagectl "IDE" --port 0 --device 0 \
		--type dvddrive --medium "$$ISO"; \
	echo "✓ VM created. Starting..."; \
	$(VBOXMANAGE) startvm "NTARI-OS-Test"

vbox-clean:
	-$(VBOXMANAGE) controlvm "NTARI-OS-Test" poweroff 2>/dev/null || true
	-$(VBOXMANAGE) unregistervm "NTARI-OS-Test" --delete 2>/dev/null || true
	@echo "✓ Test VM removed"

# ─────────────────────────────────────────────────────────
# Clean
# ─────────────────────────────────────────────────────────

clean:
	rm -rf $(BUILD_DIR)/work-*
	rm -rf $(BUILD_DIR)/overlay
	rm -rf $(BUILD_DIR)/aports
	rm -f  $(BUILD_DIR)/*.iso
	rm -f  $(BUILD_DIR)/*.sha256
	rm -f  $(BUILD_DIR)/*.qcow2
	rm -f  $(BUILD_DIR)/*.vmdk
	rm -f  $(BUILD_DIR)/build.log
	@echo "✓ Clean complete"

clean-all: clean
	rm -rf $(BUILD_DIR)
	@echo "✓ Full clean complete"

# ─────────────────────────────────────────────────────────
# Help
# ─────────────────────────────────────────────────────────

help:
	@echo ""
	@echo "NTARI OS v$(NTARI_VERSION) Build System"
	@echo "════════════════════════════════════════"
	@echo ""
	@echo "Targets:"
	@echo "  make iso          Build bootable ISO (default)"
	@echo "  make test         List available integration tests"
	@echo "  make docker-build Build the Docker build environment"
	@echo "  make docker-run   Open interactive build shell"
	@echo "  make vbox-test    Create + launch VirtualBox test VM"
	@echo "  make vbox-clean   Remove VirtualBox test VM"
	@echo "  make clean        Remove build artifacts"
	@echo "  make clean-all    Remove all build output"
	@echo ""
	@echo "Variables:"
	@echo "  EDITION=$(EDITION)"
	@echo "  ARCH=$(ARCH)"
	@echo "  NTARI_VERSION=$(NTARI_VERSION)"
	@echo ""
	@echo "Output: $(BUILD_DIR)/$(ISO_NAME)"
	@echo ""
	@echo "Requirements:"
	@echo "  - Docker Desktop (for iso target)"
	@echo "  - VirtualBox 7.2.6 (for vbox-test target)"
	@echo ""
