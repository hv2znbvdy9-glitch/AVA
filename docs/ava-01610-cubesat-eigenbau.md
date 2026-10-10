# AVA 01610-1 — CubeSat-Eigenbau: Evidenz vor Aktion

> Leitprinzip: Keine finanziellen Mittel für Bausätze, Hardware-Qualifikation oder
> Raketenstarts binden, bevor nicht die bodengebundene Simulation und reproduzierbare
> Evidenz die Machbarkeit und Sicherheitsarchitektur lückenlos nachgewiesen haben.

---

## 1. Missionsdefinition und Anforderungsanalyse

### 1.1 Missionsprofil
Ein 1U-CubeSat ist ein standardisierter Kleinsatellit mit Außenabmessungen von ca.
**10 × 10 × 10 cm** und einer Höchstmasse von ca. **1,33 kg**.

Das Primärprofil für AVA 01610-1 konzentriert sich auf:
- **Telemetrie und Umweltsensorik**: Erfassung von Batteriespannung, Solarladung,
  Innentemperatur und Hüllentemperatur in LEO (Low Earth Orbit).
- **AVA-Sicherheitsmonitoring**: End-to-End-Integritätssicherung aller Telemetriedaten
  mittels kryptografischer Hash-Verkettung (SHA-256) und verifizierte Ausführung von
  Bodenstations-Kommandos via HMAC-SHA256.

### 1.2 Missionsziele und Erfolgskriterien

| Bereich | Mindestanforderung (Erfolgskriterium) |
|---|---|
| **Formfaktor** | Strikt 1U (100 × 100 × 100 mm), Deployer-kompatibel nach CubeSat Design Specification. |
| **Energiehaushalt (EPS)** | Positives Energiebudget im LEO-Betrieb (~60 min Sonne, ~35 min Eclipse). |
| **Befehlssicherheit** | 100 % Abweisung unauthentifizierter oder manipulierter Uplink-Befehle; Replay-Abwehr. |
| **Evidenzsicherung** | Lückenlose SHA-256-Hash-Kette aller übertragenen Telemetriedatenpakete. |
| **Autonomie & Robustheit** | Watchdog-Reset-Mechanismus bei Software-Hängern; definierter Safe-Mode bei Unterspannung. |

### 1.3 Budget- und Grenzwertanalyse

| Budget-Stufe | Ziel & Umfang | Machbarkeit & Risiko |
|---|---|---|
| **< 1.000 €** | **Stufe A: Bodensimulation (Software)** | Sofort realisierbar am PC. Keine Start- oder Hardwarekosten, vollständige Verifikation der Systemlogik. |
| **1.000–10.000 €** | **Stufe B: Engineering-Modell (Hardware-in-the-Loop)** | Laborprototyp (Flachbett-Aufbau, Mikrocontroller, Sensorik, SDR-Bodenstation). Kein Startplatz. |
| **> 10.000 €** | **Stufe C: Flugmodell & Rideshare-Start** | Gesamtkosten betragen typischerweise 25.000–60.000 € inkl. Startplatz, TVAC/Vibrationstests und Genehmigungen. |

---

## 2. Phase A: Bodensimulation (Software & Virtuelles Labor)

Die Bodensimulation bildet das softwareseitige Fundament, um die Satellitenlogik
ohne Kosten- und Startrisiken reproduzierbar abzusichern.

### 2.1 Modellierung des 1U-Systems
- **On-Board-Computer (OBC)**: Schrittweise Zustandserfassung (Power-Mode, Sensordaten, Antennenstatus).
- **Elektrische Energieversorgung (EPS)**:
  - Solarertrag: ca. 2,5 W in der Sonnenphase, 0 W während der Sonnenfinsternis (Eclipse).
  - Verbrauch: ca. 0,8 W im Nominal-Leerlauf, 2,2 W während Funkfeuer-Sendungen (Beacon), 0,4 W im Low-Power-Modus.
  - Batterie: 10 Wh Kapazität mit Tiefentladeschutz und Spannungsüberwachung (3,4 V bis 4,2 V).
- **Orbit- & Thermalsimulation**:
  - Typischer LEO-Orbit (Höhe ~500 km, Umlaufzeit ~94,6 min).
  - Thermisches Verhalten: Erwärmung auf ca. +26 °C bis +31 °C im Sonnenlicht, Abkühlung auf ca. -10 °C bis -15 °C im Erdschatten.

### 2.2 Telemetrie- und Evidenzkette
Jedes Telemetriepaket enthält:
```json
{
  "step": 0,
  "minute": 0,
  "orbitNumber": 1,
  "inSunlight": true,
  "altitudeKm": 500,
  "temperatureCelsius": 26.0,
  "solarWatts": 2.5,
  "loadWatts": 2.2,
  "batteryWh": 9.0,
  "batteryPercent": 90.0,
  "voltage": 4.12,
  "powerMode": "NOMINAL",
  "antennaDeployed": false,
  "prevHash": "0000000000000000000000000000000000000000000000000000000000000000",
  "hash": "c8a4f9e1..."
}
```
Durch die `prevHash`-Verkettung ergibt sich eine kryptografisch manipulationssichere
Historie: Wird ein historischer Messwert nachträglich manipuliert, bricht die
Validierungsprüfung der Kette ab.

