# AVA 01610 „Top 20 WinRE Diagnose + Reparatur“-Reihenfolge

Diese Anleitung fasst eine strukturierte, risikoarme Reihenfolge für Startprobleme zusammen, wenn das installierte Windows unter `C:\Windows` vorhanden ist, die aktuelle Eingabeaufforderung aber in **WinRE/WinPE auf `X:`** läuft.

**Legende:** 🟢 = lesen/diagnostizieren, 🟡 = verändert etwas gezielt, 🔴 = kann bei falscher Anwendung Schaden verursachen. Bei Startproblemen sollte zuerst nur 🟢 verwendet und Reparaturen gezielt eingesetzt werden.

---

## Phase 1: Umgebung & Partitionen identifizieren (🟢 Diagnose)

Ziel dieser Phase ist es, die aktuelle WinRE-Umgebung zu verstehen, Laufwerke zuzuordnen und sicherzustellen, dass wir das richtige Offline-System im Visier haben.

### 1. Umgebung überprüfen (🟢)
Zeigt die Version der aktuell laufenden Windows-/WinRE-Umgebung.
```cmd
ver
```

### 2. Systemlaufwerk abfragen (🟢)
Zeigt das Systemlaufwerk der aktuellen Umgebung; in WinRE ist das häufig `X:`.
```cmd
echo %SystemDrive%
```

### 3. Laufwerke auflisten (🟢)
Zeigt die aktuell erkannten Laufwerksbuchstaben.
```cmd
fsutil fsinfo drives
```

### 4. Partitionen & Volumes detailliert einsehen (🟢)
Öffnet DiskPart und listet Volumes, Laufwerksbuchstaben, Dateisysteme und Größen auf.
```cmd
diskpart
list volume
```

### 5. Dirty-Bit prüfen (🟢)
Prüft, ob das NTFS-Volume als „dirty“ markiert ist und eine Dateisystemprüfung benötigt.
```cmd
fsutil dirty query C:
```

### 6. Windows-Ordner verifizieren (🟢)
Prüft, ob die Windows-Installation auf `C:` vorhanden ist.
```cmd
dir C:\Windows
```

### 7. BitLocker-Status abfragen (🟢)
Zeigt den BitLocker-Zustand von `C:` an.
```cmd
manage-bde -status C:
```

---

## Phase 2: Tiefendiagnose & Log-Analyse (🟢 Diagnose)

Bevor wir etwas verändern, analysieren wir die Boot-Konfiguration und die Log-Dateien, um die Fehlerursache präzise einzugrenzen.

### 8. Boot-Konfiguration auslesen (🟢)
Zeigt die Boot Configuration Data (BCD) an. Prüfe besonders `device` und `osdevice` im Abschnitt „Windows Boot Loader“.
```cmd
bcdedit
```

### 9. Fehlende Windows-Installationen suchen (🟢)
Sucht nach Windows-Installationen, die momentan nicht im BCD registriert sind.
```cmd
bootrec /scanos
```

### 10. Offline-Starthilfe-Protokoll lesen (🟢)
Zeigt das Protokoll der automatischen Starthilfe direkt in CMD, falls vorhanden.
```cmd
type C:\Windows\System32\Logfiles\Srt\SrtTrail.txt
```

### 11. Fehlersuche im Protokoll (🟢)
Filtert die Starthilfe-Logdatei nach typischen Fehlerschlagworten.
```cmd
findstr /i "error failed fehler" C:\Windows\System32\Logfiles\Srt\SrtTrail.txt
```

### 12. Offline-Ereignisprotokoll abfragen (🟢)
Liest die letzten 20 Einträge direkt aus der Offline-`System.evtx` ohne das installierte Windows zu starten.
```cmd
wevtutil qe C:\Windows\System32\winevt\Logs\System.evtx /lf:true /c:20 /rd:true /f:text
```

### 13. Dateisystem zerstörungsfrei prüfen (🟢)
Prüft das Dateisystem von `C:` auf Fehler, ohne diese automatisch zu reparieren.
```cmd
chkdsk C:
```

### 14. Systemdateien verifizieren (🟢)
Prüft geschützte Windows-Dateien offline, ohne Reparaturen vorzunehmen.
```cmd
sfc /verifyonly /offbootdir=C:\ /offwindir=C:\Windows
```

### 15. Offline-Image-Status prüfen (🟢)
Prüft schnell, ob der Offline-Komponentenspeicher als beschädigt markiert ist.
```cmd
DISM /Image:C:\ /Cleanup-Image /CheckHealth
```

---

## Phase 3: Gezielte, schonende Reparatur (🟡 Gezielte Veränderung)

Erst wenn die Diagnose eine klare Richtung vorgibt, werden gezielte Reparaturmaßnahmen in dieser Reihenfolge eingeleitet.

### 16. Dateisystem reparieren (🟡)
Behebt gefundene logische Dateisystemfehler auf `C:`.
```cmd
chkdsk C: /f
```

### 17. Systemdateien reparieren (🟡)
Prüft und repariert geschützte Windows-Systemdateien deiner Installation offline.
```cmd
sfc /scannow /offbootdir=C:\ /offwindir=C:\Windows
```

### 18. Komponentenspeicher reparieren (🟡)
Versucht Beschädigungen im Windows-Komponentenspeicher der Offline-Installation zu reparieren.
```cmd
DISM /Image:C:\ /Cleanup-Image /RestoreHealth
```

### 19. Boot-Dateien neu schreiben (🟡)
Kopiert Bootdateien auf die Systempartition und repariert die Startumgebung.
```cmd
bcdboot C:\Windows
```

### 20. Kontrollierter Neustart (🟡)
Startet den Rechner aus WinRE/WinPE neu.
```cmd
wpeutil reboot
```

---

## Nicht als erster Reparaturschritt ausführen

```cmd
icacls C:\Windows /reset /T
```

Ebenso nicht pauschal mit `/grant` oder `/setowner` arbeiten, solange das Problem bei der Boot-Konfiguration oder beschädigten Systemdateien liegt.

## Quellen

1. [Windows commands | Microsoft Learn](https://learn.microsoft.com/de-de/windows-server/administration/windows-commands/windows-commands?utm_source=chatgpt.com)
2. [Windows-Startprobleme beheben - Windows Client | Microsoft Learn](https://learn.microsoft.com/de-de/troubleshoot/windows-client/performance/windows-boot-issues-troubleshooting?utm_source=chatgpt.com)
3. [bcdboot | Microsoft Learn](https://learn.microsoft.com/de-de/windows-server/administration/windows-commands/bcdboot?utm_source=chatgpt.com)
4. [REAgentC-Befehlszeilenoptionen | Microsoft Learn](https://learn.microsoft.com/de-de/windows-hardware/manufacture/desktop/reagentc-command-line-options?view=windows-11&utm_source=chatgpt.com)
5. [chkdsk | Microsoft Learn](https://learn.microsoft.com/de-de/windows-server/administration/windows-commands/chkdsk?utm_source=chatgpt.com)
6. [dir | Microsoft Learn](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/dir?utm_source=chatgpt.com)
7. [Robocopy | Microsoft Learn](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/robocopy?utm_source=chatgpt.com)
8. [manage-bde | Microsoft Learn](https://learn.microsoft.com/de-de/windows-server/administration/windows-commands/manage-bde?utm_source=chatgpt.com)

