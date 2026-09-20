# AVA Windows System Repair Guide

This document contains a structured recovery procedure for Windows system files and startup problems. It is intentionally written as a procedural reference for WinRE and WinPE use, not as a destructive or invasive automation workflow.

## Scope

- Recovery environment: WinRE
- Offline recovery media: WinPE
- Objective: restore system integrity without unnecessary risk

## Phase 1 — capture facts and preserve evidence

1. Record the exact error symptom.
2. Capture the stop code and boot stage.
3. Note recent driver, patch, or upgrade activity.
4. Back up user data and logs when the system still starts.
5. Check BitLocker or secure boot constraints.

## Phase 2 — diagnose in WinRE

6. Boot to WinRE or recovery media.
7. Open Command Prompt from Advanced Options.
8. Validate partition and boot configuration.
9. Run `chkdsk /f /r` if filesystem damage is suspected.
10. Run `sfc /scannow /offbootdir=C:\ /offwindir=C:\Windows`.
11. Collect CBS logs if SFC finds irreparable files.
12. Use Event Viewer and Setup logs only as needed.

## Phase 3 — repair and verify

13. Run `DISM /Online /Cleanup-Image /RestoreHealth` when available.
14. Use an offline image source for recovery when the OS is unbootable.
15. Re-run SFC to validate restored system files.
16. Repair boot records and the BCD if needed.
17. Confirm the active partition and EFI assignments.
18. Use rollback or recovery options for recent bad updates.
19. Re-test service health and update state after booting.
20. Document final repair state and residual issues.

## Operational principles

- Prefer the least invasive fix first.
- Preserve logs and recovery evidence.
- Avoid destructive actions unless clearly required.
- Treat this as a triaged recovery guide rather than a blanket fix.