### 2.3 Befehls- und Kontrolllogik (Uplink-Sicherheit)
- Authentifizierung mittels **HMAC-SHA256**.
- **Anti-Replay-Schutz**: Jeder Befehl führt eine fortlaufende `nonce`. Wiederholte
  Nonces werden sofort verworfen.
- **Whitelist**: Nur autorisierte Befehle (`Ping`, `AdjustAltitude`, `SetPowerMode`,
  `DeployAntenna`, `ResetEPS`, `CollectTelemetry`) werden ausgeführt.
- Nicht signierte, falsch signierte oder nicht gelistete Befehle werden abgewiesen
  und im Sicherheits-Auditprotokoll registriert.

---

## 3. Phase B: Engineering-Modell (Hardware-in-the-Loop)

Nach erfolgreichem Abschluss von Phase A wird ein physischer Labor-Prototyp aufgebaut.

1. **Komponentenauswahl**:
   - Mikrocontroller: z. B. STM32 ARM Cortex-M4 oder ESP32 mit Hardware-Krypto-Beschleuniger.
   - Sensorik: I2C/SPI-Sensoren für 3-Achsen-Magnetometer, Gyroskop, Photodioden und Temperatursensoren.
   - Energie: LiFePO4-Zellen (hohe Eigensicherheit im Vakuum) mit MPPT-Solarladeregler.
2. **Flugsoftware-Portierung**:
   - Deterministischer Task-Scheduler mit Hardware-Watchdog (automatischer Neustart bei Hänger).
   - Brownout-Detection bei Spannungsabfall unter 3,3 V.
3. **Bodenstations-Setup**:
   - Empfang und Dekodierung mittels Software Defined Radio (z. B. RTL-SDR oder HackRF).
   - Antennen-Matching und Filter für das 70-cm-Amateurfunk- bzw. ISM-Band.

---

## 4. Phase C: Kostenermittlung, Regulatorik und Qualifikation

Für den realen Start in den Erdorbit sind formale und technische Hürden zu überwinden:

### 4.1 Gesamtkostenstruktur

| Kostenpunkt | Typischer Betrag |
|---|---|
| Raumfahrtqualifizierte 1U-Struktur & Solarpaneele | 3.000 – 7.000 € |
| Raumfahrttaugliche Elektronik & Batteriemodule | 2.500 – 6.000 € |
| Umwelttests (TVAC, Schwingtisch) im Testzentrum | 5.000 – 15.000 € |
| Frequenzgebühren & Zertifizierungen | 1.000 – 3.000 € |
| Rideshare-Startplatz (Deployer-Integration) | 15.000 – 35.000 € |
| **Gesamtkosten Flugmodell & Start** | **26.500 – 66.000 €** |

### 4.2 Regulatorischer Rahmen
- **Frequenzkoordination**: Frühzeitige Abstimmung mit der **IARU** (International Amateur Radio Union)
  und Frequenzzuteilung durch die nationale Regulierungsbehörde (**BNetzA**).
- **Weltraumrecht & Registrierung**: Eintragung in das Weltraumregister der Vereinten Nationen
  (UN OOSA) und Nachweis einer Raumfahrt-Haftpflichtversicherung.
- **Weltraummüll (Space Debris Mitigation)**: Nachweis des sicheren Wiedereintritts in die
  Erdatmosphäre innerhalb von maximal 25 Jahren (bzw. neuerer 5-Jahres-Richtlinien).

### 4.3 Umwelttests (Flight Readiness)
- **Thermisches Vakuum (TVAC)**: Zyklische Temperaturwechsel zwischen -20 °C und +50 °C im Hochvakuum.
- **Vibration & Schock**: Sinus- und Random-Vibrationstests gemäß den Anforderungen der Trägerrakete.
- **EMV**: Prüfung der elektromagnetischen Verträglichkeit zur Vermeidung von Interferenzen mit
  der Primärnutzlast der Rakete.

---

## 5. Review und Meilenstein-Entscheidung

Das Prinzip **Evidenz vor Aktion** regelt die Meilenstein-Übergänge:

1. **Gate 1 (Freigabe Phase B)**:
   - Erfordert 100 % bestandene Unit- und Integrationstests der Bodensimulation.
   - Lückenlose Validierung der SHA-256-Telemetriekette und erfolgreiche Abwehr aller Replay-Tests.
2. **Gate 2 (Freigabe Phase C)**:
   - Erfordert erfolgreichen 72-Stunden-Dauerbetrieb des Engineering-Modells unter Laborbedingungen.
   - Vollständige Frequenzkoordination und Kostendeckungsnachweis vor Vertragsabschluss mit einem Startanbieter.

---

## 6. Nutzung im AVA-Projekt

- **CLI-Aufruf**:
  ```bash
  ava --cubesat
  ava cubesat
  ```
- **CLI-Simulation (Phase A)**:
  ```bash
  ava --cubesat-sim
  ava cubesat-sim
  ```
- **Als Node.js-Bibliothek**:
  ```js
  const { cubeSat01610Report, cubeSat01610Data, simulateCubeSat } = require('ava');

  // Bericht anzeigen
  console.log(cubeSat01610Report());

  // Bodensimulation ausführen
  const result = simulateCubeSat({ durationMinutes: 190 });
  console.log('Telemetriekette intakt:', result.chainVerified);
  console.log('Evidence Root:', result.evidenceRoot);
  ```
