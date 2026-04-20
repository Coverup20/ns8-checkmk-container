# ns8-checkmk-container

Containerized CheckMK agent for NethServer 8 (NS8) with FRPC optional tunneling.

Runs the official `check-mk-agent` RPM inside a Rocky Linux 9 minimal container, exposes port 6556,
and optionally includes FRPC client for secure remote monitoring tunnels.

## Features

- **CheckMK agent** auto-detected from monitoring server (latest version)
- **FRPC optional** (v0.68.1) — activated via env vars or config mount
- **Two build variants**:
  - **Base** (`Containerfile`) — System checks + SOS session monitoring only
  - **Runagent** (`Containerfile.runagent`) — Full NS8 module inspection with runagent support
- **Lightweight** — 234 MB (base) / 236 MB (runagent)
- **No host dependencies** — No native RPM or systemd unit needed on NS8 host

## Build Variants

### Base image (rootful/rootless compatible)

Minimal deployment with system checks and SOS session monitoring:

```bash
podman build -f Containerfile -t checkmk-agent:latest .
```

**Includes:**
- CheckMK agent 2.4.0p26+ (auto-detected)
- FRPC client v0.68.1 (optional activation)
- 1 local check: `check-sos` (SOS session monitoring)
- Size: **234 MB**

### Runagent image (full NS8 module inspection)

Complete NS8 deployment with rootless Podman container inspection:

```bash
podman build -f Containerfile.runagent -t checkmk-agent:runagent .
```

**Includes:**
- All base features
- runagent dependencies (procps-ng, shadow-utils, libseccomp)
- PYTHONPATH wrapper for agent module imports
- 12 local checks: `check-sos` + 11 NS8 module checks
- Size: **236 MB**

**NS8 module checks:**
- `check_ns8_containers`, `check_ns8_services`, `check_ns8_container_status`
- `check_ns8_container_inventory`, `check_ns8_container_resources`
- `check_ns8_smoke_test`, `check_podman_events`
- `check_ns8_tomcat8`, `check_ns8_webtop`
- `check_nv8_status_trunk`, `check_nv8_status_extensions`

## Build Arguments

Override defaults at build time:

```bash
podman build \
  --build-arg CMK_AGENT_URL=https://<your-server>/<site>/check_mk/agents \
  --build-arg FRP_VERSION=0.68.1 \
  -f Containerfile -t checkmk-agent:latest .
```

## Pre-built images (GitHub Container Registry)

Pull directly from `ghcr.io/coverup20/ns8-checkmk-container`:

| Tag | Description | Size |
|---|---|---|
| `:latest` | Base image — system checks + SOS only | 234 MB |
| `:runagent` | Full NS8 build — runagent + 12 module checks | 236 MB |

Pull directly on target host:

```bash
# Base variant
podman pull ghcr.io/coverup20/ns8-checkmk-container:latest

# Runagent variant (full NS8)
podman pull ghcr.io/coverup20/ns8-checkmk-container:runagent
```

## Deploy

### Base deployment (rootful or rootless compatible)

Minimal container with system checks + SOS monitoring:

```bash
podman run -d \
  --name checkmk-agent \
  --restart=always \
  -p 6556:6556 \
  ghcr.io/coverup20/ns8-checkmk-container:latest
```

**Note:** Base variant works in both rootful and rootless mode. No `--privileged` required for basic monitoring.

### Full NS8 deployment (runagent + module checks)

Complete deployment with NS8 module inspection (requires host mounts):

```bash
podman run -d \
  --name checkmk-agent \
  --restart=always \
  --privileged \
  --pid=host \
  --cgroupns=host \
  -p 6556:6556 \
  -v /usr/local/agent:/usr/local/agent:ro \
  -v /usr/local/bin/runagent:/usr/local/bin/runagent:ro \
  -v /usr/bin/python3.11:/usr/bin/python3.11:ro \
  -v /usr/bin/podman:/usr/bin/podman:ro \
  -v /usr/lib64/libpython3.11.so.1.0:/usr/lib64/libpython3.11.so.1.0:ro \
  -v /usr/lib64/python3.11:/usr/lib64/python3.11:ro \
  -v /etc/passwd:/etc/passwd:ro \
  -v /etc/group:/etc/group:ro \
  -v /etc/shadow:/etc/shadow:ro \
  -v /etc/nethserver:/etc/nethserver:ro \
  -v /run/user:/run/user \
  -v /home:/home:ro \
  --security-opt label=disable \
  ghcr.io/coverup20/ns8-checkmk-container:runagent
```

