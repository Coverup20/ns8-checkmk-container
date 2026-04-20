# Container Deploy Guide — ns8-checkmk-container

Technical deployment documentation for `ns8-checkmk-container` base and runagent images.

**Repository:** `ghcr.io/coverup20/ns8-checkmk-container`  
**Variants:** `:latest` (base), `:runagent` (full NS8)  
**Current version:** v0.0.1

---

## Build Variants Overview

| Variant | Tag | Size | Use Case | Privileged | Host Mounts |
|---------|-----|------|----------|------------|-------------|
| **Base** | `:latest` | 234 MB | System checks + SOS monitoring | Optional | No |
| **Runagent** | `:runagent` | 236 MB | Full NS8 module inspection | Required | Required |

---

## Base Image (`:latest`)

### Purpose

Minimal CheckMK agent container with system-level checks and SOS session monitoring.  
Works in **rootful** or **rootless** Podman without special privileges.

### Included

- CheckMK agent 2.4.0p26+ (auto-detected from server)
- FRPC client v0.68.1 (optional activation via env/config)
- **1 local check:** `check-sos` (SOS session monitoring via `/tmp/sos-*` detection)

### Build

```bash
# From source (Containerfile)
podman build -f Containerfile -t checkmk-agent:latest .

# With custom CheckMK server
podman build \
  --build-arg CMK_AGENT_URL=https://monitor.example.com/monitoring/check_mk/agents \
  -f Containerfile \
  -t checkmk-agent:latest .

# Pull pre-built from GHCR
podman pull ghcr.io/coverup20/ns8-checkmk-container:latest
```

### Deploy

#### Simple deployment (no FRPC)

```bash
podman run -d \
  --name checkmk-agent \
  --restart=unless-stopped \
  -p 6556:6556 \
  ghcr.io/coverup20/ns8-checkmk-container:latest
```

#### With FRPC tunnel (environment variables)

```bash
podman run -d \
  --name checkmk-agent \
  --restart=unless-stopped \
  -p 6556:6556 \
  -e FRPC_SERVER_ADDR=monitor.nethlab.it \
  -e FRPC_SERVER_PORT=7000 \
  -e FRPC_TOKEN=conduit-reenact-talon-macarena-demotion-vaguely \
  -e FRPC_PROXY_NAME=myhost \
  -e FRPC_REMOTE_PORT=6020 \
  ghcr.io/coverup20/ns8-checkmk-container:latest
```

**FRPC env variables:**

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `FRPC_SERVER_ADDR` | FRPC server hostname/IP | Yes | - |
| `FRPC_SERVER_PORT` | FRPC server port | No | 7000 |
| `FRPC_TOKEN` | Authentication token | Yes | - |
| `FRPC_PROXY_NAME` | Proxy identifier (unique per host) | Yes | - |
| `FRPC_REMOTE_PORT` | Remote port exposed on server | Yes | - |
| `FRPC_TLS` | Enable TLS (true/false) | No | false |

#### With FRPC tunnel (config file)

```bash
# Create frpc.toml on host
cat > /etc/frp/frpc.toml << 'EOF'
serverAddr = "monitor.nethlab.it"
serverPort = 7000
auth.method = "token"
auth.token = "conduit-reenact-talon-macarena-demotion-vaguely"

[[proxies]]
name = "myhost"
type = "tcp"
localIP = "127.0.0.1"
localPort = 6556
remotePort = 6020
EOF

# Deploy container with config mount
podman run -d \
  --name checkmk-agent \
  --restart=unless-stopped \
  -p 6556:6556 \
  -v /etc/frp/frpc.toml:/etc/frp/frpc.toml:ro \
  ghcr.io/coverup20/ns8-checkmk-container:latest
```

### Verification

```bash
# Test CheckMK agent response
echo | nc localhost 6556 | head -20

# Check FRPC tunnel status (if configured)
podman logs checkmk-agent | grep frpc
# Expected: [d987ac446a245ebd] [myhost] start proxy success
```

---

## Runagent Image (`:runagent`)

### Purpose

Full NethServer 8 deployment with rootless Podman container inspection.  
Enables monitoring of NS8 modules (mail, samba, webtop, tomcat, etc.) via `runagent`.

### Included

