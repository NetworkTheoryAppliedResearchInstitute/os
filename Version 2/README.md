# NTARI OS

**Network Theory Applied Research Institute Operating System**

A federation-first coordination kernel for cooperative infrastructure.

**Version:** 2.0 | **License:** AGPL-3.0 | **Status:** Active Development

---

## What Is NTARI OS?

NTARI OS is a **federated coordination kernel** — not a deployment, not an
application, and not a network appliance. It is the runtime that makes
independent cooperative nodes discoverable, interconnectable, and
governable without requiring a central authority.

The kernel provides three things and only three things:

1. **A computation graph** — every participant, service, and data flow is a
   node in a DDS publish-subscribe graph. The graph is the network.
2. **A federation runtime** — WireGuard tunnels + DDS domain bridging
   connect independent cooperative deployments into a coherent whole.
3. **A policy engine** — declarative governance (Rego/DSL) enforces
   coordination rules without encoding them in the kernel itself.

Everything else — infrastructure implementations, domain logic, and
use-case packaging — belongs in the layers above.

---

## The Four-Tier Stack

```
┌──────────────────────────────────────────────────────────────┐
│  TIER 4 — DISTRIBUTIONS                                      │
│  Use-case packaging (Municipal, Co-op, School, Rural ISP)    │
│  Selects modules. Configures governance. Ships as an ISO.    │
├──────────────────────────────────────────────────────────────┤
│  TIER 3 — MODULES                                            │
│  Domain logic (Agrinet, Fruitful, SoHoLINK, Mesh, Token...)  │
│  Each module is a composable set of ROS2 node packages.      │
│  Modules depend on the kernel. The kernel does not depend    │
│  on any module.                                              │
├──────────────────────────────────────────────────────────────┤
│  TIER 2 — INFRASTRUCTURE IMPLEMENTATIONS                     │
│  Concrete service nodes (DNS, DHCP, VPN, Identity, Chat...)  │
│  SoHoLINK is one implementation in this tier.               │
│  Swap implementations without changing kernel or modules.    │
├──────────────────────────────────────────────────────────────┤
│  TIER 1 — NTARI OS KERNEL                                    │
│  Federated coordination runtime.                             │
│  Alpine Linux · ROS2 Jazzy · Cyclone DDS · WireGuard        │
│  Governance policy engine (Rego/DSL)                         │
│  Federation protocol                                         │
└──────────────────────────────────────────────────────────────┘
```

**The kernel is the stable foundation. Distributions are the visible face.**
Modules and infrastructure implementations are how you extend it. Nothing
above Tier 1 should be able to destabilize what Tier 1 guarantees.

---

## What the Kernel Guarantees

Any node running NTARI OS kernel can:

- **Join a cooperative DDS domain** — peer discovery via Cyclone DDS
  multicast, no central registry required
- **Federate with another cooperative** — WireGuard tunnel + DDS domain
  bridge, governed by a signed federation agreement
- **Publish and subscribe to any topic** — including health, status, and
  governance topics from any installed module
- **Enforce policy declaratively** — governance rules expressed in Rego or
  NTARI DSL, evaluated by the kernel policy engine, not by module code
- **Operate offline** — full local functionality without an internet uplink

These guarantees are permanent and version-stable. Modules can be added,
removed, or swapped without breaking them.

---

## What the Kernel Does Not Contain

The following belong in the module layer (Tier 3), not the kernel:

- Mesh routing logic and topology management
- Token economics, wallet systems, or ledger state
- Domain-specific data schemas (agricultural, food distribution, etc.)
- Captive portal or AAA/RADIUS session management
- Application-layer governance (voting on specific module policies)

If logic of this kind appears in Tier 1 or Tier 2, it is a **boundary
leak** and should be refactored upward.

---

## Quick Start

### Prerequisites

- Docker Desktop
- Git
- Make
- VirtualBox or QEMU (for testing)
- 8 GB RAM, 50 GB free disk

### Build the Kernel ISO

```bash
git clone https://github.com/NetworkTheoryAppliedResearchInstitute/ntari-os.git
cd ntari-os
make iso
# Output: build-output/ntari-os-2.0.0-x86_64.iso
```

