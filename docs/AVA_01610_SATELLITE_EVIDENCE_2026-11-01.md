# AVA 01610 satellite evidence isolation (2026-11-01)

The existing `scripts/AVA_01610_SATELLITE_LAB.ps1` is a **local simulation**, not access to real satellites, radio infrastructure or external services.

## Evidence improvement

Each run writes JSON, text and HTML reports into a unique timestamp-plus-GUID directory. A pre-existing run directory causes STOP instead of reuse. The associated PowerShell test runs the local simulation twice and checks that both report directories exist and that the first result remains.

## Related uploaded analysis

A separately supplied offline ZIP included a different synthetic HMAC authentication lab and a JSON report created on **2026-08-05**. That source allows `SatelliteCount=1` even though its demo assumes satellite 2, and its second-resolution run ID can collide. Its JSONL log is not cryptographically chained or signed. No claim is made that the uploaded lab was run on Windows.

## Windows manual verification

From a trusted checkout of this draft PR in normal, non-elevated PowerShell:

```powershell
powershell.exe -NoProfile -File .\scripts\AVA_01610_SATELLITE_LAB.ps1
```

It writes into a new run-specific subfolder within `Desktop\AVA_01610_SATELLITE_LAB`. Local paths may appear in reports; review before sharing. Do not commit personal raw audit logs.

## Boundaries

No host-OS security changes, firewall modifications, network access, real satellites, workflow-dispatch fan-out or automatic deployment. Static tests are separate from PowerShell runtime tests, and no local Windows execution is claimed. Do not merge without reviewing CI and runtime logs.