All base features plus:

- **runagent dependencies:** `procps-ng`, `shadow-utils`, `libseccomp`
- **PYTHONPATH injection:** `/usr/bin/env` wrapper for `runagent` module imports
- **12 local checks:**
  - `check-sos` (SOS session monitoring)
  - `check_ns8_containers` (module container list)
  - `check_ns8_services` (systemd user services per module)
  - `check_ns8_container_status` (container health)
  - `check_ns8_container_inventory` (container details)
  - `check_ns8_smoke_test` (NS8 core health)
  - `check_podman_events` (Podman event stream monitoring)
  - `check_ns8_tomcat8` (Tomcat8 status via runagent)
  - `check_ns8_webtop` (WebTop status via runagent)
  - `check_nv8_status_trunk` (NethVoice trunk status)
  - `check_nv8_status_extensions` (NethVoice extension status)

**Note:** `check_ns8_container_resources` was removed (slow, caused 50s timeout).

### Build

```bash
# From source (Containerfile.runagent)
podman build -f Containerfile.runagent -t checkmk-agent:runagent .

# With custom CheckMK server
podman build \
  --build-arg CMK_AGENT_URL=https://monitor.example.com/monitoring/check_mk/agents \
  -f Containerfile.runagent \
  -t checkmk-agent:runagent .

# Pull pre-built from GHCR
podman pull ghcr.io/coverup20/ns8-checkmk-container:runagent
```

### Deploy

**CRITICAL:** The runagent variant requires **privileged mode** and **host mounts** to inspect NS8 modules.

#### Full NS8 deployment (Rocky Linux 9.x)

```bash
podman run -d \
  --name checkmk-agent \
  --restart=unless-stopped \
  --privileged \
  --pid=host \
  --cgroupns=host \
  --security-opt label=disable \
  -p 6556:6556 \
  -v /usr/local/agent:/usr/local/agent:ro \
  -v /usr/local/bin/runagent:/usr/local/bin/runagent:ro \
  -v /usr/bin/podman:/usr/bin/podman:ro \
  -v /usr/bin/python3.11:/usr/bin/python3.11:ro \
  -v /usr/lib64/libpython3.11.so.1.0:/usr/lib64/libpython3.11.so.1.0:ro \
  -v /usr/lib64/python3.11:/usr/lib64/python3.11:ro \
  -v /etc/passwd:/etc/passwd:ro \
  -v /etc/group:/etc/group:ro \
  -v /etc/shadow:/etc/shadow:ro \
  -v /etc/nethserver:/etc/nethserver:ro \
  -v /run/user:/run/user:rw \
  -v /home:/home:ro \
  ghcr.io/coverup20/ns8-checkmk-container:runagent
```

#### With FRPC tunnel

Add FRPC environment variables to the command above:

```bash
podman run -d \
  --name checkmk-agent \
  --restart=unless-stopped \
  --privileged \
  --pid=host \
  --cgroupns=host \
  --security-opt label=disable \
  -p 6556:6556 \
  -e FRPC_SERVER_ADDR=monitor.nethlab.it \
  -e FRPC_SERVER_PORT=7000 \
  -e FRPC_TOKEN=conduit-reenact-talon-macarena-demotion-vaguely \
  -e FRPC_PROXY_NAME=rl94ns8 \
  -e FRPC_REMOTE_PORT=6020 \
  -v /usr/local/agent:/usr/local/agent:ro \
  -v /usr/local/bin/runagent:/usr/local/bin/runagent:ro \
  -v /usr/bin/podman:/usr/bin/podman:ro \
  -v /usr/bin/python3.11:/usr/bin/python3.11:ro \
  -v /usr/lib64/libpython3.11.so.1.0:/usr/lib64/libpython3.11.so.1.0:ro \
  -v /usr/lib64/python3.11:/usr/lib64/python3.11:ro \
  -v /etc/passwd:/etc/passwd:ro \
  -v /etc/group:/etc/group:ro \
  -v /etc/shadow:/etc/shadow:ro \
  -v /etc/nethserver:/etc/nethserver:ro \
  -v /run/user:/run/user:rw \
  -v /home:/home:ro \
  ghcr.io/coverup20/ns8-checkmk-container:runagent
```

