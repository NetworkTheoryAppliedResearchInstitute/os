# NTARI OS Module Layer

**Version:** 2.0
**Date:** 2026-02-18
**License:** AGPL-3.0

---

## What Is a Module?

A **module** is a composable set of ROS2 node packages that adds
domain-specific coordination logic on top of the NTARI OS kernel.
Modules live in Tier 3 of the four-tier stack.

A module is **not** a fork of the kernel, not a new distribution, and
not an infrastructure service. It is domain logic — agricultural
network coordination, food distribution tracking, mesh session
management, economic exchange records — packaged as lifecycle nodes
that speak DDS.

Modules depend on the kernel. The kernel does not depend on any module.
This is the non-negotiable boundary.

---

## Module Catalog

### Current Modules

| Module | Domain | Status |
|---|---|---|
| `agrinet` | Agricultural network coordination | Planned |
| `fruitful` | Food distribution coordination | Planned |

### Infrastructure Implementations (Tier 2, not Tier 3)

The following are sometimes called "modules" colloquially but belong in
Tier 2 (infrastructure implementations):

| Name | Correct tier | Role |
|---|---|---|
| SoHoLINK | Tier 2 (infrastructure) | RADIUS/AAA for 802.1X and Captive Portal |
| SoHoMesh | Tier 3 (module) | Mesh topology coordination logic |

**SoHoLINK** provides RADIUS authentication — a concrete infrastructure
service. It belongs in Tier 2. Any mesh session logic, routing
coordination, or topology management that builds on top of SoHoLINK
belongs in a Tier 3 module (e.g., SoHoMesh).

---

## Module Contract

A module is valid if and only if it satisfies all of the following:

### 1. Namespace

All module topics, services, and parameters must be namespaced under
`/ntari/<module-name>/`. A module must not publish to or subscribe
from `/ntari/kernel/*`.

```
/ntari/agrinet/harvest_schedule    ✅ Valid module topic
/ntari/agrinet/node_status         ✅ Valid module topic
/ntari/kernel/federation/peers     ✗ Kernel topic — read-only for modules
/ntari/kernel/policy/active        ✗ Kernel topic — read-only for modules
```

### 2. Lifecycle Node

Every module node must implement the ROS2 lifecycle node interface:

| State | Behavior |
|---|---|
| Unconfigured | Node loaded, waiting for parameters |
| Inactive | Node configured, not processing |
| Active | Node processing, publishing, subscribing |
| Finalized | Node cleaned up, ready for unload |

The kernel can stop any module node without affecting other nodes or
the kernel itself.

### 3. Health and Status Topics

Every module node must publish:

```
/ntari/<module>/<node>/health     (std_msgs/Bool, 1 Hz)
/ntari/<module>/<node>/status     (std_msgs/String, 0.1 Hz)
```

These are consumed by the globe interface and the kernel health monitor.

### 4. Policy Declaration

Governance rules required by the module must be declared in a policy
file (`<module>/policy/<rule>.rego` or `<module>/policy/<rule>.ntari`).
The kernel evaluates them. The module must not implement enforcement
logic procedurally.

```
# Valid: declarative policy in a .rego file
package ntari.agrinet.harvest

default allow_update = false

allow_update {
    input.node_role == "coordinator"
    input.domain == data.agrinet.local_domain
}
```

```python
# Invalid: enforcement logic in module Python code
def validate_update(node_role, domain):
    if node_role != "coordinator":
        raise PermissionError("not allowed")
```

### 5. No Direct Federation

Modules must not open WireGuard tunnels, configure DDS domain bridges,
or manage federation agreements. They consume federation via the kernel
API:

```
/ntari/kernel/federation/peers        # Read: list of federated peers
/ntari/kernel/federation/status       # Read: tunnel health
/ntari/kernel/federation/announce     # Write: publish module presence
```

### 6. APK Packaging

Modules must be distributed as APK packages in the NTARI APK
repository. Each module package must declare its kernel version
dependency:

```
# APKBUILD
depends="ntari-kernel>=2.0 ntari-ros2>=jazzy"
```

### 7. License

All module code must be AGPL-3.0 or a compatible license. Closed-source
modules are not accepted into the official module catalog.

---

## Module Anatomy

