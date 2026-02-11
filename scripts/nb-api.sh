#!/usr/bin/env bash
set -euo pipefail

# NetBird API helper for OpenClaw
# Usage: nb-api.sh <command> [options]

CONFIG_FILE="${HOME}/.openclaw/credentials/netbird/config.json"

# --- Config loading ---
load_config() {
  if [[ -n "${NETBIRD_API_TOKEN:-}" && -n "${NETBIRD_MANAGEMENT_URL:-}" ]]; then
    API_TOKEN="$NETBIRD_API_TOKEN"
    BASE_URL="${NETBIRD_MANAGEMENT_URL%/}/api"
    return 0
  fi

  if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: No config found. Set NETBIRD_API_TOKEN and NETBIRD_MANAGEMENT_URL env vars,"
    echo "or create $CONFIG_FILE with:"
    echo '  {"apiToken": "nbp_...", "managementUrl": "https://api.netbird.io"}'
    exit 1
  fi

  API_TOKEN=$(jq -r '.apiToken // empty' "$CONFIG_FILE")
  MGMT_URL=$(jq -r '.managementUrl // "https://api.netbird.io"' "$CONFIG_FILE")
  BASE_URL="${MGMT_URL%/}/api"

  if [[ -z "$API_TOKEN" ]]; then
    echo "Error: apiToken not found in $CONFIG_FILE"
    exit 1
  fi
}

# --- HTTP helpers ---
api_get() {
  curl -sf -X GET "${BASE_URL}$1" \
    -H "Accept: application/json" \
    -H "Authorization: Token ${API_TOKEN}"
}

api_post() {
  curl -sf -X POST "${BASE_URL}$1" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -H "Authorization: Token ${API_TOKEN}" \
    --data-raw "$2"
}

api_put() {
  curl -sf -X PUT "${BASE_URL}$1" \
    -H "Accept: application/json" \
    -H "Content-Type: application/json" \
    -H "Authorization: Token ${API_TOKEN}" \
    --data-raw "$2"
}

api_delete() {
  curl -sf -X DELETE "${BASE_URL}$1" \
    -H "Accept: application/json" \
    -H "Authorization: Token ${API_TOKEN}"
}

# --- Commands ---

cmd_peers() {
  local verbose=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --verbose|-v) verbose=true; shift ;;
      *) shift ;;
    esac
  done

  local result
  result=$(api_get "/peers")

  if $verbose; then
    echo "$result" | jq '.'
  else
    echo "$result" | jq '[.[] | {id: .id, name: .name, ip: .ip, dns_label: .dns_label, connected: .connected, os: .os, last_seen: .last_seen}]'
  fi
}

cmd_peer() {
  [[ -z "${1:-}" ]] && { echo "Usage: nb-api.sh peer <peer-id>"; exit 1; }
  api_get "/peers/$1" | jq '.'
}

cmd_delete_peer() {
  [[ -z "${1:-}" ]] && { echo "Usage: nb-api.sh delete-peer <peer-id>"; exit 1; }
  api_delete "/peers/$1"
  echo "Peer $1 deleted."
}

cmd_groups() {
  api_get "/groups" | jq '[.[] | {id: .id, name: .name, peers_count: .peers_count, resources_count: .resources_count}]'
}

cmd_create_group() {
  local name=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name) name="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  [[ -z "$name" ]] && { echo "Usage: nb-api.sh create-group --name <name>"; exit 1; }
  api_post "/groups" "{\"name\": \"$name\", \"peers\": []}" | jq '.'
}

cmd_update_group() {
  [[ -z "${1:-}" ]] && { echo "Usage: nb-api.sh update-group <group-id> [--add-peer <peer-id>]"; exit 1; }
  local group_id="$1"; shift
  local add_peer=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --add-peer) add_peer="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  if [[ -n "$add_peer" ]]; then
    # Fetch current group, add peer, PUT back
    local current
    current=$(api_get "/groups/$group_id")
    local peers
    peers=$(echo "$current" | jq -r "[.peers[].id] + [\"$add_peer\"] | unique")
    local name
    name=$(echo "$current" | jq -r '.name')
    api_put "/groups/$group_id" "{\"name\": \"$name\", \"peers\": $peers}" | jq '.'
  fi
}

