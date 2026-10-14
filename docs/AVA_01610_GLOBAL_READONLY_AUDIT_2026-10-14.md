# AVA / AVO / DEVITO — Globaler Read-only-Auditstand

**Prüfdatum:** 2026-10-14  
**Ziel:** Bestand sichtbar machen, aktuelle Befunde dokumentieren und Änderungen nur nachvollziehbar auf einem Branch vorbereiten.  
**Prüfprinzip:** Beobachten → Evidenz sichern → statisch analysieren → testen → Nachweis.

## 1. Prüfgrenzen

Die sechs erreichbaren GitHub-Repositories wurden über die GitHub-API mit ihrem Standardbranch und einem rekursiven Git-Baum abgeglichen. Die Dateipfade des zurückgegebenen Baums waren bei allen sechs Abfragen vollständig (keine Trunkierung). Zusätzlich wurden ausgewählte Python-Module, PowerShell-Skripte, Tests und Workflows als Text gelesen.

**Das ist noch kein vollständiger inhaltlicher Review jeder einzelnen Datei.** Bei großen Repositories — insbesondere AVA-007 mit über tausend Dateien — sind sämtliche Pfade inventarisiert, aber noch nicht alle Quelltexte gelesen. Es wurden keine PowerShell-Skripte, Python-Programme, Deployments oder Aktionen auf realen Maschinen ausgeführt. Laufzeitverhalten, lokale Logs und der tatsächliche Zustand externer Windows-/Linux-Server wurden nicht erhoben.

## 2. Repo-Inventar zum Prüfzeitpunkt

Dateizahlen stammen aus dem rekursiven Git-Baum auf `main`; Kategorien zählen Dateiendungen bzw. Pfadpräfixe. Es handelt sich um Repository-Dateien, **nicht um die Zahl realer Server**.

