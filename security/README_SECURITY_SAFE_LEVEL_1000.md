# AVA SECURITY SAFE — Defensive Mode

This package is intentionally limited to **local defensive hardening and evidence collection**.

## Safety boundary

Allowed:

- Export the current Windows Firewall policy before changes.
- Record a local snapshot of firewall, Defender, administrators, scheduled tasks, processes, and established connections.
- Enable all Windows Firewall profiles.
- Set the default inbound action to `Block` while leaving outbound traffic allowed.
- Add named inbound block rules for TCP ports `21, 23, 135, 139, 445, 3389, 5985, 5986`.
- Request a Microsoft Defender signature update.
- Produce JSON, HTML, and transcript evidence.
- Restore a previously exported firewall policy.

Not included:

- Counterattacks or retaliation.
- Scanning, probing, exploiting, flooding, redirecting, or disrupting remote systems.
- SYSTEM scheduled tasks or other persistence.
- Endless loops.
- Credential collection or account manipulation.
- Automatic deletion of evidence.

## Recommended sequence

Open **Windows PowerShell as Administrator** from the repository folder.

### 1. Preview the changes

```powershell
.\security\AVA_SECURITY_SAFE_LEVEL_1000.ps1 -Mode Apply -WhatIf
```

### 2. Collect a read-only snapshot

```powershell
.\security\AVA_SECURITY_SAFE_LEVEL_1000.ps1 -Mode Audit
```

### 3. Apply the defensive firewall policy

```powershell
.\security\AVA_SECURITY_SAFE_LEVEL_1000.ps1 -Mode Apply -Confirm
```

The script stores its case folder under:

```text
C:\ProgramData\AVA\SecuritySafe\AVA_CASE_YYYYMMDD_HHMMSS
```

Each case contains the firewall backup, transcript, snapshot, JSON report, and HTML report.

### 4. Roll back when required

```powershell
.\security\AVA_SECURITY_SAFE_LEVEL_1000.ps1 `
  -Mode Rollback `
  -FirewallBackupPath 'C:\ProgramData\AVA\SecuritySafe\AVA_CASE_...\firewall_before.wfw' `
  -Confirm
```

## Operational note

Blocking RDP, SMB, WinRM, FTP, Telnet, and related inbound ports can interrupt services that are deliberately in use. Preview with `-WhatIf`, keep the exported `.wfw` backup, and apply only on systems you own or administer.
