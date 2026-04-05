# NTARI OS — core/

Utility scripts that run on the live node. These are distinct from the ISO
build scripts in `build/` and the OpenRC service definitions in
`config/services/`.

## Files

### `ntari-cli.sh`
Interactive CLI management tool for NTARI OS. Provides a shell interface for
inspecting and controlling the services running on a node. Reads node
configuration from `/etc/ntari/ntari.conf` and data from `/var/lib/ntari`.

### `ntari-init.sh`
Early first-boot initialization helper. Sets up the base directory structure
(`/etc/ntari`, `/var/lib/ntari`, `/var/log/ntari`) and prepares the
environment before the edition-aware init in `scripts/ntari-init.sh` runs.

## What Is Not Here

The following are described in the project's old README and **do not exist**
in this directory or anywhere in the repository:

- `ntari-network.init` / `ntari-storage.init` / `ntari-compute.init` / `ntari-governance.init`
- `alpine-base.yaml`
- `kernel/ntari-kernel.config`
- `desktop/`, `lite/`, `server/` edition subdirectories
- `build.sh` (the build script is `build/build-iso.sh`)

NTARI OS has two editions — `server` (headless) and `ros2` (Jazzy + Cyclone
DDS). There is no desktop or lite edition. The Alpine version target is 3.23,
not 3.19.

## Related Directories

| Directory | Purpose |
|---|---|
| `build/` | ISO builder (`build-iso.sh`), Dockerfile, Docker wrapper |
| `scripts/` | Runtime scripts copied into the ISO overlay |
| `config/services/` | OpenRC initd files for all NTARI service nodes |
| `packages/` | Custom APKBUILDs (Cyclone DDS, IXP packages) |
| `docs/` | Architecture, federation, and IXP operator documentation |