### Run in a VM

```bash
make vm
# Or: ./vm/quickstart.sh
```

Default credentials (change immediately after first boot):
- Username: `root`
- Password: `ntaripass`

Globe interface: `http://ntari.local` (available after boot)

---

## Project Structure

```
ntari-os/
├── kernel/                   # Tier 1: Core runtime
│   ├── base/                 # Alpine Linux 3.23 layer
│   ├── middleware/           # ROS2 Jazzy + Cyclone DDS
│   ├── federation/           # WireGuard + DDS bridge
│   └── policy/               # Rego/DSL governance engine
├── infra/                    # Tier 2: Infrastructure implementations
│   ├── soholink/             # RADIUS/AAA (SoHoLINK)
│   ├── dns/                  # dnsmasq node
│   ├── dhcp/                 # Kea DHCP node
│   ├── identity/             # FreeIPA node
│   ├── vpn/                  # WireGuard node
│   └── ...                   # Additional service nodes
├── modules/                  # Tier 3: Domain modules
│   ├── agrinet/              # Agricultural network coordination
│   ├── fruitful/             # Food distribution coordination
│   └── ...                   # Additional domain modules
├── distributions/            # Tier 4: Use-case ISOs
│   ├── municipal/
│   ├── cooperative/
│   ├── school/
│   └── rural-isp/
├── build/                    # Build scripts and Dockerfiles
├── docs/                     # Documentation
│   ├── ARCHITECTURE.md
│   ├── MODULES.md
│   ├── DISTRIBUTIONS.md
│   ├── FEDERATION.md
│   └── globe-interface/
├── tests/
├── CHANGELOG.md
└── README.md
```

---

## Documentation

| Document | Description |
|---|---|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Full four-tier stack, kernel internals, design decisions |
| [docs/MODULES.md](docs/MODULES.md) | Module layer contract — how to build and register a module |
| [docs/DISTRIBUTIONS.md](docs/DISTRIBUTIONS.md) | Distribution packaging — how to assemble a use-case ISO |
| [docs/FEDERATION.md](docs/FEDERATION.md) | Federation protocol — WireGuard + DDS bridge specification |
| [CHANGELOG.md](CHANGELOG.md) | Version history |

---

## Development Status

**Current Version:** 2.0.0-dev
**Phase:** Kernel foundation — boundary clarification and stack
re-framing from v1.x

| Area | Status |
|---|---|
| Alpine 3.23 base + OpenRC | ✅ Scripts complete |
| ROS2 Jazzy + Cyclone DDS integration | 🔵 In progress |
| Federation protocol (WireGuard + DDS bridge) | 📋 Specified |
| Policy engine (Rego/DSL) | 📋 Specified |
| Globe interface | 📋 Prototype delivered |
| Module layer API | 📋 Designed |
| SoHoLINK (infra tier) | ✅ Legacy compat retained |
| Distribution packaging | 📋 Planned |

---

## Contributing

NTARI OS is built for and by cooperative communities.

### Boundary Rule

Before contributing code, verify which tier it belongs in:

- **Kernel (Tier 1):** federation, policy engine, DDS domain management
- **Infrastructure (Tier 2):** service node implementations
- **Module (Tier 3):** domain logic, application-layer coordination
- **Distribution (Tier 4):** use-case configuration and packaging

Pull requests that place domain logic in the kernel tier will be
redirected to the module layer.

### How to Contribute

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/your-feature`)
3. Identify the correct tier for your contribution
4. Submit a pull request

All contributions must be licensed AGPL-3.0 or compatible.

---

## License

**AGPL-3.0** — See LICENSE file.

The AGPL-3.0 license ensures that modifications to NTARI OS remain
cooperative: any deployment as a network service must share its
modifications. This is structural, not incidental.

---

## Support

- **GitHub Issues:** https://github.com/NetworkTheoryAppliedResearchInstitute/ntari-os/issues
- **Email:** contact@ntari.org

---

**Version:** 2.0.0-dev
**Last Updated:** 2026-02-18
