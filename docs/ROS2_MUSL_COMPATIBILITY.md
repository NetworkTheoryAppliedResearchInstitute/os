# ROS2 on Alpine Linux (musl libc): Compatibility State Report

**Scope:** Technical assessment for NTARI OS — a network-first OS built on Alpine Linux + ROS2 with Cyclone DDS middleware.
**Date:** February 2026
**License:** AGPL-3.0

---

## Executive Summary

Running ROS2 on Alpine Linux (which uses musl libc instead of glibc) is viable as of early 2026, but remains unofficial, unsupported by the Open Source Robotics Foundation (OSRF), and dependent on community infrastructure maintained primarily by a single Japanese robotics company (SEQSENSE). The core packages — `ros_core`, `ros_base`, and the `desktop` metapackage — build and run on Alpine 3.20 and 3.23. The full ROS2 ecosystem is not uniformly covered.

**For NTARI OS, the recommended stack is:**
- Base: Alpine 3.23
- ROS2 distribution: Jazzy (LTS) or Humble (LTS)
- DDS middleware: **Cyclone DDS** (`rmw_cyclonedds_cpp`) — not Fast-DDS
- Build infrastructure: SEQSENSE experimental aports or alpine-ros Docker images

---

## Why This Matters for NTARI OS

NTARI OS proposes inverting the conventional OS design priority: rather than treating networking as a later addition to a local-computation base, networking — expressed as a live ROS2 communication graph — is the foundational abstraction. This requires ROS2 to run on Alpine Linux, which was chosen for its minimal footprint, security-oriented packaging, OpenRC init system, and suitability for edge deployment on modest hardware.

The musl libc compatibility question is therefore not peripheral. It is the primary technical risk for the project. This document characterizes that risk concretely and identifies what remains to be resolved.

---

## 1. What musl libc Is and Why It Differs from glibc

