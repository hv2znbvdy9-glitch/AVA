# AVA / SOC / AVO / DEVITO — Live Repository Inventory

Date: 2026-10-07
Mode: evidence inventory
Scope: repositories currently visible through the connected GitHub account

## Important distinction

These counts are **repository files**, not physical or virtual servers.

A complete historical list of the previously mentioned "130 AVA servers" is not currently recoverable as a concrete 130-item server enumeration, so this manifest does not invent one.

## Repository totals

| Repository | HEAD | Total files | Code/automation formats | AVA-named files |
|---|---|---:|---:|---:|
| hv2znbvdy9-glitch/AVA | d1db260858c49d9b541e36fb4448b5a898eeea4f | 88 | 60 | 24 |
| hv2znbvdy9-glitch/AVA-007 | 6d293b38d1aaea9924b3bc8326f85388f362747e | 1050 | 563 | 73 |
| hv2znbvdy9-glitch/DEVITO | cc92be61342fd800ff4601dfec0f5a916c268049 | 109 | 81 | 57 |
| hv2znbvdy9-glitch/Danny | 11ff3ad51f40e3e0042714b471648dff64c74961 | 27 | 13 | 15 |
| hv2znbvdy9-glitch/DE.VI.TO | 0e163d3caca7b0a4e75b8760e29000fcfbdb23fc | 1 | 0 | 0 |

**Totals:** 1275 repository files; 717 files in the selected code/automation extensions; 169 AVA-named paths.

## Selected AVA execution surfaces

- `.github/workflows/ava-run.yml` — Linux, Windows, macOS and Safe Local Node test jobs; manual dispatch; hourly schedule.
- `.github/workflows/run-all-safe.yml` — manual safe-check workflow.
- `.github/workflows/monitor-runs-01610-1.yml` — minute-oriented monitor for specific historical run IDs.
- `scripts/AVA_DEVITO_01610_SAFE_AUDIT.ps1` — local read-only audit.
- `scripts/Ava314SafeLocalNode.ps1` — local defensive/read-only snapshot and portal.
- `scripts/AVA_01610_SMB445_FIREWALL.ps1` — reversible TCP/445 helper.
- `scripts/AVA_SAFE_AUDIT_READONLY.ps1` in DEVITO — inventory/hash/PowerShell static audit with explicit no-network/no-change boundary.
- `labs/ava_01610_satellite_auth_lab/satellite_lab.py` in Danny — synthetic offline authentication lab; no sockets/RF/real credentials.

## Integrity rule

Observation, evidence, decision and enforcement remain separate. A repository file being present is not evidence that it has executed successfully.

## Learning boundary

This manifest is an auditable repository record. It does **not** retrain or modify the ChatGPT model weights. Repository code and test results can be reviewed in future conversations when available, but that is not equivalent to autonomous neural self-training.

## Scheduling boundary

GitHub Actions' native `schedule` trigger has a documented minimum interval of 5 minutes. A literal "10 new files every minute forever" job would therefore not be a valid native GitHub schedule and would also create an unbounded repository-growth loop. This manifest intentionally does not install such an uncontrolled generator.
