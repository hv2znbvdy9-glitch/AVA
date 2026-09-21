# AVA Safe Start

AVA-Modus: Fakten vor Angst. Kopf klar. Original sichern. Technik und Symbolik bewusst trennen.

## Status

Diese Datei beschreibt den sicheren lokalen Start fuer AVA-Tools. Sie ist Dokumentation, kein Ausfuehrungsskript.

## Grundregeln

```text
Fremde Systeme: NEIN
Gegenangriffe: NEIN
Nur eigener Windows-PC / autorisierte Systeme: JA
Lokale defensive Pruefung: JA
Rollback: bereit
START_03 / AutoDefense: nicht blind
Gemischte Dateien 1:1 ausfuehren: STOP
```

## Dateien sauber trennen

```text
AVA_ADMIN_CHECK.ps1          = nur PowerShell-Code
START_AVA_ADMIN_CHECK.cmd    = nur Start-Wrapper
ava_admin_policy.json        = nur JSON-Regeln
SAFE_START.md                = nur Dokumentation
commands_safe_reference.md   = nur Befehlsnotizen
```

Wenn PowerShell-Code, JSON, Hashes, Befehle und Notizen in einer Datei gemischt sind: **STOP**. Erst trennen, lesen, Hash pruefen.

## Erster sicherer Pruefschritt

```powershell
cd "$env:USERPROFILE\Desktop\AVA_v4_PORTAL_SAFE_STARTPAKET_TESTED_FIXED"

Get-FileHash -LiteralPath ".\AVA_ADMIN_CHECK.ps1" -Algorithm SHA256
Get-FileHash -LiteralPath ".\START_AVA_ADMIN_CHECK.cmd" -Algorithm SHA256

notepad ".\AVA_ADMIN_CHECK.ps1"
notepad ".\START_AVA_ADMIN_CHECK.cmd"
```

Dieser Schritt fuehrt kein `.ps1` aus. Er wechselt nur in den Ordner, berechnet Hashes und oeffnet Dateien in Notepad.

## Start-Reihenfolge

1. Hash pruefen.
2. Datei mit Notepad lesen.
3. Pruefen, ob am Ende keine losen JSON-, Text- oder Befehlsbloecke in der `.ps1` stehen.
4. `START_01_RUNONCE_ADMIN.cmd` nur lokal ausfuehren.
5. Report pruefen.
6. `START_02_LIVE_PREVIEW_ADMIN.cmd` nur als Preview verwenden.
7. `START_03_LIVE_AUTODEFENSE_MIT_BESTAETIGUNG_ADMIN.cmd` nicht blind starten.
8. `START_04_ROLLBACK_BLOCKS_ADMIN.cmd` nur gezielt fuer eigene `AVA_v4_Block_*` Firewall-Regeln verwenden.

## Hash-Regel

```text
Hash passt exakt: OK zum Lesen / Pruefen
Hash passt nicht: STOP
Signatur leer oder ungueltig: nicht automatisch schlimm, aber bewusst pruefen
Blind ausfuehren: STOP
Ueberall ausfuehren: STOP
Nur eigener Windows-PC / autorisierte Systeme: OK
```

## Rollback-Regel

Firewall-Rollback nur anzeigen und dann gezielt fuer eigene AVA-Regeln entfernen:

```powershell
Get-NetFirewallRule -DisplayName "AVA_v4_Block_*" -ErrorAction SilentlyContinue |
Select-Object DisplayName, Enabled, Direction, Action
```

Nur wenn diese Regeln wirklich entfernt werden sollen:

```powershell
Get-NetFirewallRule -DisplayName "AVA_v4_Block_*" -ErrorAction SilentlyContinue |
Remove-NetFirewallRule
```

## Privacy-Regel

Private Identitaets- und Standortdaten nicht in oeffentliche Reports oder Repos schreiben. In oeffentlichen Dateien keine lokalen Benutzernamen, Adressen oder privaten Rechnerdetails veroeffentlichen.

## Kernsatz

Realitaet vor Interpretation. Messbarkeit vor Gefuehl. Code vor Symbolik. Schutzregeln stehen ueber Vollzugriff.
