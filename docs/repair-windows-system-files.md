# Windows-Systemdateien aus WinRE/WinPE reparieren

Diese Anleitung fasst eine vorsichtige Reihenfolge für Startprobleme zusammen,
wenn das installierte Windows unter `C:\Windows` vorhanden ist, die aktuelle
Eingabeaufforderung aber in **WinRE/WinPE auf `X:`** läuft.

## 1. Normal neu starten

```cmd
wpeutil reboot
```

`wpeutil reboot` ist für den Neustart der laufenden Windows-PE-Sitzung
vorgesehen.

## 2. Boot-Eintrag prüfen

Falls danach wieder die Starthilfe erscheint, in der Eingabeaufforderung:

```cmd
bcdedit
```

Im Abschnitt **Windows Boot Loader** sollte `osdevice` auf `partition=C:`
zeigen, bevor Reparaturbefehle gegen `C:\Windows` ausgeführt werden.

## 3. Systemdateien offline reparieren

Wenn `osdevice` auf `C:` zeigt:

```cmd
sfc /scannow /offbootdir=C:\ /offwindir=C:\Windows
```

## 4. Offline-DISM verwenden, wenn SFC nicht ausreicht

```cmd
DISM /Image:C:\ /Cleanup-Image /RestoreHealth
```

Falls DISM meldet, dass Quelldateien nicht gefunden wurden, sollte zuerst die
genaue Fehlermeldung festgehalten werden, statt weitere Rechte- oder
Eigentümeränderungen zu improvisieren.

## 5. Erneut neu starten

```cmd
wpeutil reboot
```

## Alternative ohne weitere CMD-Befehle

```cmd
exit
```

Danach in **Problembehandlung -> Erweiterte Optionen -> Starthilfe** wechseln.

## Nicht als erster Reparaturschritt ausführen

```cmd
icacls C:\Windows /reset /T
```

Ebenso nicht pauschal mit `/grant` oder `/setowner` arbeiten, solange das
Problem bei der Boot-Konfiguration oder beschädigten Systemdateien liegt.

## Quellen

1. [Wpeutil-Befehlszeilenoptionen | Microsoft Learn](https://learn.microsoft.com/de-de/windows-hardware/manufacture/desktop/wpeutil-command-line-options?view=windows-11)
2. [Use WinRE to troubleshoot startup issues | Microsoft Learn](https://learn.microsoft.com/en-us/troubleshoot/windows-server/performance/use-winre-to-troubleshoot-startup-issue)
3. [sfc | Microsoft Learn](https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/sfc)
4. [Startup Repair | Microsoft Support](https://support.microsoft.com/en-us/windows/experience/startup-boot/startup-repair)
