#!/usr/bin/env bash
#
# capture-secrets.sh — one-off / occasional: read the CURRENT swarm secret values
# off the running containers (on the Pi) and write them SOPS-ENCRYPTED into git.
#
# The plaintext NEVER leaves this host and never hits durable disk: values are read
# in-process and encrypted straight to the output file. Only the age-encrypted file
# is committed. Decryption requires the age private key (kept only on the Pi).
#
# Run on a swarm manager (the Pi), from the repo root:
#   scripts/capture-secrets.sh [out.enc.json]
#
# Re-run whenever a secret is rotated to refresh the versioned copy in git.
set -euo pipefail
set +x  # never trace secret values

RECIPIENT="age1lp0mjc900vahqvuyg6dr45vcpu03pddljspkhw6pppj8k5vp49kqynk9nq"
OUT="${1:-$(dirname "$0")/../secrets/swarm-secrets.enc.json}"

# The swarm secrets we manage. (Configs are intentionally excluded — the 5 live
# swarm configs are orphaned/unreferenced and belong to cleanup, not provisioning.)
SECRETS=(
  llm_api_key
  openrouter_api_key
  verly_bot_username
  verly_bot_password
  verly_prod_db_password
  verly_staging_db_password
  whatsapp_evolution_api_key
)

command -v sops >/dev/null || { echo "ERROR: sops not installed" >&2; exit 1; }

# tmpfs (RAM-backed) staging so plaintext never touches disk; 0600; wiped on exit.
TMP="$(mktemp /dev/shm/swarmsec.XXXXXX)"
chmod 600 "$TMP"
cleanup() { rm -f "$TMP"; }
trap cleanup EXIT

# Read exact bytes per secret (via python to avoid shell command-substitution
# stripping trailing newlines) and emit a JSON object to the tmpfs file.
python3 - "$TMP" "${SECRETS[@]}" <<'PY'
import json, subprocess, sys

tmp_path = sys.argv[1]
wanted = sys.argv[2:]

def sh(*args):
    return subprocess.run(list(args), capture_output=True, text=True, check=True).stdout

# Map SecretName -> (service, in-container target path) from the service specs.
loc = {}
for svc in sh("docker", "service", "ls", "--format", "{{.Name}}").split():
    spec = sh("docker", "service", "inspect", svc, "--format",
              "{{range .Spec.TaskTemplate.ContainerSpec.Secrets}}{{.SecretName}}\t{{.File.Name}}\n{{end}}")
    for line in spec.splitlines():
        if not line.strip():
            continue
        sname, tpath = line.split("\t", 1)
        loc.setdefault(sname, (svc, tpath))

out = {}
missing = []
for name in wanted:
    if name not in loc:
        missing.append(name); print(f"WARN: {name}: not mounted by any service", file=sys.stderr); continue
    svc, tpath = loc[name]
    cids = sh("docker", "ps", "--filter", f"label=com.docker.swarm.service.name={svc}",
              "--format", "{{.ID}}").split()
    if not cids:
        missing.append(name); print(f"WARN: {name}: no running container for {svc}", file=sys.stderr); continue
    raw = subprocess.run(["docker", "exec", cids[0], "cat", f"/run/secrets/{tpath}"],
                         capture_output=True, check=True).stdout
    out[name] = raw.decode("utf-8")
    print(f"  captured {name}  (from {svc}:/run/secrets/{tpath})", file=sys.stderr)

with open(tmp_path, "w") as f:
    json.dump(out, f)

if missing:
    print(f"WARN: {len(missing)} secret(s) not captured: {', '.join(missing)}", file=sys.stderr)
PY

# Encrypt straight to git-tracked output (values only ever leave RAM encrypted).
mkdir -p "$(dirname "$OUT")"
sops --encrypt --age "$RECIPIENT" --input-type json --output-type json "$TMP" > "$OUT"
echo "wrote encrypted $OUT"
echo "captured secrets: $(sops --decrypt --input-type json --output-type json "$OUT" | python3 -c 'import json,sys;print(", ".join(json.load(sys.stdin).keys()))')"
