# AVA Windows Safe Audit

## Start

Open PowerShell in the AVA repository and run:

```powershell
powershell.exe -NoProfile -File .\scripts\windows\AVA_DEVITO_01610_SAFE_AUDIT_READONLY.ps1
```

The script is intended for local defensive inspection. It does not change firewall rules, Defender settings, registry values, services, scheduled tasks, or user settings. It writes one JSON report to a timestamped folder on the Desktop.

## Privacy by default

The supplied ZIP version was reviewed statically. It does not appear to intentionally upload collected data, but it records detailed local information including user/account names, network addresses and connections, process paths, autorun registry values, event messages, recent download names and file hashes, then creates a ZIP. These fields can reveal personal or security-sensitive information.

The repository variant therefore minimizes collection: it omits account names, IP/MAC addresses, process command lines/paths, registry autoruns, download metadata and full event messages. Inspect the resulting report before sharing it. Do not commit raw audit output to GitHub.

## Validation status

Static review only. Run on a Windows test machine before relying on it. No claim is made that it has been executed on the user's laptop.
