---
name: netbird
description: Manage NetBird zero-trust network via CLI and REST API. Use when the user asks to "check netbird status", "list netbird peers", "connect to netbird", "create setup key", "manage groups", "add access policy", "check who's connected", "SSH via netbird", or mentions NetBird network management.
metadata: {"openclaw":{"requires":{"bins":["netbird"]},"primaryEnv":"NETBIRD_API_TOKEN","emoji":"🐦"}}
---

# NetBird Network Management

Hybrid skill using CLI for local peer operations and REST API for network-wide management.

## API config (optional, for network-wide operations)

`~/.openclaw/credentials/netbird/config.json`

```json
{
  "apiToken": "nbp_XXXXXXXXXXXXXXXXXXXX",
  "managementUrl": "https://api.netbird.io"
}
```

- `apiToken`: Personal access token from NetBird dashboard (Users → your user → Create Token)
- `managementUrl`: For SaaS use `https://api.netbird.io`. For self-hosted, use your management URL (may need port 33073).

---

## CLI Commands (local machine)

These work on the current machine only. Requires the `netbird` daemon to be running.

### Connection management

```bash
# Connect to NetBird network (starts daemon + authenticates)
netbird up

# Connect with a setup key (headless/automated)
netbird up --setup-key AAAA-BBB-CCC-DDDDDD

# Connect to self-hosted management
netbird up --management-url https://api.self-hosted.com:33073

# Enable SSH server on this peer
netbird up --allow-server-ssh

# Enable quantum-resistant encryption (Rosenpass)
netbird up --enable-rosenpass

# Disconnect from NetBird network
netbird down

# Authenticate only (no connect)
netbird login
netbird login --setup-key AAAA-BBB-CCC-DDDDDD

# Logout (deregister)
netbird logout
```

### Status & diagnostics

```bash
# Quick status overview
netbird status

# Detailed peer info (connection types, IPs, transfer stats, latency)
netbird status -d

# Detailed + anonymized (safe for sharing in bug reports)
netbird status -dA

# JSON output for scripting
netbird status --json

# Check version
netbird version
```

### SSH via NetBird

```bash
# SSH to a peer by NetBird IP
netbird ssh user@100.119.230.104

# SSH and run a command
netbird ssh user@100.119.230.104 "uptime"
```

Note: SSH must be enabled on the target peer (`--allow-server-ssh`) and permitted by access control policies.

### Network routes (client-side)

```bash
# List available network routes
netbird networks ls

# Select/deselect specific networks
netbird networks select <network-id>
netbird networks deselect <network-id>
```

### Service management

```bash
# Install/uninstall the daemon service
netbird service install
netbird service uninstall

# Start/stop the daemon
netbird service start
netbird service stop
```

### Useful one-liners

```bash
# List connected peers with IPs (parse JSON status)
netbird status --json | jq '.peers.details[] | select(.connectionStatus == "Connected") | {name: .fqdn, ip: .netbirdIp, type: .connectionType, latency: .latency}'

# Count connected vs total peers
netbird status --json | jq '{connected: [.peers.details[] | select(.connectionStatus == "Connected")] | length, total: .peers.details | length}'

# Get this machine's NetBird IP
netbird status --json | jq -r '.netbirdIp'

# Check management & signal connectivity
netbird status --json | jq '{management: .managementState, signal: .signalState}'
```

---

## REST API Commands (network-wide)

These manage your entire NetBird account/network. Requires an API token.

All API commands use the helper script: `{baseDir}/scripts/nb-api.sh`

### Peers

```bash
# List all peers
{baseDir}/scripts/nb-api.sh peers

# List with full details
{baseDir}/scripts/nb-api.sh peers --verbose

# Get a specific peer
{baseDir}/scripts/nb-api.sh peer <peer-id>

# Delete a peer
{baseDir}/scripts/nb-api.sh delete-peer <peer-id>
```

### Groups

```bash
# List all groups
{baseDir}/scripts/nb-api.sh groups

# Create a group
{baseDir}/scripts/nb-api.sh create-group --name "web-servers"

# Add a peer to a group
{baseDir}/scripts/nb-api.sh update-group <group-id> --add-peer <peer-id>

# Delete a group
{baseDir}/scripts/nb-api.sh delete-group <group-id>
```

