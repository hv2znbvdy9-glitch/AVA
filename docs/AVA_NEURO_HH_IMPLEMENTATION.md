# AVA 01610 Neuro-HH: Analyse und Implementierung

## Status

`ava-neuro-hh-l5-prototype/v1` ist ein ausführbarer, deterministischer und
abhängigkeitsfreier Multi-Kompartiment-Prototyp für AVA/Nachhall/JARVIS.

Er ist **kein** unverändertes Hay-L5b-Modell und darf nicht als experimentell
validierte digitale Kopie einer Schicht-5-Pyramidenzelle bezeichnet werden.
Der Prototyp schafft eine prüfbare Integrationsschicht im bestehenden
Node.js-Projekt; die vollständige Hay-Reproduktion bleibt ein eigener
NEURON/ModelDB-Arbeitsschritt.

## Wissenschaftliche Prüfung der Ausgangsaussagen

| Aussage | Urteil | Präzisierung |
|---|---|---|
| Hay et al. ist ein aktives, morphologisch rekonstruiertes Multi-Kompartimentmodell einer L5b-Pyramidenzelle. | Belegt | Die Arbeit nutzte im Mittel etwa 200 Kompartimente pro Modellzelle, Hodgkin-Huxley-artige Ströme, neun optimierte Kanal-Dichten beziehungsweise zehn beschriebene aktive Ströme und NEURON. |
| Das Hay-Modell bildet somatische Na-Spikes, dendritische Ca-Spikes, Rückpropagation und BAC-Firing ab. | Belegt | Genau diese perisomatischen und dendritischen Zielmerkmale wurden gemeinsam optimiert. Das ist nicht dasselbe wie eine vollständige Zellkopie. |
| Das Hay-Axon ist vollständig rekonstruiert. | Falsch | Für das Hauptmodell wurde der axonale Spikebereich aus Vereinfachungsgründen auf eine perisomatische Zone reduziert; vom rekonstruierten Axon blieb nur das Anfangssegment. |
| Das Hay-Modell enthält NMDA-Spikes. | Nicht als Eigenschaft dieses Modells belegt | NMDA-Spikes gehören zur allgemeinen Physiologie aktiver Dendriten, sind aber kein implementierter Kernmechanismus des beschriebenen Hay-Modells. |
| DeepDendrite modelliert ungefähr 25.000 Spines. | Belegt | Die Publikation nennt 24.994 beziehungsweise gerundet 25.000 Spines in einem detaillierten menschlichen Pyramidenzellmodell. Die explizite Geometrie darf nicht mit vollständiger Spine-Biochemie gleichgesetzt werden. |
| Das 2019 untersuchte neokortikale Mikroschaltkreismodell hatte 31.346 Neuronen, etwa 7,8 Mio. Verbindungen, 36,4 Mio. Synapsen und 55 morphologische Typen. | Belegt | Die Methoden nennen genau diese Größen; stochastische Vesikelfreisetzung galt für die Synapsen, stochastische K-Kanäle nur für 1.137 irregulär feuernde Neuronen. |
| Mehr Details bedeuten automatisch mehr biologische Wahrheit. | Nicht haltbar | Reference-grade-Modellierung verlangt zusätzlich nachvollziehbare Provenienz, erklärte Unsicherheit, Ensemble-Vorhersagen und unabhängige Validierung. |

## Was AVA jetzt tatsächlich simuliert

Das Modell enthält sieben gekoppelte, lumped Kompartimente:

```text
AIS ↔ Soma ↔ basaler Dendrit
       ↕
proximal apikal ↔ Stamm ↔ distale Ca-Zone ↔ Tuft
```

Pro Kompartiment wird die Membranspannung integriert:

```text
C_m dV/dt = I_ext + I_axial
            - I_Na - I_K - I_leak - I_Ca - I_KCa - I_HCN
```

Enthalten sind:

