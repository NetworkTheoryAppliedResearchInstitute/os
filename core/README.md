# NTARI OS Core System

This directory contains the base Alpine Linux configurations and system-level components.

## Components

### 1. Base System Configuration
- **alpine-base.yaml**: Package selection and base system config
- **kernel-config/**: Custom kernel configurations
- **init-system/**: OpenRC service definitions
- **filesystem/**: Root filesystem structure

### 2. System Services
- **ntari-network.service**: P2P network daemon
- **ntari-storage.service**: Distributed storage service
- **ntari-compute.service**: Job processing daemon
- **ntari-governance.service**: Voting and governance service

### 3. Desktop Environments
- **desktop/**: XFCE configuration for Desktop Edition
- **lite/**: Minimal GUI for Lite Edition
- **server/**: Headless configuration for Server Edition

## Building

### Prerequisites
- Alpine Linux 3.19 or later
- Docker (for cross-platform builds)
- 10GB free disk space

### Build Commands

```bash
# Build Desktop Edition (1.2GB ISO)
./build.sh --edition desktop --arch x86_64

# Build Lite Edition (400MB ISO)
./build.sh --edition lite --arch x86_64

# Build Server Edition (180MB ISO)
./build.sh --edition server --arch armv7

# Build all editions
./build.sh --all
```

## File Structure

```
core/
├── alpine-base.yaml           # Base package list
├── build.sh                   # Main build script
├── configs/
│   ├── desktop/               # Desktop Edition configs
│   ├── lite/                  # Lite Edition configs
│   └── server/                # Server Edition configs
├── services/
│   ├── ntari-network.init     # Network service
│   ├── ntari-storage.init     # Storage service
│   ├── ntari-compute.init     # Compute service
│   └── ntari-governance.init  # Governance service
├── kernel/
│   └── ntari-kernel.config    # Custom kernel configuration
└── rootfs/
    └── overlay/               # Root filesystem overlay
```

## Editions Comparison

| Feature | Desktop | Lite | Server |
|---------|---------|------|--------|
| GUI | XFCE | Minimal | None |
| Size | 1.2GB | 400MB | 180MB |
| RAM | 2GB+ | 1GB+ | 512MB+ |
| Target | Mainstream | Old PCs | Headless |

## Next Steps

After building the core system:
1. Test in VM: `./test-vm.sh`
2. Create USB installer: `cd ../installer`
3. Generate checksums: `./checksum.sh`
