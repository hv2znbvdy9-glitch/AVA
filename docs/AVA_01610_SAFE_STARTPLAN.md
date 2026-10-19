# AVA 01610 — Safe Start Plan (read-only)

## Purpose

Turn the supplied AVA ALL STARTPLAN — SAFE / DEFENSIVE into a repeatable inventory step. The script checks only whether six named launcher files exist in a package folder and computes SHA-256 hashes for files that are present.

## Run on Windows

From the repository folder in a normal PowerShell session:

    .\scripts\AVA_01610_SAFE_STARTPLAN.ps1 -PackagePath "C:\path\to\extracted\AVA_SAFE_START"

Or omit -PackagePath to inventory the repository root:

    .\scripts\AVA_01610_SAFE_STARTPLAN.ps1

The default report is written to the system temporary directory as AVA_01610_SAFE_STARTPLAN.json. To choose another location, run:

    .\scripts\AVA_01610_SAFE_STARTPLAN.ps1 -PackagePath "C:\path\to\extracted\AVA_SAFE_START" -EvidencePath "$env:USERPROFILE\Documents\AVA_01610_SAFE_STARTPLAN.json"

## What it checks

- START_AVA_DEVITO_01610_SAFE_AUDIT_READONLY.cmd
- START_AVA_SAFE_AUDIT_ADMIN.cmd
- START_01_RUNONCE_ADMIN.cmd
- START_02_LIVE_PREVIEW_ADMIN.cmd
- START_03_LIVE_AUTODEFENSE_MIT_BESTAETIGUNG_ADMIN.cmd
- START_04_ROLLBACK_BLOCKS_ADMIN.cmd

The JSON report contains presence/missing status, SHA-256 for each present launcher, timestamps, and safety boundaries. It deliberately excludes the absolute package path and does not include Windows username, computer name, IP addresses, or MAC/BSSID identifiers.

Exit codes: 0 means all six expected names were inventoried; 2 means one or more were missing; other PowerShell errors mean the inventory could not be completed. Missing files are not proof of compromise.

## Safety boundaries

- This script never launches any .cmd or .ps1 file.
- It does not elevate privileges, install dependencies, alter PowerShell policy, or modify Defender, firewall, registry, users, scheduled tasks, or Windows settings.
- START_03_LIVE_AUTODEFENSE_MIT_BESTAETIGUNG_ADMIN.cmd remains a separate manual decision. It may add firewall block rules and can interrupt legitimate connections.
- A filename or SHA-256 hash alone does not establish that a file is trustworthy. Compare the package archive hash only against the exact original archive; the hashes listed in the supplied plan are package hashes, not hashes of these individual launchers.
- Start with the read-only audit, review its output, and only then consider portal or live-preview actions. Do not treat audit entries alone as proof of an attack. Do not perform counterattacks.

## Evidence distinction

This inventory reports file presence and hashes only. It does not execute AVA, verify Windows runtime behavior, prove that AutoDefense is safe, or establish that GitHub CI passed. Those require separate runs and evidence.
