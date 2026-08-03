#!/usr/bin/env bash
# setup-mcp.sh - One-click setup for commonly-used MCP servers (macOS / Linux)
#
# Purpose:
#   Register 3 MCP servers used across projects/hosts (jira-mcp, playwright,
#   postman) at Claude Code user scope, so a new host only needs credentials
#   filled in once instead of re-typing `claude mcp add` by hand.
#
#   Credentials live in a separate, gitignored, host-local file
#   (mcp-secrets.local.json, next to this script) so this script itself never
#   carries secrets. To rotate a token, edit that file and re-run this script -
#   it removes and re-adds each server, so re-running is always safe.
#
# Usage:
#   bash <repo>/setting/setup-mcp.sh
#
# First run on a host:
#   - If this host already has jira-mcp/postman registered (e.g. this is the
#     host the config was first set up on), their existing env values are
#     extracted into mcp-secrets.local.json automatically.
#   - Otherwise a blank template is written; fill it in and re-run.
#
# Requires: jq (for safely reading/writing JSON without hand-rolled parsing).
#
# Note on the Docker command form:
#   The Windows counterpart (setup-mcp.ps1) wraps the docker command in
#   `cmd /c "..."` because that's how it was already configured there. On
#   macOS/Linux there's no such shell wrapper needed - docker is invoked
#   directly with normal argv, which is the more portable form.
#
# Note on a Windows-only bug this script does NOT work around:
#   Live testing on Windows found that `claude` there resolves to a buggy
#   npm-generated .ps1 shim that mangles `claude mcp add` arguments, requiring
#   a workaround (calling the bundled claude.exe directly). That is a
#   Windows/PowerShell-specific packaging issue; it has not been observed or
#   tested here, so this script calls `claude` directly per the documented
#   CLI. If `claude mcp add` misbehaves on this platform, report it -
#   don't assume the Windows workaround applies here without verifying.

set -euo pipefail

repo="$(cd "$(dirname "$0")/.." && pwd)"
secrets_path="$repo/setting/mcp-secrets.local.json"

if ! command -v jq >/dev/null 2>&1; then
    echo "jq not found. Install it first (e.g. 'brew install jq' or 'apt install jq') and re-run."
    exit 1
fi

if ! command -v claude >/dev/null 2>&1; then
    echo "claude CLI not found on PATH. Install Claude Code first."
    exit 1
fi

# ------------------------------------------------------------------
# Load or bootstrap the local secrets file
# ------------------------------------------------------------------
get_existing_env() {
    local server_name="$1" key="$2"
    local claude_json="$HOME/.claude.json"
    [ -f "$claude_json" ] || { echo ""; return; }
    jq -r --arg s "$server_name" --arg k "$key" \
        '.mcpServers[$s].env[$k] // ""' "$claude_json" 2>/dev/null || echo ""
}

if [ ! -f "$secrets_path" ]; then
    echo "No local secrets file found - bootstrapping $secrets_path"

    jira_url="$(get_existing_env jira-mcp JIRA_URL)"
    jira_username="$(get_existing_env jira-mcp JIRA_USERNAME)"
    jira_token="$(get_existing_env jira-mcp JIRA_API_TOKEN)"
    postman_key="$(get_existing_env postman POSTMAN_API_KEY)"

    jq -n \
        --arg jira_url "$jira_url" \
        --arg jira_username "$jira_username" \
        --arg jira_token "$jira_token" \
        --arg postman_key "$postman_key" \
        '{
            jira: { JIRA_URL: $jira_url, JIRA_USERNAME: $jira_username, JIRA_API_TOKEN: $jira_token },
            postman: { POSTMAN_API_KEY: $postman_key }
        }' > "$secrets_path"
    echo "Wrote $secrets_path"

    if [ -z "$jira_url" ] || [ -z "$jira_username" ] || [ -z "$jira_token" ] || [ -z "$postman_key" ]; then
        echo ""
        echo "Some values could not be auto-detected from this host's existing config."
        echo "Fill in the blank fields in $secrets_path, then re-run this script."
        exit 0
    else
        echo "Auto-filled from this host's existing MCP config."
    fi
fi

jira_url="$(jq -r '.jira.JIRA_URL' "$secrets_path")"
jira_username="$(jq -r '.jira.JIRA_USERNAME' "$secrets_path")"
jira_token="$(jq -r '.jira.JIRA_API_TOKEN' "$secrets_path")"
postman_key="$(jq -r '.postman.POSTMAN_API_KEY' "$secrets_path")"

ok=1
[ -n "$jira_url" ]      || { echo "Missing value: jira.JIRA_URL (edit $secrets_path and re-run)"; ok=0; }
[ -n "$jira_username" ] || { echo "Missing value: jira.JIRA_USERNAME (edit $secrets_path and re-run)"; ok=0; }
[ -n "$jira_token" ]    || { echo "Missing value: jira.JIRA_API_TOKEN (edit $secrets_path and re-run)"; ok=0; }
[ -n "$postman_key" ]   || { echo "Missing value: postman.POSTMAN_API_KEY (edit $secrets_path and re-run)"; ok=0; }
if [ "$ok" -ne 1 ]; then
    echo "Fill in the missing values above and re-run this script."
    exit 1
fi

# ------------------------------------------------------------------
# Register (idempotent: remove any existing entry, then add fresh)
# ------------------------------------------------------------------
register_mcp_server() {
    local name="$1"
    shift
    claude mcp remove "$name" -s user >/dev/null 2>&1 || true

    if claude mcp add "$name" -s user "$@"; then
        echo "Registered: $name"
    else
        echo "WARNING: Failed to register $name"
    fi
}

# jira-mcp: Docker image, credentials passed through as env vars
register_mcp_server jira-mcp \
    -e "JIRA_URL=$jira_url" \
    -e "JIRA_USERNAME=$jira_username" \
    -e "JIRA_API_TOKEN=$jira_token" \
    -t stdio \
    -- docker run -i --rm -e JIRA_URL -e JIRA_USERNAME -e JIRA_API_TOKEN ghcr.io/sooperset/mcp-atlassian:latest

# playwright: no credentials; resolve the global npm bin path dynamically
npm_prefix="$(npm config get prefix)"
playwright_cmd="$npm_prefix/bin/playwright-mcp-server"
if [ ! -x "$playwright_cmd" ]; then
    echo "playwright-mcp-server not found - installing @executeautomation/playwright-mcp-server globally..."
    npm install -g '@executeautomation/playwright-mcp-server'
fi
register_mcp_server playwright -t stdio -- "$playwright_cmd"

# postman: no local install needed, npx resolves it on demand
register_mcp_server postman \
    -e "POSTMAN_API_KEY=$postman_key" \
    -t stdio \
    -- npx -y @postman/postman-mcp-server

echo ""
echo "Done. Verifying:"
claude mcp list | grep -E 'jira-mcp|playwright|postman' || true
echo ""
echo "To rotate credentials later: edit $secrets_path, then re-run this script."
