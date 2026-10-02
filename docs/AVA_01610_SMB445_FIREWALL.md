# AVA 01610: Local TCP 445 Firewall Rule

This helper audits and, only when explicitly requested, manages one local
Windows Firewall rule for inbound TCP port 445. It does not stop the SMB
service, close a listener, contact other hosts, or change GitHub repositories.
Blocking inbound SMB can interrupt legitimate file and printer sharing.

Run these commands in an elevated PowerShell session from a trusted copy of
the repository. The default audit is read-only:

```powershell
.\scripts\AVA_01610_SMB445_FIREWALL.ps1
```

Review current local listeners, the `LanmanServer` service, and the AVA-owned
rule. Preview creation without changing settings:

```powershell
.\scripts\AVA_01610_SMB445_FIREWALL.ps1 -Mode Apply -WhatIf
```

After confirming SMB is not needed for this device's role, explicitly apply
the inbound-only block. PowerShell prompts for confirmation; accept only if
the proposed change is intended:

```powershell
.\scripts\AVA_01610_SMB445_FIREWALL.ps1 -Mode Apply
```

Reversibly disable the AVA rule if needed:

```powershell
.\scripts\AVA_01610_SMB445_FIREWALL.ps1 -Mode Disable
```

Disable retains the rule definition. The helper does not remove firewall rules.
It refuses to alter an existing rule with the same name if its AVA marker,
direction, action, or TCP 445 port filter does not match. Applying an already
present AVA rule and disabling an already disabled or absent rule are no-ops.

This only affects inbound TCP 445 traffic governed by Windows Firewall; it
does not stop a listener, disable SMB, or establish that any observed listener
is malicious. An observation is not a threat verdict.