### Setup Keys

```bash
# List all setup keys
{baseDir}/scripts/nb-api.sh setup-keys

# Create a one-time setup key
{baseDir}/scripts/nb-api.sh create-setup-key --name "deploy-key" --type one-off

# Create a reusable key with auto-assign groups and 30-day expiry
{baseDir}/scripts/nb-api.sh create-setup-key --name "server-key" --type reusable --expires 2592000 --groups "group-id-1,group-id-2"

# Create an ephemeral key (peer auto-removed when offline)
{baseDir}/scripts/nb-api.sh create-setup-key --name "ephemeral-agents" --type reusable --ephemeral

# Revoke a setup key
{baseDir}/scripts/nb-api.sh revoke-setup-key <key-id>
```

### Access Control Policies

```bash
# List all policies
{baseDir}/scripts/nb-api.sh policies

# Get a specific policy
{baseDir}/scripts/nb-api.sh policy <policy-id>

# Create a policy (allows src group to reach dst group)
{baseDir}/scripts/nb-api.sh create-policy --name "Dev SSH Access" --src-group <group-id> --dst-group <group-id> --protocol tcp --port 22

# Delete a policy
{baseDir}/scripts/nb-api.sh delete-policy <policy-id>
```

### Networks & Routes

```bash
# List all networks
{baseDir}/scripts/nb-api.sh networks

# List all routes
{baseDir}/scripts/nb-api.sh routes

# Get a specific route
{baseDir}/scripts/nb-api.sh route <route-id>
```

### DNS

```bash
# List nameserver groups
{baseDir}/scripts/nb-api.sh nameservers

# Get DNS settings
{baseDir}/scripts/nb-api.sh dns-settings
```

### Users

```bash
# List all users
{baseDir}/scripts/nb-api.sh users

# Get current account info
{baseDir}/scripts/nb-api.sh account
```

### Events (Audit Log)

```bash
# List recent events
{baseDir}/scripts/nb-api.sh events

# List events with limit
{baseDir}/scripts/nb-api.sh events --limit 50
```

---

## Common Workflows

### Onboard a new server

1. Create a setup key with appropriate groups:
   ```bash
   {baseDir}/scripts/nb-api.sh create-setup-key --name "new-server" --type one-off --groups "<group-id>"
   ```
2. On the server, install NetBird and connect:
   ```bash
   netbird up --setup-key <KEY>
   ```

### Troubleshoot connectivity

1. Check local status: `netbird status -d`
2. Look for `Connection type: P2P` vs `Relayed`
3. Check management/signal connectivity
4. Verify peer is in correct groups via API: `{baseDir}/scripts/nb-api.sh peers --verbose`
5. Check policies allow the desired traffic: `{baseDir}/scripts/nb-api.sh policies`

### Quick network audit

```bash
# How many peers, which are online?
{baseDir}/scripts/nb-api.sh peers | jq '[.[] | {name: .name, ip: .ip, connected: .connected, os: .os, last_seen: .last_seen}]'

# What setup keys exist and are still valid?
{baseDir}/scripts/nb-api.sh setup-keys | jq '[.[] | select(.valid == true) | {name: .name, type: .type, used: .used_times, expires: .expires}]'
```

---

## Key Differences from Tailscale

| Feature | NetBird | Tailscale |
|---------|---------|-----------|
| Architecture | Zero-trust, WireGuard mesh | WireGuard mesh (coordination server) |
| Identity | External IdP or embedded Dex | Built-in / Google / OIDC |
| Access control | Group-based policies | ACLs (HuJSON) |
| Self-hosting | Fully self-hostable | Headscale (community) |
| CLI status | `netbird status -d` | `tailscale status` |
| File transfer | Not built-in (use SSH/SCP) | `tailscale file cp` |
| DNS | Configurable nameserver groups | MagicDNS |

---

## References

- CLI docs: https://docs.netbird.io/how-to/cli
- REST API: https://docs.netbird.io/api
- Access control: https://docs.netbird.io/how-to/manage-network-access
- SSH access: https://docs.netbird.io/manage/peers/ssh
- Setup keys: https://docs.netbird.io/manage/peers/register-machines-using-setup-keys