### Runtime Requirements Explained

| Flag / Mount | Purpose | Required |
|--------------|---------|----------|
| `--privileged` | Allows container to execute Podman commands on host | Yes |
| `--pid=host` | Share host PID namespace (needed for module process inspection) | Yes |
| `--cgroupns=host` | Share host cgroup namespace (needed for `podman exec` into rootless modules) | Yes |
| `--security-opt label=disable` | Disable SELinux labeling (NS8 modules use complex labeling) | Recommended |
| `/usr/local/agent` | NS8 agent Python environment (runagent runtime dependencies) | Yes |
| `/usr/local/bin/runagent` | NS8 runagent binary | Yes |
| `/usr/bin/python3.11` | Python 3.11 binary (runagent shebang) | Yes |
| `/usr/bin/podman` | Podman binary (for module container inspection) | Yes |
| `/usr/lib64/libpython3.11.so.1.0` | Python 3.11 shared library | Yes |
| `/usr/lib64/python3.11` | Python 3.11 standard library | Yes |
| `/etc/passwd`, `/etc/group`, `/etc/shadow` | Host user/group database (module users: `mail1`, `samba1`, etc.) | Yes |
| `/etc/nethserver` | NS8 agent configuration (`agent.env`) | Yes |
| `/run/user` | Module user runtime dirs (`XDG_RUNTIME_DIR`, Podman storage) | Yes (RW) |
| `/home` | Module user home dirs (agent state, env files) | Yes |

### Verification

```bash
# Test CheckMK agent response
echo | nc localhost 6556 | grep -E "NS8|NV8|WebTop|Tomcat"

# List deployed checks inside container
podman exec checkmk-agent ls /usr/lib/check_mk_agent/local/

# Test runagent availability
podman exec checkmk-agent runagent -h

# Check FRPC tunnel status (if configured)
podman logs checkmk-agent | grep frpc
```

---

## Troubleshooting

### Base image issues

**Problem:** CheckMK agent not responding on port 6556

```bash
# Check if socat is running
podman exec checkmk-agent ps aux | grep socat

# Check agent output
podman exec checkmk-agent check_mk_agent

# View entrypoint logs
podman logs checkmk-agent
```

**Problem:** FRPC tunnel not activating

```bash
# Verify env variables are set
podman exec checkmk-agent env | grep FRPC

# Check FRPC process
podman exec checkmk-agent ps aux | grep frpc

# View FRPC logs
podman logs checkmk-agent | grep frpc

# Expected on success:
# [d987ac446a245ebd] [rl94ns8] start proxy success
```

### Runagent image issues

**Problem:** runagent commands fail with `ModuleNotFoundError: No module named 'agent'`

**Cause:** Missing `/usr/local/agent` mount or PYTHONPATH not set.

```bash
# Verify mount exists
podman exec checkmk-agent ls /usr/local/agent/pypkg/agent/

# Verify PYTHONPATH wrapper
podman exec checkmk-agent cat /usr/bin/env | head -3
# Expected: #!/bin/sh
#           exec /usr/bin/env.orig PYTHONPATH=/usr/local/agent/pypkg "$@"

# Test runagent
podman exec checkmk-agent runagent list-modules
```

**Problem:** `podman exec` into module containers fails

**Cause:** Missing `--cgroupns=host` flag.

```bash
# Check cgroupns
podman inspect checkmk-agent | grep -i cgroupns
# Expected: "CgroupNS": "host"

# Recreate container with --cgroupns=host if missing
```

**Problem:** Module checks return "unknown user: mail1"

**Cause:** Missing `/etc/passwd`, `/etc/group`, `/etc/shadow` mounts.

```bash
# Verify mounts
podman exec checkmk-agent grep mail1 /etc/passwd
podman exec checkmk-agent grep samba1 /etc/passwd

# Check module users exist on host
grep -E 'mail1|samba1|webtop1' /etc/passwd
```

**Problem:** High execution time (>50s) on `check_mk_agent`

**Cause:** `check_ns8_container_resources` was still deployed (removed in commit 532e9b3).

```bash
# Verify check does NOT exist
podman exec checkmk-agent ls /usr/lib/check_mk_agent/local/ | grep container_resources
# Expected: (no output)

# If present, recreate container from latest image
podman pull ghcr.io/coverup20/ns8-checkmk-container:runagent
podman stop checkmk-agent && podman rm checkmk-agent
# Re-run deploy command
```