## FRPC Optional Tunneling

FRPC client (v0.68.1) is pre-installed but **NOT activated** by default.

### Activation method 1: Environment variables (recommended)

```bash
podman run -d \
  --name checkmk-agent \
  -p 6556:6556 \
  -e FRPC_SERVER_ADDR=monitor.nethlab.it \
  -e FRPC_TOKEN=your-auth-token \
  -e FRPC_PROXY_NAME=myhost \
  -e FRPC_REMOTE_PORT=6003 \
  -e FRPC_SERVER_PORT=7000 \
  -e FRPC_TLS=true \
  ghcr.io/coverup20/ns8-checkmk-container:latest
```

### Activation method 2: Config file mount (advanced)

```bash
podman run -d \
  --name checkmk-agent \
  -p 6556:6556 \
  -v /etc/frp/frpc.toml:/etc/frp/frpc.toml:ro \
  ghcr.io/coverup20/ns8-checkmk-container:latest
```

**Without FRPC configuration:** Container runs CheckMK agent only (no tunnel).

## Verification

Test agent response:

```bash
# Direct connection
echo | nc localhost 6556 | head -20

# From CheckMK server
cmk --check <hostname>
```

Check FRPC status (if configured):

```bash
podman logs checkmk-agent | grep frpc
```

## Version

Current release: **v0.0.1**

See [releases](https://github.com/Coverup20/ns8-checkmk-container/releases) for changelog.
```

### Mount reference

| Flag / Mount | Purpose |
|---|---|
| `--cgroupns=host` | Share host cgroup namespace — required for `podman exec` into rootless module containers |
| `/usr/local/agent` | NS8 agent Python environment (runagent runtime) |
| `/usr/local/bin/runagent` | NS8 runagent binary |
| `/usr/bin/python3.11` | Python 3.11 binary (required by runagent shebang) |
| `/usr/bin/podman` | Podman binary (for module container inspection) |
| `/usr/lib64/libpython3.11.so.1.0` | Python 3.11 shared library |
| `/usr/lib64/python3.11` | Python 3.11 standard library |
| `/etc/passwd`, `/etc/group`, `/etc/shadow` | Host user/group database (module users) |
| `/etc/nethserver` | NS8 agent configuration (agent.env) |
| `/run/user` | Module user runtime dirs (XDG_RUNTIME_DIR, Podman storage) |
| `/home` | Module user home dirs (agent state, environment files) |

## How runagent works from the container

NS8 module containers (webtop, mail, nethvoice, etc.) run as rootless Podman under
dedicated Linux users (e.g. `webtop3` with UID 1015). The `runagent` tool switches
context to those users via `runuser -l` to run commands in their environment.

The container's `/usr/bin/env` is wrapped to inject `PYTHONPATH=/usr/local/agent/pypkg`
into the `runuser` sub-process environment (since `runuser -l` resets all env vars).
This allows the second `runagent` invocation (running as the module user) to find the
NS8 `agent` Python module. `PYTHONPATH` is also set via `ENV` in the image for the
initial invocation.

**`--cgroupns=host` is required** for `podman exec` into rootless module containers.
Without it, the container uses a private cgroup namespace and cannot see the cgroup
paths of `user.slice/user-<uid>.slice/...` where module containers live. This causes
`podman exec` to fail with `crun: write to /sys/fs/cgroup/.../cgroup.procs: No such file or directory`.

Example - list webtop3 containers from inside the running container:

```bash
podman exec checkmk-agent runagent -m webtop3 podman ps
```

## Local checks

Custom check scripts in `checks/` are copied into `/usr/lib/check_mk_agent/local/`
at build time. Currently deployed:

| Script | Service name | Description |
|---|---|---|
| `check-sos` | `SOS.Session` | Checks whether an active SOS support session is running |

Additional NS8-aware check scripts are in `checks-rootless/` and use `runagent`
to inspect module containers. They are deployed by `Dockerfile.runagent` (Full NS8 build).
To include them in the minimal build, copy selected scripts into `checks/`.

## Stopping and removing

```bash
podman stop checkmk-agent
podman rm checkmk-agent
```

## Verify agent output

```bash
podman exec checkmk-agent check_mk_agent | head -20
```