- klassische schnelle Na- und verzögert gleichrichtende K-Gates,
- vereinfachte hochschwellige Ca-Dynamik,
- ein Ca-abhängiger K-Strom,
- ein vereinfachter HCN-Strom mit distalem Dichtegradienten,
- elektrische Kopplung zwischen benachbarten Kompartimenten,
- lumped intrazelluläre Calciumdynamik,
- RK4-Integration mit standardmäßig `dt = 0,01 ms`,
- Spike- und dendritische Calciumereignis-Erkennung,
- reproduzierbare Protokolle für Ruhe, somatische Stufe, distalen Puls und zeitliche Koinzidenz.

Die Parameter sind bewusst als transparenter Prototyp gekennzeichnet. Sie wurden
nicht gegen die Hay-Zielverteilungen oder neue Patch-Clamp-Daten optimiert.

## Ausführung

```bash
npm run test:neuro
npm run neuro:demo
```

Direkter Aufruf:

```bash
node bin/cli.js --neuro-hh \
  --protocol bac-coincidence \
  --output AVA_EVENTS
```

Verfügbare Protokolle:

- `rest`
- `somatic-step`
- `distal-pulse`
- `bac-coincidence`

`bac-coincidence` ist der Name des Stimulationsprotokolls. Ein erfolgreich
ausgeführtes Protokoll ist **kein experimenteller Nachweis von BAC-Firing**.

## Nachweis- und Doppeltrigger-Schutz

Jeder CLI-Lauf erzeugt ein neues Verzeichnis:

```text
AVA_EVENTS/<UTC-Zeit>_<UUID>/
├─ summary.json
├─ trace.csv
└─ manifest.json
```

`manifest.json` enthält SHA-256-Werte für Zusammenfassung und Messspur. Dateien
werden exklusiv neu angelegt. Eine bereits vorhandene Ereignis-ID führt zum STOP,
nicht zum Überschreiben.

Damit gilt auch für die Simulation:

> Erster Blitz bleibt. Zweiter Blitz ergänzt. Kein Überschreiben.

## Validierungsgrenze

Automatisch geprüft werden:

- endliche Zustände ohne NaN/Infinity,
- begrenzte Spannungen,
- Ruhe ohne somatische Spikes,
- somatisch ausgelöster und dendritisch fortgeleiteter Spike,
- distales Calciumereignis,
- deterministische Wiederholung,
- SHA-256-Integrität und getrennte Ereignisverzeichnisse.

Noch **nicht** validiert sind:

- reale 3D-Morphologie und d_lambda-Diskretisierung,
- originales Hay-Parameterset und dessen zehn Ströme,
- quantitative f-I-Kurven, BAP-Amplituden und BAC-Merkmale gegen Messdaten,
- explizite Synapsen, NMDA-Spikes und 24.994 Spines,
- Plastizität, Neuromodulation, Proteinsynthese, Stoffwechsel und Glia,
- Unsicherheits-Ensembles und unabhängige Laborreplikation.

## Weg zum vollständigen Referenzmodell

1. ModelDB 139653 und zugehörige Lizenz/Provenienz unverändert archivieren.
2. NEURON-Version, MOD-Dateien, Morphologie, Parameter und Temperatur fest pinnen.
3. Referenzprotokolle aus Hay et al. getrennt reproduzieren.
4. Spannungs- und Feature-Regression gegen veröffentlichte Zielbereiche aufbauen.
5. Parameterunsicherheit als Ensemble statt als einzelnes „bestes“ Modell führen.
6. Erst nach bestandener unabhängiger Validierung die Bezeichnung
   `Hay-L5b-compatible` verwenden.

## Primärquellen

- Hay et al. (2011), PLOS Computational Biology: <https://doi.org/10.1371/journal.pcbi.1002107>
- Hay-L5b-Code, ModelDB accession 139653: <https://modeldb.science/139653>
- Zhang et al. (2023), DeepDendrite: <https://doi.org/10.1038/s41467-023-41553-7>
- Nolte et al. (2019), neokortikales Mikroschaltkreismodell: <https://doi.org/10.1038/s41467-019-11633-8>
- Korngreen (2026), reference-grade neuron models: <https://doi.org/10.1038/s42003-026-10561-w>

