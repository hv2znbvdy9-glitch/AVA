# AVA – Bestandsaufnahme und Architektur (Stand der Weiterentwicklung)

Dieses Dokument gleicht die in der Planung beschriebene Struktur ("Soll") mit dem
tatsächlichen Repository ("Ist") ab.

## Ist-Zustand

| Bereich | Pfad | Beschreibung |
|---|---|---|
| CLI | `bin/cli.js` | Einstieg: `ava "<cmd>"`, `--safe-local-node` |
| Bibliothek | `src/index.js` | Re-exports von `run`, `runSafeLocalNode`, … |
| Kern | `src/run.js` | `run()` führt Shell-Kommandos aus |
| Safe Local Node | `src/safe-local-node.js` | Lokaler, defensiver Snapshot + HTML-Portal |
| Übersicht / Farben | `src/overview.js`, `src/color.js` | Ausgabe-Hilfen |
| PowerShell | `scripts/*.ps1` | SOC-Portale V5–V7, Core Stack, 3.14 Layer, WLAN-Tangle-Sensor, Spyware-Audit, Baseline-Drift, Memory Core, Security Guardian |
| Tests | `test/*.test.js` | Node `assert`, Ausführung über `npm test` |
| CI | `.github/workflows/ci.yml` | `npm test` auf Node 20 |

Technik: Node.js, CommonJS, keine externen Abhängigkeiten.

## Soll/Ist-Abgleich

Die geplante Python-Struktur (`ava/cli`, `clients`, `config`, `core`, `db`, `lsp`,
`monitoring`, `utils`, `policy*.py`, `neuron_models.py`) sowie die Workflows
`ava-policy.yml`, `safe-audit*.yml`, `run-all-safe.yml`, `psscriptanalyzer.yml`,
`tests/test_ava*.py`, `tools/Invoke-AvaSafeAuditStatic.ps1` und
`docs/AVA_FLASH_IMMUTABLE_RULE.md` sind in **diesem** Repository **nicht** vorhanden
(DEVITO-Auszug: 109 Dateien, 39 Python, 30 PowerShell). Sie gehören zum separaten Server-Stand.

Zuordnung der PowerShell-Skripte (Soll → Ist):

| Soll | Ist |
|---|---|
| `AVA_SOC_PORTAL_V5.ps1` | `scripts/AvaSocPortalV5.ps1` |
| `AVA_SOC_PORTAL_V6_SAFE.ps1` | `scripts/AvaSocPortalV6.ps1` |
| `AVA_SOC_V7_SAFE*.ps1` | `scripts/AvaSocPortalV7.ps1` |
| `AVA_SYMBOLIC_MEMORY_PORTAL.ps1` | `scripts/AvaSymbolicMemoryPortal.ps1` |
| `AVA_3_14_NEXT_LAYER_ALL.ps1` | `scripts/Ava314NextLayerAll.ps1` |
| `AVA_3_14_SAFE_LOCAL_NODE.ps1` | `scripts/Ava314SafeLocalNode.ps1` (+ `src/safe-local-node.js`) |
| `AVA_CORE_STACK_v1.ps1` | `scripts/AvaCoreStack.ps1` |
| WLAN-Tangle-Sensor | `scripts/AVA_WLAN_TANGLE_SENSOR.ps1` |
| `AVA_SOC_CORE*`, `AVA_v4_Portal`, `ava_portal_v4`, `ava_soc_scan_v1`, `AVA_Immune_System_v2/v3` | nicht vorhanden |

## Datenfluss (Evidenz)

Sensor/Skript → JSONL-Log → State/Snapshot (JSON) → HTML-Portal → Evidenz.
Die Skripte arbeiten defensiv, lokal und nur lesend.

## Policy-Entwurf (`ava_admin`, AVA_RADIO_01610_v1)

Entwurf für Zielzustand, noch nicht implementiert: Effekte (`pitch_shift` 3, `echo`,
`radio_filter`, `glitch`, `distortion` 0.15); Sicherheit (Einwilligung erforderlich,
kein Klonen realer Stimmen, lokale Verarbeitung bevorzugt); Evidenz (Logging an,
Aufnahme standardmäßig aus).

Hinweis zum Skriptauszug: Die Zeilen `"name": "…"` in einer PowerShell-`[ordered]@{}`
sind JSON-Syntax und in PowerShell ungültig (richtig: `name = "…"`), und
`$env:dhild` / `$env:DEVITO` sind keine Standardvariablen (richtig: `$env:COMPUTERNAME`,
`$env:USERNAME`).

## Nächste Schritte

1. Fehlende Python-Teile (Policy, Neuron-Modelle) in separatem Repository/Branch führen oder importieren.
2. Workflows für PSScriptAnalyzer ergänzen.
3. Unveränderliche Ereignisregel (`AVA_FLASH_IMMUTABLE_RULE`) dokumentieren: erstes Ereignis bleibt, weitere werden angehängt.
