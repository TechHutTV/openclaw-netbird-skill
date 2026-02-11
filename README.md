# NetBird OpenClaw Skill

An OpenClaw skill for managing NetBird zero-trust networks via CLI and REST API.

## Structure

```
netbird/
├── SKILL.md              # Skill definition (frontmatter + instructions)
├── scripts/
│   └── nb-api.sh         # REST API helper script
└── README.md             # This file
```

## Installation

### Local install (for your own OpenClaw instance)

Copy the `netbird/` folder into your OpenClaw skills directory:

```bash
cp -r netbird/ ~/.openclaw/skills/netbird
```

Or into your workspace skills:

```bash
cp -r netbird/ <workspace>/skills/netbird
```

### Configuration

1. **CLI**: Ensure `netbird` is installed and the daemon is running.

2. **API** (optional): Create a credentials file for network-wide management:

```bash
mkdir -p ~/.openclaw/credentials/netbird
cat > ~/.openclaw/credentials/netbird/config.json << 'EOF'
{
  "apiToken": "nbp_YOUR_TOKEN_HERE",
  "managementUrl": "https://api.netbird.io"
}
EOF
```

Get your API token from: NetBird Dashboard → Users → your user → Create Token

3. **OpenClaw config** (optional): Enable in `~/.openclaw/openclaw.json`:

```json
{
  "skills": {
    "entries": {
      "netbird": {
        "enabled": true,
        "apiKey": "nbp_YOUR_TOKEN_HERE",
        "env": {
          "NETBIRD_API_TOKEN": "nbp_YOUR_TOKEN_HERE",
          "NETBIRD_MANAGEMENT_URL": "https://api.netbird.io"
        }
      }
    }
  }
}
```

## Publishing to ClawHub

To publish to the OpenClaw skills registry:

```bash
# From the parent directory containing the netbird/ folder
clawhub publish netbird
```

Or submit a PR to the [openclaw/skills](https://github.com/openclaw/skills) repository
following their contribution guidelines.

## What it does

- **CLI operations**: Connect/disconnect, check status, SSH to peers, manage routes
- **API operations**: List/manage peers, groups, setup keys, access policies, DNS, routes, users, and audit events
- **Trigger phrases**: "check netbird status", "list peers", "create setup key", "add access policy", "who's connected", etc.

## Self-hosted support

For self-hosted NetBird deployments, set `managementUrl` to your management server URL.
