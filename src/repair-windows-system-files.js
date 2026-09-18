'use strict';

const REPAIR_WINDOWS_SYSTEM_FILES_REFERENCES = Object.freeze([
	Object.freeze({
		title: 'Wpeutil command-line options | Microsoft Learn',
		url: 'https://learn.microsoft.com/de-de/windows-hardware/manufacture/desktop/wpeutil-command-line-options?view=windows-11',
	}),
	Object.freeze({
		title: 'Use WinRE to troubleshoot startup issues | Microsoft Learn',
		url: 'https://learn.microsoft.com/en-us/troubleshoot/windows-server/performance/use-winre-to-troubleshoot-startup-issue',
	}),
	Object.freeze({
		title: 'sfc | Microsoft Learn',
		url: 'https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/sfc',
	}),
	Object.freeze({
		title: 'Startup Repair | Microsoft Support',
		url: 'https://support.microsoft.com/en-us/windows/experience/startup-boot/startup-repair',
	}),
]);

const REPAIR_WINDOWS_SYSTEM_FILES_REPORT = `Windows-Systemdateien aus WinRE/WinPE reparieren

Ausgangslage:
- C:\\Windows ist vorhanden, aber die aktuelle Eingabeaufforderung läuft in WinRE/WinPE auf X:.
- Das installierte Windows wird nicht direkt mit explorer.exe aus dieser Sitzung gestartet.
- Der Rückweg führt über den Windows-Bootmanager und die Offline-Reparaturwerkzeuge.

Reihenfolge:
1. Normal neu starten:
   wpeutil reboot

2. Falls erneut die Starthilfe erscheint, in der CMD prüfen:
   bcdedit

   Im Abschnitt „Windows Boot Loader“ soll bei osdevice partition=C: stehen.

3. Wenn osdevice auf C: zeigt, Systemdateien offline prüfen und reparieren:
   sfc /scannow /offbootdir=C:\\ /offwindir=C:\\Windows

4. Wenn SFC nicht alles reparieren kann:
   DISM /Image:C:\\ /Cleanup-Image /RestoreHealth

5. Danach erneut neu starten:
   wpeutil reboot

Alternative ohne CMD:
- exit
- Dann Problembehandlung -> Erweiterte Optionen -> Starthilfe

Wichtig:
- Kein icacls C:\\Windows /reset /T
- Kein /grant
- Kein /setowner
- Wenn DISM meldet, dass Quelldateien nicht gefunden wurden, zuerst die genaue Ausgabe sichern und dann gezielt weiterarbeiten.

Quellen:
- docs/repair-windows-system-files.md`;

function repairWindowsSystemFilesReport() {
	return REPAIR_WINDOWS_SYSTEM_FILES_REPORT;
}

function repairWindowsSystemFilesData() {
	return {
		environment: 'Windows Recovery Environment (WinRE/WinPE)',
		bootCheck: 'bcdedit -> Windows Boot Loader -> osdevice should point to partition=C:',
		commands: [
			'wpeutil reboot',
			'bcdedit',
			'sfc /scannow /offbootdir=C:\\ /offwindir=C:\\Windows',
			'DISM /Image:C:\\ /Cleanup-Image /RestoreHealth',
			'exit',
		],
		references: REPAIR_WINDOWS_SYSTEM_FILES_REFERENCES.map((reference) => ({...reference})),
	};
}

module.exports = {
	repairWindowsSystemFilesReport,
	repairWindowsSystemFilesData,
	REPAIR_WINDOWS_SYSTEM_FILES_REPORT,
	REPAIR_WINDOWS_SYSTEM_FILES_REFERENCES,
};