---

## Build & Publish Workflow

### Local build

```bash
# Base variant
podman build -f Containerfile -t checkmk-agent:latest .

# Runagent variant
podman build -f Containerfile.runagent -t checkmk-agent:runagent .

# Test locally before pushing
podman run -d --name test-base -p 6556:6556 checkmk-agent:latest
echo | nc localhost 6556 | head
podman stop test-base && podman rm test-base
```

### Tag & push to GHCR

```bash
# Login to GHCR (one-time)
echo $GITHUB_TOKEN | podman login ghcr.io -u Coverup20 --password-stdin

# Tag images
podman tag checkmk-agent:latest ghcr.io/coverup20/ns8-checkmk-container:latest
podman tag checkmk-agent:runagent ghcr.io/coverup20/ns8-checkmk-container:runagent

# Push to registry
podman push ghcr.io/coverup20/ns8-checkmk-container:latest
podman push ghcr.io/coverup20/ns8-checkmk-container:runagent
```

### GitHub Actions (automated)

CI/CD pipeline in `.github/workflows/build.yml` automatically:

1. Builds both variants on push to `main`
2. Tags with commit SHA (`sha-abc1234`)
3. Tags `:latest` and `:runagent` (rolling tags)
4. Pushes to `ghcr.io/coverup20/ns8-checkmk-container`

Trigger: `git push origin main`

---

## Production Deployment Reference

### Example: rl94ns8 (10.155.100.40)

**Host:** Rocky Linux 9.7, NethServer 8 production node  
**Modules:** samba1, mail2, webtop1, webtop3  
**Container:** `ghcr.io/coverup20/ns8-checkmk-container:runagent` (digest `354ed9db`)  
**FRPC tunnel:** rl94ns8 → monitor.nethlab.it:7000 → port 6020

```bash
# Deployed with:
ssh rl94ns8 'podman stop checkmk-agent && podman rm checkmk-agent && podman run -d \
  --name checkmk-agent --restart unless-stopped \
  --privileged --pid=host --cgroupns=host --security-opt label=disable \
  -e FRPC_SERVER_ADDR=monitor.nethlab.it -e FRPC_SERVER_PORT=7000 \
  -e FRPC_TOKEN=conduit-reenact-talon-macarena-demotion-vaguely \
  -e FRPC_PROXY_NAME=rl94ns8 -e FRPC_REMOTE_PORT=6020 \
  -v /usr/local/agent:/usr/local/agent:ro \
  -v /usr/local/bin/runagent:/usr/local/bin/runagent:ro \
  -v /usr/bin/podman:/usr/bin/podman:ro \
  -v /usr/bin/python3.11:/usr/bin/python3.11:ro \
  -v /usr/lib64/libpython3.11.so.1.0:/usr/lib64/libpython3.11.so.1.0:ro \
  -v /usr/lib64/python3.11:/usr/lib64/python3.11:ro \
  -v /etc/passwd:/etc/passwd:ro -v /etc/group:/etc/group:ro \
  -v /etc/shadow:/etc/shadow:ro -v /etc/nethserver:/etc/nethserver:ro \
  -v /run/user:/run/user:rw -v /home:/home:ro \
  ghcr.io/coverup20/ns8-checkmk-agent:runagent'

# Verify deployment
ssh rl94ns8 'podman logs checkmk-agent | grep frpc'
# Expected: [d987ac446a245ebd] [rl94ns8] start proxy success

# Test local checks via tunnel
ssh checkmk-vps-01 'echo | nc localhost 6020 | grep -E "NS8|WebTop|NV8"'
```

---

## Related Documentation

- [README.md](README.md) — Quick start and feature overview
- [Coverup20/ns8-checkmk-agent](https://github.com/Coverup20/ns8-checkmk-agent) — Check script source repository
- [GHCR Package](https://github.com/Coverup20/ns8-checkmk-container/pkgs/container/ns8-checkmk-container) — Pre-built images

---

**Version:** 1.0.0  
**Last updated:** 2026-04-20  
**Author:** Coverup20 / Nethesis