cmd_delete_group() {
  [[ -z "${1:-}" ]] && { echo "Usage: nb-api.sh delete-group <group-id>"; exit 1; }
  api_delete "/groups/$1"
  echo "Group $1 deleted."
}

cmd_setup_keys() {
  api_get "/setup-keys" | jq '[.[] | {id: .id, name: .name, type: .type, valid: .valid, state: .state, used_times: .used_times, expires: .expires, ephemeral: .ephemeral}]'
}

cmd_create_setup_key() {
  local name="default-key" type="one-off" expires=86400 groups="" ephemeral=false
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name) name="$2"; shift 2 ;;
      --type) type="$2"; shift 2 ;;
      --expires) expires="$2"; shift 2 ;;
      --groups) groups="$2"; shift 2 ;;
      --ephemeral) ephemeral=true; shift ;;
      *) shift ;;
    esac
  done

  local auto_groups="[]"
  if [[ -n "$groups" ]]; then
    auto_groups=$(echo "$groups" | tr ',' '\n' | jq -R . | jq -s .)
  fi

  api_post "/setup-keys" "{
    \"name\": \"$name\",
    \"type\": \"$type\",
    \"expires_in\": $expires,
    \"auto_groups\": $auto_groups,
    \"usage_limit\": 0,
    \"ephemeral\": $ephemeral
  }" | jq '.'
}

cmd_revoke_setup_key() {
  [[ -z "${1:-}" ]] && { echo "Usage: nb-api.sh revoke-setup-key <key-id>"; exit 1; }
  api_put "/setup-keys/$1" '{"revoked": true}' | jq '.'
}

cmd_policies() {
  api_get "/policies" | jq '[.[] | {id: .id, name: .name, enabled: .enabled, rules: [.rules[]? | {name: .name, protocol: .protocol, action: .action}]}]'
}

cmd_policy() {
  [[ -z "${1:-}" ]] && { echo "Usage: nb-api.sh policy <policy-id>"; exit 1; }
  api_get "/policies/$1" | jq '.'
}

cmd_create_policy() {
  local name="" src="" dst="" protocol="all" port=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --name) name="$2"; shift 2 ;;
      --src-group) src="$2"; shift 2 ;;
      --dst-group) dst="$2"; shift 2 ;;
      --protocol) protocol="$2"; shift 2 ;;
      --port) port="$2"; shift 2 ;;
      *) shift ;;
    esac
  done

  [[ -z "$name" || -z "$src" || -z "$dst" ]] && {
    echo "Usage: nb-api.sh create-policy --name <name> --src-group <id> --dst-group <id> [--protocol tcp|udp|icmp|all] [--port 22]"
    exit 1
  }

  local ports_json="[]"
  if [[ -n "$port" ]]; then
    ports_json="[\"$port\"]"
  fi

  api_post "/policies" "{
    \"name\": \"$name\",
    \"enabled\": true,
    \"rules\": [{
      \"name\": \"$name\",
      \"enabled\": true,
      \"action\": \"accept\",
      \"protocol\": \"$protocol\",
      \"ports\": $ports_json,
      \"bidirectional\": true,
      \"sources\": [\"$src\"],
      \"destinations\": [\"$dst\"]
    }]
  }" | jq '.'
}

cmd_delete_policy() {
  [[ -z "${1:-}" ]] && { echo "Usage: nb-api.sh delete-policy <policy-id>"; exit 1; }
  api_delete "/policies/$1"
  echo "Policy $1 deleted."
}

cmd_networks() {
  api_get "/networks" | jq '.'
}

cmd_routes() {
  api_get "/routes" | jq '.'
}

