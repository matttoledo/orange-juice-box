#!/usr/bin/env python3
"""stack-plan.py — a lightweight "terraform plan" for Docker Swarm stacks.

For each stack given, renders the DESIRED spec (`docker stack config`) and diffs the
high-signal fields (image / replicas / env / secrets) against the LIVE swarm
(`docker service inspect`). Prints a Markdown report to stdout (always exit 0 —
informational). Meant to run on a swarm manager (the self-hosted CI runner).

Usage: stack-plan.py <stack> [<stack> ...]
"""
from __future__ import annotations

import json
import subprocess
import sys

import yaml


def run(*args: str) -> tuple[int, str]:
    p = subprocess.run(list(args), capture_output=True, text=True)
    return p.returncode, p.stdout


def desired_services(stack: str) -> dict:
    rc, out = run("docker", "stack", "config", "-c", f"stacks/{stack}/docker-compose.yml")
    if rc != 0:
        return {}
    doc = yaml.safe_load(out) or {}
    return doc.get("services", {}) or {}


def norm_env(env) -> dict:
    if env is None:
        return {}
    if isinstance(env, dict):
        return {str(k): str(v) for k, v in env.items()}
    out = {}
    for item in env:  # list of "K=V"
        k, _, v = str(item).partition("=")
        out[k] = v
    return out


def desired_secrets(svc: dict) -> set:
    out = set()
    for s in svc.get("secrets", []) or []:
        out.add(s["source"] if isinstance(s, dict) else str(s))
    return out


def repo_tag(image: str) -> str:
    return (image or "").split("@", 1)[0]  # strip @sha256 digest


def live_service(name: str) -> dict | None:
    rc, out = run("docker", "service", "inspect", name)
    if rc != 0:
        return None
    arr = json.loads(out)
    if not arr:
        return None
    spec = arr[0]["Spec"]
    cs = spec["TaskTemplate"]["ContainerSpec"]
    replicas = spec.get("Mode", {}).get("Replicated", {}).get("Replicas")
    return {
        "image": repo_tag(cs.get("Image", "")),
        "replicas": replicas,
        "env": norm_env(cs.get("Env")),
        "secrets": {s["SecretName"] for s in cs.get("Secrets", []) or []},
    }


def trunc(v: str, n: int = 60) -> str:
    v = v.replace("\n", "\\n")
    return v if len(v) <= n else v[:n] + "…"


def plan_stack(stack: str, lines: list[str]) -> bool:
    desired = desired_services(stack)
    if not desired:
        lines.append(f"### `{stack}` — ⚠️ could not render compose (skipped)")
        return False
    changed_any = False
    lines.append(f"### `{stack}`")
    live_names = set()
    for svc, spec in desired.items():
        full = f"{stack}_{svc}"
        live_names.add(full)
        live = live_service(full)
        d_img = repo_tag(spec.get("image", ""))
        d_rep = (spec.get("deploy", {}) or {}).get("replicas", 1)
        d_env = norm_env(spec.get("environment"))
        d_sec = desired_secrets(spec)

        if live is None:
            lines.append(f"- 🟢 **{svc}**: not deployed → would be **created** (image `{d_img}`)")
            changed_any = True
            continue

        diffs = []
        if d_img != live["image"]:
            diffs.append(f"  - image: `{live['image']}` → `{d_img}`")
        if live["replicas"] is not None and int(d_rep) != int(live["replicas"]):
            diffs.append(f"  - replicas: `{live['replicas']}` → `{d_rep}`")
        # env
        for k in sorted(set(d_env) | set(live["env"])):
            dv, lv = d_env.get(k), live["env"].get(k)
            if dv == lv:
                continue
            if lv is None:
                diffs.append(f"  - env `{k}`: (absent) → `{trunc(dv)}`  _(git adds)_")
            elif dv is None:
                diffs.append(f"  - env `{k}`: `{trunc(lv)}` → (removed)  _(⚠️ live has it, git doesn't)_")
            else:
                diffs.append(f"  - env `{k}`: `{trunc(lv)}` → `{trunc(dv)}`")
        # secrets
        for s in sorted(d_sec - live["secrets"]):
            diffs.append(f"  - secret `+{s}` (git adds)")
        for s in sorted(live["secrets"] - d_sec):
            diffs.append(f"  - secret `-{s}` (⚠️ live has it, git doesn't)")

        if diffs:
            changed_any = True
            lines.append(f"- 🟠 **{svc}**: would change")
            lines.extend(diffs)
        else:
            lines.append(f"- ✅ **{svc}**: in sync")

    # services live in this stack but absent from git (prune candidates)
    rc, out = run("docker", "stack", "services", stack, "--format", "{{.Name}}")
    if rc == 0:
        for name in out.split():
            if name not in live_names:
                lines.append(f"- 🔴 **{name}**: live but not in git → would be **removed** with `--prune`")
                changed_any = True
    return changed_any


def main() -> int:
    stacks = sys.argv[1:]
    if not stacks:
        print("_(no changed stacks)_")
        return 0
    lines = ["<!-- stack-plan -->", "## 📋 Stack plan (desired git vs live swarm)", ""]
    any_change = False
    for s in stacks:
        if plan_stack(s, lines):
            any_change = True
        lines.append("")
    if not any_change:
        lines.append("✅ **No drift** — live swarm already matches git for the changed stack(s).")
    lines.append("")
    lines.append("<sub>legend: 🟢 create · 🟠 change · 🔴 remove (prune) · ✅ in sync · "
                 "env/secret `-x` = live has it but git doesn't</sub>")
    print("\n".join(lines))
    return 0


if __name__ == "__main__":
    sys.exit(main())