A minimal module directory:

```
modules/agrinet/
├── APKBUILD                  # APK build definition
├── README.md                 # Module documentation
├── agrinet_coordinator/      # Main coordination node
│   ├── package.xml
│   ├── setup.py
│   └── agrinet_coordinator/
│       ├── __init__.py
│       └── coordinator_node.py
├── agrinet_monitor/          # Health monitoring node (optional)
│   └── ...
└── policy/
    ├── update_policy.rego    # Governance rules (kernel evaluates)
    └── federation.rego       # Federation rules (kernel evaluates)
```

### Example: Minimal Node Implementation

```python
import rclpy
from rclpy.lifecycle import LifecycleNode
from std_msgs.msg import Bool, String

class AgrinetCoordinatorNode(LifecycleNode):

    def __init__(self):
        super().__init__('agrinet_coordinator')

    def on_activate(self, state):
        self.health_pub = self.create_publisher(
            Bool, '/ntari/agrinet/coordinator/health', 10)
        self.status_pub = self.create_publisher(
            String, '/ntari/agrinet/coordinator/status', 10)
        self.health_timer = self.create_timer(1.0, self.publish_health)
        self.status_timer = self.create_timer(10.0, self.publish_status)
        return super().on_activate(state)

    def publish_health(self):
        msg = Bool()
        msg.data = True  # Replace with actual health check
        self.health_pub.publish(msg)

    def publish_status(self):
        msg = String()
        msg.data = 'active'
        self.status_pub.publish(msg)
```

---

## Mesh and Token Boundary

Two areas require explicit boundary discipline: **mesh logic** and
**token/economic logic**.

### Mesh Logic

The kernel provides WireGuard transport and DDS domain bridging.
It does not implement mesh topology algorithms, routing protocols,
or session management.

Mesh coordination logic — topology discovery, route selection, session
handoff — belongs in a Tier 3 module. It consumes the kernel federation
API and publishes mesh state to module-namespaced topics.

```
Kernel provides:       /ntari/kernel/federation/*  (transport + bridge)
Module owns:           /ntari/sohomesh/*            (topology + sessions)
```

If mesh logic appears in `/ntari/kernel/*` topics or in kernel source
files, it is a boundary leak.

### Token and Economic Logic

Ledger state, wallet balances, token transfers, and economic coordination
are application-layer concerns. They belong in a Tier 3 module.

The kernel does not hold ledger state. The kernel does not validate
transactions. The kernel does not know what a "token" is.

A token module consumes the kernel's identity and federation services
and publishes economic state to its own namespace:

```
Kernel provides:       /ntari/kernel/identity/*     (who is this node?)
Module owns:           /ntari/token/*               (balances, transfers)
```

If token or ledger logic appears in kernel source or in the federation
layer, it is a boundary leak.

---

## Developing a Module

1. **Choose a namespace** — pick a short, lowercase, hyphen-free name
   (`agrinet`, `fruitful`, `sohomesh`, `tokenledger`)

2. **Define your topics** — all under `/ntari/<name>/`

3. **Write policy files** — governance rules in Rego or NTARI DSL;
   no enforcement logic in Python/C++

4. **Implement lifecycle nodes** — one node per logical concern;
   publish health and status at required rates

5. **Package as APK** — declare kernel dependency in APKBUILD

6. **Test in isolation** — use `ros2 launch` to start your module
   against a running kernel; verify no kernel topic writes

7. **Submit to module catalog** — open a pull request against the
   `modules/` directory; include README and policy files

---

## Module Review Criteria

Pull requests adding or modifying modules are reviewed against:

- [ ] All topics under `/ntari/<module>/` namespace
- [ ] No writes to `/ntari/kernel/*`
- [ ] Lifecycle node interface implemented
- [ ] Health and status topics published at required rates
- [ ] Governance rules in policy files, not procedural code
- [ ] No direct WireGuard or DDS bridge management
- [ ] APK declares kernel version dependency
- [ ] AGPL-3.0 license
- [ ] README describes module purpose, topics, and policy files

---

For architecture context, see [ARCHITECTURE.md](ARCHITECTURE.md).
For distribution packaging, see [DISTRIBUTIONS.md](DISTRIBUTIONS.md).
