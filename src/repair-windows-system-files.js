'use strict';

const REPAIR_WINDOWS_SYSTEM_FILES_REFERENCES = Object.freeze([
	Object.freeze({
		title: 'Microsoft WinRE / Windows Recovery Environment',
		url: 'https://learn.microsoft.com/windows-hardware/manufacture/desktop/windows-recovery-environment--winre--overview',
	}),
	Object.freeze({
		title: 'Microsoft WinPE overview',
		url: 'https://learn.microsoft.com/windows-hardware/manufacture/desktop/winpe-intro',
	}),
	Object.freeze({
		title: 'sfc /scannow and DISM guidance',
		url: 'https://support.microsoft.com/windows/using-system-file-checker-in-windows',
	}),
]);

const REPAIR_WINDOWS_SYSTEM_FILES_REPORT = `AVA Windows System Repair Guide

This guide is a structured recovery sequence for Windows system-file damage and boot problems. It is a procedural checklist, not a system-modifying script.

Scope
- Recovery environment: WinRE (Windows Recovery Environment)
- Recovery media: WinPE (Windows Preinstallation Environment)
- Goal: restore system integrity and verify bootability without unnecessary risk

Phase 1 — Gather facts and preserve evidence
1. Confirm the observed failure mode: boot loop, BSOD, startup repair loop, missing DLL, or damaged registry state.
2. Record the exact error text, stop code, boot stage, and whether the machine is UEFI or legacy BIOS.
3. Capture recent changes: driver updates, Windows patch rollups, antimalware events, or failed upgrades.
4. If the PC can start, back up user data, local logs, and any recovery or security artifacts before repair steps.
5. Document whether the system is using BitLocker, Secure Boot, or TPM-backed startup protections.

Phase 2 — Use WinRE diagnostics
6. Boot to WinRE from recovery media, automatic repair, or a Windows installation USB.
7. Open Troubleshoot > Advanced options > Command Prompt.
8. Verify the system partition and active boot configuration with diskpart and bcdedit.
9. Run chkdsk /f /r on the system volume if filesystem corruption is suspected.
10. Run sfc /scannow /offbootdir=C:\ /offwindir=C:\Windows to verify protected system files before deeper repair.
11. If SFC reports unrepairable files, collect the CBS logs and continue to DISM-based repair.
12. Inspect Event Viewer and Setup logs only as needed to narrow the cause of the corruption.

Phase 3 — Repair and restore integrity
13. Run DISM /Online /Cleanup-Image /RestoreHealth to repair the component store and Windows image.
14. If the machine cannot boot online, use DISM /Image:C:\ /Cleanup-Image /RestoreHealth /Source:wim:...\sources\install.wim:1 /LimitAccess.
15. Re-run sfc /scannow after repair to validate that protected system files are restored.
16. Repair boot files and boot configuration if startup still fails: bootrec /fixmbr, bootrec /fixboot, bootrec /scanos, bootrec /rebuildbcd.
17. Validate the BCD store, EFI entries, and partition assignments for the active OS before restarting.
18. If the issue follows a recent update or driver installation, use rollback or recovery options in WinRE to neutralize the offending change.
19. After the system boots, verify that Windows Update, drivers, and security tools are healthy before restoring broader system state.
20. Re-test startup, critical services, and user workload behavior; document the final repair state and any remaining anomalies.

Operational principles
- Prefer the least invasive repair path first: validate disk health, then protected files, then component store, then boot configuration.
- Keep command output and logs for diagnosis.
- Avoid broad destructive actions unless the problem clearly requires them.
- Treat this as a recovery procedure that is safe only when performed with the right environment and a clear understanding of the boot state.

References
- Microsoft WinRE overview
- Microsoft WinPE overview
- SFC and DISM guidance`;

function repairWindowsSystemFilesReport() {
	return REPAIR_WINDOWS_SYSTEM_FILES_REPORT;
}

function repairWindowsSystemFilesData() {
	return {
		category: 'windows-system-repair-guide',
		environment: {
			winRE: true,
			winPE: true,
		},
		phases: 3,
		steps: 20,
		references: REPAIR_WINDOWS_SYSTEM_FILES_REFERENCES.map((reference) => ({...reference})),
	};
}

module.exports = {
	repairWindowsSystemFilesReport,
	repairWindowsSystemFilesData,
	REPAIR_WINDOWS_SYSTEM_FILES_REPORT,
	REPAIR_WINDOWS_SYSTEM_FILES_REFERENCES,
};
