# PowerShell scripts

The repository contains 21 `.ps1` files under `scripts/` and `security/`.
These are standalone scripts; they are not dispatched through the Node.js
package. Read the source and use `Get-Help`/the script's parameters before
running one. `#requires` declarations apply only where present. Do not infer a
release or migration chain from filenames alone.

| Script | Purpose / cautions |
|---|---|
| `scripts/AVA_01610_SATELLITE_LAB.ps1` | Local simulation and optional report output; declares PowerShell 5.1. |
| `scripts/AVA_01610_SMB445_FIREWALL.ps1` | Audit/apply/disable modes for one inbound TCP 445 firewall rule; supports `ShouldProcess`, high confirmation impact; 5.1. |
| `scripts/AVA_DEVITO_01610_SAFE_AUDIT.ps1` | Local safe-audit report and transcript. |
| `scripts/AVA_SAFE_AUDIT_CHAT_MODE_v1.ps1` | Local safe-audit report; optional report opening. |
| `scripts/AVA_SPYWARE_RISK_AUDIT.ps1` | Local read-only spyware-risk report; 5.1. |
| `scripts/AVA_WLAN_TANGLE_SENSOR.ps1` | Local WLAN/LAN visibility and logging; requires administrator; task-management switches; 5.1. |
| `scripts/Ava314NextLayerAll.ps1` | Local defensive visibility, baseline/reporting, optional loop/task modes; requires administrator. |
| `scripts/Ava314SafeLocalNode.ps1` | Local snapshot, alerts, baseline, and HTML report generation; 5.1. |
| `scripts/AvaAutoStart.ps1` | Registers a repeating elevated scheduled task; review before use. |
| `scripts/AvaBaselineDrift.ps1` | Saves/compares local baselines and reports drift; optional loop. |
| `scripts/AvaCoreStack.ps1` | Local Defender/process/network visibility and reports; requires administrator. |
| `scripts/AvaSocPortalV4.ps1` | Reads local logs and builds a graph/HTML portal; requires administrator. |
| `scripts/AvaSocPortalV5.ps1` | V5-named local SOC portal with loop/task switches; source header also mentions V6; requires administrator; 5.1. |
| `scripts/AvaSocPortalV6.ps1` | Local graph, timeline, and report generation; optional loop; 5.1. |
| `scripts/AvaSocPortalV6Safe.ps1` | Safe V6 portal, local snapshot/baseline/reporting; 5.1. |
| `scripts/AvaSocPortalV7.ps1` | Local alert correlation, tagging, JSON/HTML export; optional imported alert-log path; 5.1. |
| `scripts/AvaSymbolicMemoryPortal.ps1` | Creates local JSON/CSV/HTML symbolic-memory files; 5.1. |
| `scripts/RUN_POLICY_TESTS.ps1` | Changes to repository root and runs the Python policy pytest file. |
| `scripts/SecurityGuardian.ps1` | Local administrative hardening/visibility; has task, firewall rollback, and remote-service switches; requires administrator. |
| `scripts/WandersmannMemoryCore.ps1` | Creates a local family-photo archive structure and memory portal. |
| `security/AVA_SECURITY_SAFE_LEVEL_1000.ps1` | Administrative audit/apply/rollback security workflow; supports `ShouldProcess`, high confirmation impact; 5.1. |

## Script versions and safety

V4, V5, V6, V6Safe, and V7 are separate script files, not a package-managed
version history. Names, headers, parameters, and safeguards differ; there is
no common upgrade or rollback procedure. Some scripts only read local state
and create reports, while others can create scheduled tasks, alter firewall
rules, or harden system settings. “Safe” or “read-only” in a filename/header
does not replace reviewing the implementation and running it with least
privilege.

PowerShell parsing/execution checks are in `test/scripts.test.js` and are
conditional on `pwsh` being available. Run the repository Node tests with
`npm test`; PowerShell-specific tests will be skipped if PowerShell is absent.
No PowerShell version-upgrade claim is made without a script-by-script
compatibility test.
