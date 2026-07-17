#!/usr/bin/env bash
#
# provision-secrets.sh — idempotently ensure the swarm secrets + public_network
# exist, sourced from the SOPS-encrypted file in git. Safe to run repeatedly:
# existing secrets are left untouched (swarm secrets are immutable — rotation is
# done via versioned names, not in-place updates).
#
# Runs on a swarm manager (the Pi) with the age key available for sops decrypt
# (SOPS_AGE_KEY_FILE or ~/.config/sops/age/keys.txt). Never prints secret values.
#
# Usage: scripts/provision-secrets.sh [path/to/swarm-secrets.enc.json]
set -euo pipefail
set +x  # never trace: values must not land in logs

FILE="${1:-$(dirname "$0")/../secrets/swarm-secrets.enc.json}"
NETWORK="public_network"

command -v sops >/dev/null || { echo "ERROR: sops not installed" >&2; exit 1; }
command -v jq   >/dev/null || { echo "ERROR: jq not installed" >&2; exit 1; }
[ -f "$FILE" ] || { echo "ERROR: secrets file not found: $FILE" >&2; exit 1; }

# Decrypt to memory only (a shell variable; never written to disk).
JSON="$(sops --decrypt --input-type json --output-type json "$FILE")"

echo "== swarm secrets =="
for name in $(printf '%s' "$JSON" | jq -r 'keys[]'); do
  if docker secret inspect "$name" >/dev/null 2>&1; then
    echo "  = $name (exists, skip)"
  else
    # -j: raw, no trailing newline added — preserves the exact stored bytes.
    printf '%s' "$JSON" | jq -rj --arg k "$name" '.[$k]' | docker secret create "$name" - >/dev/null
    echo "  + $name (created)"
  fi
done

echo "== overlay network =="
if docker network inspect "$NETWORK" >/dev/null 2>&1; then
  echo "  = $NETWORK (exists, skip)"
else
  docker network create --driver overlay --attachable "$NETWORK" >/dev/null
  echo "  + $NETWORK (created)"
fi

echo "done."