cmd_route() {
  [[ -z "${1:-}" ]] && { echo "Usage: nb-api.sh route <route-id>"; exit 1; }
  api_get "/routes/$1" | jq '.'
}

cmd_nameservers() {
  api_get "/dns/nameservers" | jq '.'
}

cmd_dns_settings() {
  api_get "/dns/settings" | jq '.'
}

cmd_users() {
  api_get "/users" | jq '[.[] | {id: .id, name: .name, email: .email, role: .role, status: .status, last_login: .last_login}]'
}

cmd_account() {
  api_get "/accounts" | jq '.'
}

cmd_events() {
  local limit=20
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --limit) limit="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  api_get "/events?limit=$limit" | jq '.'
}

# --- Main ---
load_config

COMMAND="${1:-help}"
shift || true

case "$COMMAND" in
  peers)            cmd_peers "$@" ;;
  peer)             cmd_peer "$@" ;;
  delete-peer)      cmd_delete_peer "$@" ;;
  groups)           cmd_groups "$@" ;;
  create-group)     cmd_create_group "$@" ;;
  update-group)     cmd_update_group "$@" ;;
  delete-group)     cmd_delete_group "$@" ;;
  setup-keys)       cmd_setup_keys "$@" ;;
  create-setup-key) cmd_create_setup_key "$@" ;;
  revoke-setup-key) cmd_revoke_setup_key "$@" ;;
  policies)         cmd_policies "$@" ;;
  policy)           cmd_policy "$@" ;;
  create-policy)    cmd_create_policy "$@" ;;
  delete-policy)    cmd_delete_policy "$@" ;;
  networks)         cmd_networks "$@" ;;
  routes)           cmd_routes "$@" ;;
  route)            cmd_route "$@" ;;
  nameservers)      cmd_nameservers "$@" ;;
  dns-settings)     cmd_dns_settings "$@" ;;
  users)            cmd_users "$@" ;;
  account)          cmd_account "$@" ;;
  events)           cmd_events "$@" ;;
  help|--help|-h)
    echo "NetBird API helper for OpenClaw"
    echo ""
    echo "Usage: nb-api.sh <command> [options]"
    echo ""
    echo "Peer commands:"
    echo "  peers [--verbose]              List all peers"
    echo "  peer <id>                      Get peer details"
    echo "  delete-peer <id>               Delete a peer"
    echo ""
    echo "Group commands:"
    echo "  groups                         List all groups"
    echo "  create-group --name <n>        Create a group"
    echo "  update-group <id> --add-peer   Add peer to group"
    echo "  delete-group <id>              Delete a group"
    echo ""
    echo "Setup key commands:"
    echo "  setup-keys                     List setup keys"
    echo "  create-setup-key [opts]        Create a setup key"
    echo "    --name <n> --type one-off|reusable --expires <sec>"
    echo "    --groups <id,id> --ephemeral"
    echo "  revoke-setup-key <id>          Revoke a setup key"
    echo ""
    echo "Policy commands:"
    echo "  policies                       List all policies"
    echo "  policy <id>                    Get policy details"
    echo "  create-policy [opts]           Create a policy"
    echo "    --name <n> --src-group <id> --dst-group <id>"
    echo "    --protocol tcp|udp|icmp|all --port <port>"
    echo "  delete-policy <id>             Delete a policy"
    echo ""
    echo "Network commands:"
    echo "  networks                       List networks"
    echo "  routes                         List routes"
    echo "  route <id>                     Get route details"
    echo ""
    echo "DNS commands:"
    echo "  nameservers                    List nameserver groups"
    echo "  dns-settings                   Get DNS settings"
    echo ""
    echo "Account commands:"
    echo "  users                          List users"
    echo "  account                        Get account info"
    echo "  events [--limit N]             List audit events"
    ;;
  *)
    echo "Unknown command: $COMMAND"
    echo "Run 'nb-api.sh help' for usage."
    exit 1
    ;;
esac