Alpine Linux uses [musl libc](https://musl.libc.org/) rather than glibc (the GNU C Library used by Ubuntu, Fedora, Debian, and most mainstream Linux distributions). musl is a from-scratch POSIX implementation prioritizing correctness, simplicity, and security over compatibility with GNU extensions.

The practical consequence: code written assuming glibc — which includes most of ROS2's dependency chain — may use glibc-specific functions, macros, or behaviors that musl does not provide or provides differently. This creates build failures, runtime errors, and behavioral differences that must be identified and patched before ROS2 runs on Alpine.

---

## 2. Specific Compatibility Issues

### 2.1 Missing GNU Extensions

**`__xstat` (internal glibc symbol):** The `rcutils` test mocking infrastructure used `__xstat`, a private versioned-stat wrapper glibc exposes but musl never has. Filed as [ros2/rcutils#329](https://github.com/ros2/rcutils/issues/329), fixed in [PR #330](https://github.com/ros2/rcutils/pull/330). Older pinned releases require this patch applied manually.

**`_NP`-suffixed pthread extensions:** Functions like `pthread_attr_setaffinity_np()` and constants `PTHREAD_MUTEX_FAST_NP` / `PTHREAD_MUTEX_RECURSIVE_NP` are glibc extensions. Fast-DDS and Boost.Thread use these without `#ifdef __GLIBC__` guards, causing build failures on musl.

**`execinfo.h` and backtrace functions:** musl does not provide `execinfo.h`. Cyclone DDS's `sysdeps.c` conditionally included it. Fixed upstream in [eclipse-cyclonedds/cyclonedds#383](https://github.com/eclipse-cyclonedds/cyclonedds/issues/383) via PR #384, which added the correct preprocessor guard for non-glibc Linux builds. This fix is in the upstream Cyclone DDS codebase.

**`fts` functions:** The file-tree traversal API (`fts_open`, `fts_read`, etc.) is in glibc but absent from musl. Some ROS2 build tooling hits this indirectly through dependencies.

**`MAXNAMLEN` macro:** glibc aliases `MAXNAMLEN` to `NAME_MAX`; musl does not. Packages using `MAXNAMLEN` directly will fail to compile. Fix: add `#define MAXNAMLEN NAME_MAX` in affected files.

### 2.2 ASIO `strerror_r` Type Mismatch

ASIO (used by Fast-DDS) assumed the GNU non-standard signature of `strerror_r`, which returns `char*`. The POSIX-standard version (which musl correctly implements) returns `int`. This caused a hard build failure:

```
could not convert 'strerror_r(...)' from 'int' to 'std::string'
```

Fixed in ASIO 1.12.0 ([chriskohlhoff/asio#94](https://github.com/chriskohlhoff/asio/issues/94)). Distributions pinning older ASIO versions re-expose this failure.

### 2.3 Dynamic Linker Behavioral Differences

**`dlclose()` is a no-op in musl.** musl's author made a deliberate design decision that library unloading is not reliably implementable without glibc's internals. This means ROS2's `pluginlib` and `class_loader`, which cycle plugin libraries at runtime, will accumulate loaded libraries in address space rather than freeing them. There is no upstream fix — this is musl's intended behavior. For long-running NTARI OS nodes, this requires managing plugin lifecycle carefully.

**No lazy symbol binding.** musl resolves all symbols at library load time rather than on first call (lazy binding). A glibc-compiled DDS library referencing internal glibc symbols (`__cmsg_nxthdr`, `__sysconf`, `backtrace`) will fail immediately at `dlopen()`. The practical implication: you cannot use pre-compiled glibc binaries on Alpine — everything must be rebuilt natively on Alpine from source. This is confirmed by [eclipse-cyclonedds/cyclonedds#1892](https://github.com/eclipse-cyclonedds/cyclonedds/issues/1892), where Alpine users saw:

```
Error relocating /usr/bin/libddsc.so.0: __cmsg_nxthdr: symbol not found
Error relocating /usr/bin/libddsc.so.0: __sysconf: symbol not found
Error relocating /usr/bin/libddsc.so.0: backtrace: symbol not found
```

Rebuilding Cyclone DDS natively inside an Alpine build environment resolves this completely.

### 2.4 Thread Stack Size Defaults

musl's default thread stack size is **128 KB**; glibc's is typically 2–10 MB. DDS middleware threads handling serialization, discovery, and transport can overflow the smaller default on complex message types. The fix — calling `pthread_attr_setstacksize()` before spawning DDS-internal threads — requires patching upstream DDS code that currently trusts the platform default. No upstream fix exists for this in Cyclone DDS or Fast-DDS.

### 2.5 DNS Resolver Behavior

musl queries all configured nameservers **in parallel** rather than sequentially, and did not support TCP-based DNS until version 1.2.4. DDS peer discovery that uses DNS-based peer lookup will see non-deterministic lookup behavior under multi-nameserver configurations. The reliable mitigation is to configure DDS discovery to use multicast rather than DNS-based peer lookup — which is the correct approach for local mesh networks regardless.

### 2.6 Atomic Library Linkage

Building `rcutils` on musl toolchains produced linker errors:

```
undefined reference to `__atomic_store_8`
undefined reference to `__atomic_load_8`
```

The rcutils changelog explicitly notes "Export `-latomic` even if `BUILD_TESTING` is disabled" — indicating prior bugs where atomic library linkage was incorrectly conditional. This has been addressed upstream but requires attention in custom builds.

### 2.7 Python Binary Wheel Incompatibility

ROS2 Python packages on PyPI use the `manylinux` platform tag, targeting glibc. These wheels cannot run on musl. Alpine must compile every Python package with C extensions (e.g., `numpy`, `lxml`) from source. [PEP 656](https://peps.python.org/pep-0656/) introduced the `musllinux` platform tag as the solution, but adoption across the ROS2 Python dependency ecosystem is still incomplete. This significantly increases build time and introduces additional musl compatibility surface.

---

## 3. DDS Middleware: Cyclone DDS vs. Fast-DDS

### 3.1 Why Cyclone DDS Is the Correct Choice

For NTARI OS on Alpine, **Cyclone DDS is the only practical DDS choice**. The reasons are architectural, not merely preferential:

**Written in C, not C++.** Cyclone DDS's core (`libddsc`) is implemented in C. This eliminates the entire class of musl incompatibilities rooted in C++ runtime quirks, Boost, and ASIO. The musl compatibility surface is dramatically smaller.

**musl patches are merged upstream.** The `execinfo.h` issue (Issue #383) was resolved by PR #384, adding correct `#ifndef __GLIBC__` guards. These patches are in the current Cyclone DDS codebase, not in a fork.

**Simpler dependency tree.** Cyclone DDS does not depend on ASIO, Boost, OpenSSL (for the base build), or ACE/TAO. Each of these is a documented source of musl build failures in the Fast-DDS stack.

**Default DDS for recent ROS2 LTS releases.** Cyclone DDS was the default middleware from ROS2 Galactic through Iron. The alpine-ros project, which provides the primary Alpine ROS2 build infrastructure, uses Cyclone DDS throughout.

**License alignment.** Cyclone DDS is licensed under EPL-2.0 and maintained under the Eclipse Foundation with no single corporate owner. This aligns better with NTARI OS's AGPL-3.0 license and cooperative governance model than Fast-DDS, which is maintained by eProsima as a commercial product.

### 3.2 Fast-DDS musl Problems

Fast-DDS on musl requires patching:

- **ASIO `strerror_r`** type mismatch (fixed in ASIO 1.12.0, but version pinning can re-expose)
- **Boost.Thread `_NP` pthread extensions** without proper `#ifdef __GLIBC__` guards
- **Shared-memory transport `MAP_LOCKED` mmap failure** — Fast-DDS's shared-memory transport uses `mmap` with `MAP_LOCKED`, which fails on Alpine. Requires patching Fast-DDS to catch the exception and retry without the flag.

These are not insurmountable, but they add maintenance burden on every Fast-DDS version update. For a community-maintained project, this overhead is unjustified when Cyclone DDS does not require it.

---

## 4. Current State of Alpine ROS2 Infrastructure (Early 2026)

### 4.1 Primary Project: `alpine-ros`

The main community effort is the [alpine-ros/alpine-ros](https://github.com/alpine-ros/alpine-ros) Docker image project. Active images as of early 2026:

| Image | Alpine Version | Status |
|---|---|---|
| `jazzy-3.20` | 3.20 | Active |
| `jazzy-3.23` | 3.23 | Active |
| `humble-3.20` | 3.20 | Active |
| `humble-3.23` | 3.23 | Active |
| `noetic-3.20` | 3.20 | Active |
| `noetic-3.23` | 3.23 | Active |

Images are published to `ghcr.io/alpine-ros/alpine-ros`. The project has 5 contributors.

### 4.2 Build Infrastructure: `seqsense/aports-ros-experimental`

The APK build scripts are maintained at [seqsense/aports-ros-experimental](https://github.com/seqsense/aports-ros-experimental) by [SEQSENSE](https://www.seqsense.org/alpine-ros), a Japanese industrial robotics company. This repository contains Alpine `APKBUILD` scripts for ROS packages across Alpine 3.20 and 3.23, with 1,257+ commits from 8 contributors.

SEQSENSE appears to use Alpine-based ROS2 in production containerized robotic deployments, which explains their sustained investment. Outside SEQSENSE, no other known organization is actively maintaining Alpine ROS2 compatibility.

### 4.3 What "Unofficial" Means in Practice

- There is no `ros-humble` or `ros-jazzy` package in the official Alpine `aports` tree.
- OSRF's REP-2000 (the ROS2 platform support document) lists only Ubuntu distributions as Tier 1 and Tier 2. Alpine has no tier designation.
- The seqsense experimental aports are a separate, user-maintained repository.
- Not all ROS2 packages are available. The tracked meta-packages are: `ament_package`, `desktop`, `geographic_msgs`, `navigation2`, `perception`, `ros_base`, `ros_core`, `ros_workspace`, `vision_msgs`.
- For production bare-metal Alpine deployment, you add the seqsense APK repository and install from it — this is not an officially signed repository.

---

## 5. Remaining Open Problems

Problems where no upstream fix exists or where the fix requires ongoing maintenance:

| Problem | Severity | Status |
|---|---|---|
| `dlclose()` no-op — plugin libraries accumulate in memory | Medium | musl design decision; no fix upstream |
| Thread stack size defaults too small for DDS threads | High | No upstream fix; requires per-patch on DDS internals |
| DNS parallel query non-determinism | Low (mitigated by multicast discovery config) | musl design decision |
| Python `musllinux` wheel ecosystem incomplete | Medium | PEP 656 exists; adoption ongoing |
| Sanitizer incompatibility (ASan, TSan unusable on musl) | Medium for development | musl limitation; UBSan trap-only mode works |
| Incomplete ROS2 package coverage beyond core/base/desktop | High for full ecosystem | Requires sustained community packaging work |
| `ucontext_t` functions unimplemented | Low (not used by mainstream DDS) | musl design decision |

---

## 6. Implications for NTARI OS Development

### Near-term technical priority

The musl/ROS2 compatibility work is **the highest near-term technical risk** for NTARI OS. The good news: it is a bounded, tractable problem rather than an open-ended one. Cyclone DDS's upstream musl patches are merged. The core SEQSENSE infrastructure exists. The gap is formalization, governance, and extension of that infrastructure under NTARI's ownership rather than dependence on SEQSENSE's continued interest.

### Recommended approach

1. **Base NTARI OS builds on Alpine 3.23** with ROS2 Jazzy (current LTS as of 2026).
2. **Fork or formally adopt the seqsense aports-ros-experimental** as an NTARI-maintained repository, credited to SEQSENSE contributors. This gives NTARI control over the build infrastructure rather than depending on a single corporate maintainer.
3. **Use Cyclone DDS exclusively.** Document this as a project-level decision in all technical roadmap materials.
4. **Address the thread stack size issue early.** This is the most likely source of hard-to-reproduce production failures on modest edge hardware. The fix is a targeted patch to Cyclone DDS's internal thread spawning — a bounded, reviewable change.
5. **Plan the Python ecosystem separately.** ROS2 Python tooling on Alpine requires a sustained effort to compile dependencies from source or to contribute `musllinux` wheels upstream. This is parallel work, not blocking.

### What is not a problem

The concerns sometimes raised about musl's strict POSIX compliance breaking ROS2 broadly are overstated for the specific NTARI use case. NTARI OS does not need the full ROS2 ecosystem — it needs the communication graph infrastructure: `ros_core`, Cyclone DDS, lifecycle node management, and graph introspection tooling. These are exactly the packages that the alpine-ros project covers and tests. The compatibility problems are concentrated in packages (Fast-DDS, Boost, sensor drivers, full navigation stacks) that NTARI OS does not need in its base deployment.

---

## 7. Community Projects and Sources

| Project | URL | Role |
|---|---|---|
| `alpine-ros/alpine-ros` | https://github.com/alpine-ros/alpine-ros | Docker images for ROS/ROS2 on Alpine |
| `seqsense/aports-ros-experimental` | https://github.com/seqsense/aports-ros-experimental | APK build scripts; primary build infrastructure |
| `seqsense/aports-ros-updater` | https://github.com/seqsense/aports-ros-updater | Automated rosdistro version tracker |
| SEQSENSE OSS Portal | https://www.seqsense.org/alpine-ros | Documentation and package portal |
| `eclipse-cyclonedds/cyclonedds` | https://github.com/eclipse-cyclonedds/cyclonedds | Cyclone DDS upstream; musl patches merged |
| `ros2/rcutils` | https://github.com/ros2/rcutils | `__xstat` musl fix merged (PR #330) |
| musl libc Functional Differences | https://wiki.musl-libc.org/functional-differences-from-glibc.html | Reference for musl vs glibc gaps |
| PEP 656 | https://peps.python.org/pep-0656/ | Python musllinux platform tag specification |
| REP-2000 | https://www.ros.org/reps/rep-2000.html | ROS2 platform support tiers |

---

*This document is part of the NTARI OS technical research series. It should be reviewed and updated when Alpine Linux releases a new stable version or when ROS2 LTS support windows change.*
