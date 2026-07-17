# Swarm secrets as code

The Docker Swarm secrets used by the stacks (`external: true` in every compose) used to be
hand-created on the Pi with no reproducible path — if the node died, they were lost. This directory
versions them **encrypted** (SOPS + age) so they can be recreated deterministically.

- **`swarm-secrets.enc.json`** — the 7 swarm secrets, SOPS-encrypted to the age recipient in
  `.sops.yaml`. Safe to commit (only the age private key on the Pi can decrypt).

## Capture (refresh git from the live swarm)

Run **on the Pi** (a manager, where the age key lives). Reads the current values off the running
containers and writes them encrypted — plaintext never leaves the host or hits durable disk:

```bash
scripts/capture-secrets.sh          # writes secrets/swarm-secrets.enc.json
git add secrets/swarm-secrets.enc.json && git commit && git push   # commit the ENCRYPTED file
```

Re-run whenever a secret is rotated.

## Provision (recreate secrets on the swarm from git)

Idempotent — existing secrets are skipped (swarm secrets are immutable), so it's safe to run
anytime; it only does work on a fresh node / DR:

```bash
scripts/provision-secrets.sh        # docker secret create (if missing) + create public_network
```

## Rotating a secret

Swarm secrets can't be updated in place. To rotate: create a **versioned** name
(`docker secret create <name>_v2 -`), point the compose `secrets:` at the new source, redeploy the
stack, then remove the old secret and re-run `capture-secrets.sh`.

## Notes

- The `public_network` overlay (referenced `external` by every stack) is created by
  `provision-secrets.sh` if absent.
- The 5 live swarm **configs** are orphaned (no service references them) and are intentionally not
  managed here — they belong to the Phase 4 cleanup.