| Repository | Sichtbarkeit | Git-Baum / HEAD auf `main` | Dateien | `.py` | `.ps1` | Workflows |
|---|---|---|---:|---:|---:|---:|
| [hv2znbvdy9-glitch/AVA](https://github.com/hv2znbvdy9-glitch/AVA) | öffentlich | `5783f0600e2d2450f47fddf0cf7c337c5bc4b87b` | 103 | 6 | 21 | 7 |
| [hv2znbvdy9-glitch/AVA-007](https://github.com/hv2znbvdy9-glitch/AVA-007) | öffentlich | `6d293b38d1aaea9924b3bc8326f85388f362747e` | 1.050 | 6 | 10 | 4 |
| [hv2znbvdy9-glitch/DEVITO](https://github.com/hv2znbvdy9-glitch/DEVITO) | öffentlich | `6c86dc83122952c45375adb20a7c69162044a879` | 114 | 42 | 30 | 8 |
| [hv2znbvdy9-glitch/Danny](https://github.com/hv2znbvdy9-glitch/Danny) | privat | `11ff3ad51f40e3e0042714b471648dff64c74961` | 27 | 6 | 2 | 1 |
| [hv2znbvdy9-glitch/DE.VI.TO](https://github.com/hv2znbvdy9-glitch/DE.VI.TO) | privat | `0e163d3caca7b0a4e75b8760e29000fcfbdb23fc` | 1 | 0 | 0 | 0 |
| [69-007/AVA](https://github.com/69-007/AVA) | privat | `1f6a924f661b37e639843b4860e06d219b73208f` | 231 | 114 | 19 | 3 |
| **Summe** |  |  | **1.526** | **174** | **82** | **23** |

## 3. Befunde mit hoher Priorität

### F-01 — WLAN-Tangle-Skripte sind nicht vollständig system-read-only

Geprüfte Pfade:
- [AVA: `scripts/AVA_WLAN_TANGLE_SENSOR.ps1`](https://github.com/hv2znbvdy9-glitch/AVA/blob/main/scripts/AVA_WLAN_TANGLE_SENSOR.ps1), Git-Blob-SHA `d9a37bd44752541f766eaf7dc31ad1f5064be2c4`
- [DEVITO: `scripts/AVA_WLAN_TANGLE_SENSOR.ps1`](https://github.com/hv2znbvdy9-glitch/DEVITO/blob/main/scripts/AVA_WLAN_TANGLE_SENSOR.ps1), Git-Blob-SHA `5b95e63a60692405c7a2769af17e55c6e54ccc32`

Beide Skripte erheben lokale WLAN-/Adapter-/Nachbarinformationen. Sie schreiben jedoch Ereignisprotokolle, JSONL-Tangle-Daten, Zustands-/Snapshot-Dateien und HTML-Berichte. Die DEVITO-Fassung enthält außerdem Task-Installations- und -Entfernungspfade; die Installation registriert eine geplante Aufgabe unter `SYSTEM` mit höchster Stufe. Die AVA-Fassung schreibt bei der Initialisierung auch die Admin-Policy-JSON und verwaltet ebenfalls eine Aufgabe.

**Bewertung:** Das kann ein legitimer lokaler Beobachter sein, ist aber nicht „keine Systemänderungen“. Für sichere Betriebsmodi trennen: `InspectOnly` (keine Schreibzugriffe, keine Task-Änderung), `RunOnce` (explizite, protokollierte Report-Schreibvorgänge) und `Install/RemoveTask` (separater expliziter Administrationspfad). Der Standardaufruf darf keine stillschweigende Installation oder Erhöhung auslösen.

Die Tangle-Funktion berechnet SHA-256 über einen Ereignisdatensatz und verlinkt den vorherigen Hash. Im überprüften Sensorquelltext wurde keine vollständige Verifikationsroutine für die gesamte vorhandene Kette gefunden. Ein Hash im beschreibbaren Log plus beschreibbarer Zustand ist **kein manipulationssicheres oder extern verankertes Beweismittel**.

### F-02 — Firewall-Skript hat ausdrücklich verändernde Modi

Geprüfter Pfad: [AVA: `scripts/AVA_01610_SMB445_FIREWALL.ps1`](https://github.com/hv2znbvdy9-glitch/AVA/blob/main/scripts/AVA_01610_SMB445_FIREWALL.ps1), Git-Blob-SHA `c471aef20f525f6a061e22795d2d40c4a4ae22e8`.

Das Skript bietet `Audit`, `Apply` und `Disable`. `Apply` kann eine eingehende TCP/445-Blockregel erstellen; `Disable` kann diese Regel deaktivieren. `SupportsShouldProcess` und hoher ConfirmImpact sind positive Schutzmaßnahmen, ersetzen aber nicht die Modustrennung und Tests. Nur `Audit` ist als Beobachtungsmodus ohne Firewalländerung gedacht. Ein TCP/445-Listener allein beweist keinen Angriff.

### F-03 — Monitor-Workflow enthält Konfigurationsfehler

Geprüfter Pfad: [AVA: `.github/workflows/monitor-runs-01610-1.yml`](https://github.com/hv2znbvdy9-glitch/AVA/blob/main/.github/workflows/monitor-runs-01610-1.yml), ursprünglicher Git-Blob-SHA `8c728bdd521cf73ed21242be2bd1876ba49a9a03`.

Im Stand vor der Korrektur:
1. `cron: '* * * * *'` fordert minütliche Ausführung an; GitHub Actions unterstützt für `schedule` als kürzestes Intervall fünf Minuten. Siehe [GitHub Events: schedule](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows).
2. `timeout-minutes: 2880` verspricht 48 Stunden, obwohl GitHub-gehostete Jobs höchstens 360 Minuten laufen können. Siehe [GitHub Workflow-Syntax](https://docs.github.com/en/actions/reference/workflows-and-actions/workflow-syntax).
3. Der zweite Abruf setzt den Output `ava_run`, spätere Schritte lesen aber `ava_status`; der Status kann daher leer sein.
4. Der Workflow versucht, einen Issue-Kommentar zu erstellen, obwohl er das benötigte Schreibrecht nicht explizit deklariert, und verschluckt den Fehler mit `|| true`. Das passt nicht zu einem reinen Read-only-Monitor.

Die vorgeschlagene Branch-Aktualisierung stellt auf fünf Minuten und einen kurzen Job-Timeout um, korrigiert den Statusfluss und gibt Ergebnisse in der Run-Zusammenfassung aus statt Issue-Kommentare zu schreiben.

### F-04 — Der statische PowerShell-Parser erzwingt Parse-Fehler nicht

Geprüfter Pfad: [DEVITO: `.github/workflows/ava-safe-audit-one-script.yml`](https://github.com/hv2znbvdy9-glitch/DEVITO/blob/main/.github/workflows/ava-safe-audit-one-script.yml), Git-Blob-SHA `853e499643b64734eba00af734325c0c480c7421`.

Die Schleife über PowerShell-Dateien sammelt und publiziert Parse-Fehler. In diesem Schritt wird nach dem Bericht aber kein Fehler ausgelöst, wenn `$Failures.Count` größer als null ist. Dadurch können Syntaxfehler gemeldet werden, ohne diesen Parser-Schritt zwingend fehlschlagen zu lassen. Korrekturvorschlag: nach dem Summary-Bericht bei Parse-Fehlern `throw` bzw. einen Exit-Code ungleich null setzen; danach erst den isolierten Einzel-Skript-Test starten.

### F-05 — Python-Engine darf Kommandos ausführen; Denylist ist keine Sicherheitsgrenze

Geprüfte Pfade:
- [DEVITO: `ava/core/engine.py`](https://github.com/hv2znbvdy9-glitch/DEVITO/blob/main/ava/core/engine.py), Git-Blob-SHA `751a79682bb2c65618b0d9814ab2534b78c05049`
- [DEVITO: `ava/policy.py`](https://github.com/hv2znbvdy9-glitch/DEVITO/blob/main/ava/policy.py), Git-Blob-SHA `1b80ae9726a3d0481fccbaeb22dfba0ecb28901c`
- [DEVITO: `ava/monitoring/real_state.py`](https://github.com/hv2znbvdy9-glitch/DEVITO/blob/main/ava/monitoring/real_state.py), Git-Blob-SHA `1bfd6ad5f6d79677cd7c0a0589ff3386f2d7cdb5`

Die Engine enthält eine Befehlsausführung. Die derzeitige Prüfung auf ausgewählte gefährliche Teilzeichenfolgen und `shlex.split` ist keine vollständige Sicherheitsgrenze gegen missbräuchliche Kommandos. Vor Freigabe sind Vertrauensgrenzen, erlaubte ausführbare Programme/Argumente, Shell-Verzicht, Timeout, Prozessabbruch, Ausgabebegrenzung und Fehlerzustände festzulegen. Bevorzugt wird eine explizite Allowlist von Programmen und Argumenten anstelle einer Blacklist.

Das Zustandsmonitoring nutzt Heuristiken: fremde IP-Adressen werden als „WATCH“ eingestuft, sofern sie nicht in einer kurzen Liste stehen; ausführbare Pfade mit „temp“ werden auffällig. Diese Regeln erzeugen mögliche Fehlalarme und sind keine belastbare Angriffsbestätigung.

### F-06 — Repository-Bestand und Komponentenidentität müssen getrennt bleiben

- `AVA-007` hat 1.050 Dateien; der `package.json`-Eintrag beschreibt AVA Test Runner 7.0.0. Ein großer Teil des Baums besteht aus Upstream-Code, Testdateien und Fixtures; dies ist nicht mit 1.050 AVA-Servern gleichzusetzen. Python-/PowerShell-Sicherheitszusätze müssen getrennt von der Node.js-Hauptpipeline geprüft werden.
- `DEVITO` enthält in seinem Git-Baum ungewöhnlich benannte Top-Level-Pfade wie `Dict[str`, `None` und `Optional[Dict[str`; außerdem sind Cache-Dateien unter `.lsp/.cache` und `.clj-kondo/.cache` eingecheckt. Erst auf Herkunft prüfen, dann ggf. auf einem separaten Branch bereinigen.
- `Danny` enthält privilegierte Windows-Startskripte, darunter einen Modus mit „LIVE_AUTODEFENSE“ und einen separaten Rollback-Pfad. Diese sind vor tatsächlicher Ausführung statisch zu prüfen; keine Ausführung wurde vorgenommen.
- `69-007/AVA` hat die breiteste Sicherheits-/Deployment-Oberfläche (Security-Orchestrierung, API/gRPC, Cloud-Provider, systemd, Docker/Kubernetes, Firewall-/Setup-Skripte). Diese Bereiche benötigen isolierte Tests und explizite Autorisierung vor jeder realen Aktion.
- `DE.VI.TO` enthält auf `main` nur eine `README.md`; daraus kann kein ausführbares System oder Serverzustand abgeleitet werden.

## 4. Aktuell sichtbare GitHub-Run-Evidenz

Statuswerte hier sind Metadaten der jeweiligen Run-Seite; ein grüner Run ist nur ein Nachweis für den Workflow und Commit, auf dem er lief.

| Repository / Run | Status am geprüften Stand | Aussagekraft |
|---|---|---|
| [AVA-007 Run 37056290532](https://github.com/hv2znbvdy9-glitch/AVA-007/actions/runs/37056290532), HEAD `6d293b38…` | **failure** | Aktueller Hauptbranch-Head; die Install-/Test-Pipeline ist nicht grün. |
| [DEVITO Lindblad Check 38458673749](https://github.com/hv2znbvdy9-glitch/DEVITO/actions/runs/38458673749), HEAD `6c86dc83…` | **success** | Enger Lindblad-/Qubit-Test, kein Gesamtnachweis für alle Python- und PowerShell-Module. |
| [69-007/AVA Tests 37837416840](https://github.com/69-007/AVA/actions/runs/37837416840), HEAD `1f6a924f…` | **failure** | Haupttests fehlgeschlagen. |
| [69-007/AVA Python Smoke CI 37837416846](https://github.com/69-007/AVA/actions/runs/37837416846), HEAD `1f6a924f…` | **failure** | Smoke-Pipeline fehlgeschlagen. |
| [69-007/AVA Code Quality 37837416894](https://github.com/69-007/AVA/actions/runs/37837416894), HEAD `1f6a924f…` | **success** | Code-Quality-Workflow bestanden; nicht gleichbedeutend mit Tests bestanden. |
| [Danny Run All Safe Checks 31666658583](https://github.com/hv2znbvdy9-glitch/Danny/actions/runs/31666658583) | **success** | Älterer, sichtbarer Run; kein Beweis für alle späteren Änderungen oder reale Maschine. |
| [AVA letzte sichtbare Actions](https://github.com/hv2znbvdy9-glitch/AVA/actions), main HEAD `5783f060…` | **kein aktueller Code-Testnachweis in der eingesehenen letzten Zehnerliste** | Die sichtbaren jüngsten Einträge sind überwiegend Copilot-Agent-/Code-Review-Runs auf anderen SHAs. |
| [DE.VI.TO Actions](https://github.com/hv2znbvdy9-glitch/DE.VI.TO/actions) | keine Runs gelistet | Es gibt im Hauptbranch keinen Workflow. |

## 5. Nächste kontrollierte Schritte

1. Den Monitor-Workflow-Fix und diesen Bericht im Audit-Branch prüfen.
2. Pull Request prüfen lassen; nichts direkt auf `main` mergen.
3. Parser-Enforcement und getrennte Read-only-/Write-/Task-Modi in eigenen Branches vorbereiten.
4. Tests gezielt mit Fixture-Daten ausführen; zuerst Python-Einheitstests und PowerShell-AST-Parser, keine Firewall-, Task- oder Autodefense-Aktion.
5. Jeden tatsächlichen Run, seine Commit-SHA, Job-Ergebnisse, Logs und Artefakte dokumentieren.
6. Vollständige Quelltextprüfung für den Rest der 1.526 Pfade fortsetzen; der jetzige Bericht ist ein Inventar plus risikobasierter Teil-Audit, kein behaupteter Vollreview jeder Datei.

## 6. Integritäts- und Änderungsnachweis

- Inventarisierung verwendet die aktuellen `main`-Heads aus der GitHub-API; die oben stehenden 40-stelligen Werte sind Git-Commit-SHAs.
- Wo Datei-SHAs genannt werden, sind es **Git-Blob-SHAs** aus der Contents-API, nicht separat berechnete SHA-256-Prüfsummen.
- Keine reale Maschine wurde abgefragt oder verändert; keine Firewall-Regel, Aufgabe oder Sicherheitssoftware wurde gestartet/angepasst.
- Die Audit-Dokumentation und der Monitor-Fix werden auf einem separaten Branch vorgeschlagen. Ein PR wird nicht automatisch mit `main` zusammengeführt.


## 7. Nachträgliche Prüfung der fehlgeschlagenen Jobs

Die Job-Listen und dekodierten Logs der bereits vorhandenen Fehlerläufe wurden nach dem ersten Bericht ergänzend gelesen:

- **AVA-007, Run [37056290532](https://github.com/hv2znbvdy9-glitch/AVA-007/actions/runs/37056290532):** fehlgeschlagen waren unter anderem Linux-Matrixjobs für Node 20.19, 22.20, 24.12 und 25 sowie der Job „Install dependencies without using a lockfile“; mehrere Windows-/macOS-Matrixjobs waren erfolgreich. In den Linux-Logs sind Snapshot-Abweichungen bei `test-tap/reporters/default.failfast2.v20.log` und `default.edgecases.v20.log` sichtbar; darunter weichen erfasste Terminalausgaben/Fehlermeldungen von den erwarteten Report-Fixtures ab. Dies grenzt die nächste Diagnose auf Report-/Snapshot-Kompatibilität ein, beweist aber noch nicht die endgültige Ursache. Es wurde kein Retry ausgelöst.
- **69-007/AVA, Tests-Run [37837416840](https://github.com/69-007/AVA/actions/runs/37837416840):** die Python-Matrixjobs 3.8, 3.9, 3.10, 3.11 und 3.12 scheiterten. Die Logs belegen einen gemeinsamen Test-Collection-Fehler: `tests/test_wellbeing.py` versucht `threat_log` aus `ava.security` zu importieren; das Symbol kann nicht importiert werden. In derselben Pipeline meldet mypy 146 Fehler über 37 Dateien. Der fehlende `coverage.xml`-Report ist Folge des abgebrochenen pytest-Laufs, nicht automatisch ein eigener Root Cause.
- **69-007/AVA, Python Smoke CI [37837416846](https://github.com/69-007/AVA/actions/runs/37837416846):** auch hier scheitern die Python-Matrixjobs an der Test-Collection mit demselben `threat_log`-Importfehler.
- **DEVITO, Run [38458673749](https://github.com/hv2znbvdy9-glitch/DEVITO/actions/runs/38458673749):** die beiden ausgewiesenen fokussierten Lindblad-Tests auf Python 3.10 und 3.12 sind erfolgreich. Das bestätigt nur diesen fokussierten Experimentpfad, nicht den gesamten DEVITO-Testbestand.
- **Danny:** Run [38083813956](https://github.com/hv2znbvdy9-glitch/Danny/actions/runs/38083813956) ist ein fehlgeschlagener Copilot-Agent-Job und kein regulärer Produkt-Testlauf. Der sichtbare `Run All Safe Checks` [31666658583](https://github.com/hv2znbvdy9-glitch/Danny/actions/runs/31666658583) war erfolgreich, ist aber ein älterer Auditlauf.

**Nächste konkrete Fehlerbehebung:** In 69-007/AVA zuerst die vorgesehene Herkunft und API von `threat_log` klären, dann den Importvertrag mit einem gezielten Test absichern; anschließend mypy-Probleme in getrennten Modulen priorisieren. In AVA-007 zuerst den Diff der Reporter-Snapshots auf den Linux-Node-Matrixjobs untersuchen und nicht die absichtlich fehlschlagenden Test-Fixtures pauschal entfernen.


## 8. Admin-Startdateien: Hashvermerk gefunden, Originaldateien nicht gefunden

Die Werte für `AVA_ADMIN_CHECK.ps1` (`20FC0D4F5F0F22857F95DDF7DCAC4742474CFA90ABA369082CFED4C526289B78`) und `START_AVA_ADMIN_CHECK.cmd` (`31ED9855DF6B05D4BB4D4BA3FC51EA1185F8F210F055F5F9A2046FEA1877611E`) sind in `docs/AVA_FLASH_IMMUTABLE_RULE.md` als Referenzwerte dokumentiert. `SAFE_START_FINAL.md` erklärt außerdem, dass dies getrennte Dateien sein müssen und Hash-Prüfung vor Ausführung kommt.

Die eigentlichen Dateien mit diesen Namen wurden in den sechs abgeglichenen Standardbranch-Bäumen und der GitHub-Dateisuche nicht als Quell-Dateien gefunden. Daher ließ sich keine unabhängige SHA-256-Übereinstimmung mit einem tatsächlichen Skriptinhalt herstellen. Der dokumentierte Hash ist ein Sollwert, keine Bestätigung des derzeitigen Datei-Inhalts.

**Entscheidung:** nicht ausführen, solange Originaldateien nicht vorhanden, lesbar und hash-verifiziert sind. Auf einem Windows-Laptop ist als nächster Schritt ausschließlich die lokale Hash-Prüfung mit `Get-FileHash` und die textuelle Sichtprüfung vorgesehen; kein `Start-Process`, keine Elevation und kein Autostart.

## 9. Tatsächlich neu gestartete GitHub-Jobversuche

Am 2026-10-14 wurden ausschließlich die fehlgeschlagenen Jobs in drei vorhandenen Testläufen erneut angefordert (keine neuen Workflow-Dispatches und keine Deployments):

| Repository | Run | neuer Versuch bei letzter Statusabfrage | Zustand der letzten Abfrage |
|---|---:|---:|---|
| [AVA-007](https://github.com/hv2znbvdy9-glitch/AVA-007/actions/runs/37056290532) | `37056290532` | 40 | `in_progress` |
| [69-007/AVA Tests](https://github.com/69-007/AVA/actions/runs/37837416840) | `37837416840` | 7 | `queued` |
| [69-007/AVA Python Smoke CI](https://github.com/69-007/AVA/actions/runs/37837416846) | `37837416846` | 7 | `queued` |

Die Versuche laufen auf den bestehenden Commit-SHAs `6d293b38d1aaea9924b3bc8326f85388f362747e` (AVA-007) und `1f6a924f661b37e639843b4860e06d219b73208f` (69-007/AVA). Die erneute Anforderung bestätigt nicht, dass die Tests bestanden haben; diese Runs benötigen ein späteres Ergebnis, das hier zum Prüfzeitpunkt noch nicht vorlag.

## 10. Ausführungsgrenze

Die verbundene GitHub-Schnittstelle stellt für diese Sitzung keine neue `workflow_dispatch`-Aktion bereit. Daher wurden keine neuen Workflows in allen sechs Repositories pauschal ausgelöst; nur die drei vorhandenen fehlgeschlagenen Testläufe konnten über die verfügbare Retry-Aktion neu gestartet werden. Für `DE.VI.TO` ist im Standardbranch kein Workflow vorhanden. Auf realen Windows-Laptops wurde nichts gestartet und kein privilegiertes Skript ausgeführt. GitHub-Dateizugriff ist kein Fernzugriff auf lokale Geräte.
