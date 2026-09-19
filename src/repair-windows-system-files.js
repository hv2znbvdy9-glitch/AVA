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

const REPAIR_WINDOWS_SYSTEM_FILES_REPORT = `AVA 01610 „Top 20 WinRE Diagnose + Reparatur“-Reihenfolge (Windows-Systemdateien aus WinRE/WinPE reparieren)

Phase 1: Umgebung & Partitionen identifizieren (🟢 Diagnose)
Ziel dieser Phase ist es, die aktuelle WinRE-Umgebung zu verstehen, Laufwerke zuzuordnen und sicherzustellen, dass wir das richtige Offline-System im Visier haben.

1. Umgebung überprüfen:
   ver

2. Systemlaufwerk abfragen:
   echo %SystemDrive%

3. Laufwerke auflisten:
   fsutil fsinfo drives

4. Partitionen & Volumes detailliert einsehen:
   diskpart
   list volume

5. Dirty-Bit prüfen:
   fsutil dirty query C:

6. Windows-Ordner verifizieren:
   dir C:\\Windows

7. BitLocker-Status abfragen:
   manage-bde -status C:

Phase 2: Tiefendiagnose & Log-Analyse (🟢 Diagnose)
Bevor wir etwas verändern, analysieren wir die Boot-Konfiguration und die Log-Dateien, um die Fehlerursache präzise einzugrenzen.

8. Boot-Konfiguration auslesen:
   bcdedit

9. Fehlende Windows-Installationen suchen:
   bootrec /scanos

10. Offline-Starthilfe-Protokoll lesen:
    type C:\\Windows\\System32\\Logfiles\\Srt\\SrtTrail.txt

11. Fehlersuche im Protokoll:
    findstr /i "error failed fehler" C:\\Windows\\System32\\Logfiles\\Srt\\SrtTrail.txt

12. Offline-Ereignisprotokoll abfragen:
    wevtutil qe C:\\Windows\\System32\\winevt\\Logs\\System.evtx /lf:true /c:20 /rd:true /f:text

13. Dateisystem zerstörungsfrei prüfen:
    chkdsk C:

14. Systemdateien verifizieren:
    sfc /verifyonly /offbootdir=C:\\ /offwindir=C:\\Windows

15. Offline-Image-Status prüfen:
    DISM /Image:C:\\ /Cleanup-Image /CheckHealth

Phase 3: Gezielte, schonende Reparatur (🟡 Gezielte Veränderung)
Erst wenn die Diagnose eine klare Richtung vorgibt, werden gezielte Reparaturmaßnahmen in dieser Reihenfolge eingeleitet.

16. Dateisystem reparieren:
    chkdsk C: /f

17. Systemdateien reparieren:
    sfc /scannow /offbootdir=C:\\ /offwindir=C:\\Windows

18. Komponentenspeicher reparieren:
    DISM /Image:C:\\ /Cleanup-Image /RestoreHealth

19. Boot-Dateien neu schreiben:
    bcdboot C:\\Windows

20. Kontrollierter Neustart:
    wpeutil reboot

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
			'ver',
			'echo %SystemDrive%',
			'fsutil fsinfo drives',
			'diskpart',
			'list volume',
			'fsutil dirty query C:',
			'dir C:\\Windows',
			'manage-bde -status C:',
			'bcdedit',
			'bootrec /scanos',
			'type C:\\Windows\\System32\\Logfiles\\Srt\\SrtTrail.txt',
			'findstr /i "error failed fehler" C:\\Windows\\System32\\Logfiles\\Srt\\SrtTrail.txt',
			'wevtutil qe C:\\Windows\\System32\\winevt\\Logs\\System.evtx /lf:true /c:20 /rd:true /f:text',
			'chkdsk C:',
			'sfc /verifyonly /offbootdir=C:\\ /offwindir=C:\\Windows',
			'DISM /Image:C:\\ /Cleanup-Image /CheckHealth',
			'chkdsk C: /f',
			'sfc /scannow /offbootdir=C:\\ /offwindir=C:\\Windows',
			'DISM /Image:C:\\ /Cleanup-Image /RestoreHealth',
			'bcdboot C:\\Windows',
			'wpeutil reboot',
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
