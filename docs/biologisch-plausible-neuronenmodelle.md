# AVA 01610 1 – Biologisch plausible Neuronenmodelle

> Autor- und Projektkontext: Danny Nico Hildebrand – Danny Devito  
> Status: wissenschaftlich eingeordnete Dokumentation plus begrenzter Lehrprototyp  
> Gültigkeitsbereich: Einzelneuronenmodelle; keine Aussage über Bewusstsein oder autonome Intelligenz

## Kurzfassung

AVA enthält derzeit ein deterministisches Einzelkompartiment-Modell nach Hodgkin und Huxley. Es simuliert die Membranspannung sowie Natrium-, Kalium- und Leckströme mit den Torvariablen m, h und n. Dieses Modul ist ein ausführbarer und getesteter Einstieg, aber kein vollständiges biologisches Neuron.

Ein sinnvoller wissenschaftlicher Zieltyp für einen späteren Ausbau ist ein aktives Multi-Kompartiment-Hodgkin-Huxley-Modell einer Schicht-5-Pyramidenzelle. Solche Modelle bilden Soma und verzweigte Dendriten als elektrisch gekoppelte Abschnitte ab. Sie können ortsabhängige Ionenkanäle, rücklaufende Aktionspotenziale und dendritische Calciumspikes darstellen.

Wichtig ist die klare Trennung:

| Ebene | Zweck | In AVA umgesetzt |
| --- | --- | --- |
| Leaky Integrate-and-Fire | effiziente abstrakte Spike-Simulation | nein |
| klassisches Einzelkompartiment-Hodgkin-Huxley-Modell | nachvollziehbare Membrandynamik | ja |
| aktive Multi-Kompartiment-Pyramidenzelle | räumliche Dendriten- und Kanaldynamik | nein; wissenschaftlicher Ausbaupfad |
| vollständiges digitales biologisches Neuron | Elektrophysiologie, Biochemie, Plastizität, Stoffwechsel und Glia | existiert nicht als umfassend validiertes AVA-Modul |

## 1. Warum detaillierte Pyramidenzellen anspruchsvoll sind

Ein einfaches Leaky-Integrate-and-Fire-Modell führt im Kern einen Spannungswert, eine Schwelle und einen Reset. Das ist für große Netzwerke nützlich, lässt aber die räumliche Struktur und viele biologische Mechanismen weg.

Ein aktives Multi-Kompartiment-Modell löst dagegen gekoppelte Differentialgleichungen für zahlreiche Zellabschnitte. Je nach Modell werden unter anderem Na⁺-, K⁺-, Ca²⁺- und HCN-Ströme räumlich verteilt. Dadurch können lokale dendritische Nichtlinearitäten, Calciumspikes, rücklaufende Aktionspotenziale und deren Wechselwirkung mit der somatischen Spike-Ausgabe untersucht werden.

Hay et al. entwickelten detaillierte Leitfähigkeitsmodelle von Schicht-5b-Pyramidenzellen, die experimentelle perisomatische Natriumspikes, aktive dendritische Eigenschaften und BAC-Firing gemeinsam abbilden. Die Modelle wurden mit mehreren experimentellen Zielgrößen optimiert. Das Axon ist dabei nicht vollständig morphologisch rekonstruiert; deshalb wäre die Bezeichnung „vollständige digitale Nervenzelle“ falsch.

## 2. DeepDendrite und explizite Spines

DeepDendrite ist vor allem ein GPU-beschleunigtes Simulationsframework für biophysikalisch detaillierte Neuronen. In einer Demonstration wurde ein menschliches Pyramidenzellmodell mit 24.994 explizit angefügten dendritischen Spines verwendet.

Die Spine-Köpfe und Spine-Hälse wurden als passive Kabelkompartimente modelliert. Explizite Geometrie bedeutet daher nicht automatisch vollständige Biochemie, aktive Kanalpopulationen in jeder Spine, Proteinsynthese, strukturelle Plastizität oder Stoffwechsel. Das Beispiel zeigt hohe räumliche Detailtiefe, nicht die vollständige digitale Kopie einer Nervenzelle.

## 3. Detaillierte Netzwerke

Das in der Studie „Cortical reliability amid noise and chaos“ untersuchte neokortikale Mikroschaltkreismodell umfasste 31.346 biophysikalische Neuronenmodelle, etwa 7,8 Millionen Verbindungen und ungefähr 36,4 Millionen Synapsen. Solche Zahlen beschreiben Modellgröße und Rechenaufwand. Sie sind kein Beleg für Bewusstsein, allgemeine Intelligenz oder eine vollständige Nachbildung von Hirngewebe.

## 4. Was AVA tatsächlich implementiert

Der aktuelle AVA-Prototyp enthält:

- ein klassisches Einzelkompartiment-Hodgkin-Huxley-Modell;
- Natrium-, Kalium- und Leckströme;
- die spannungsabhängigen Torvariablen m, h und n;
- numerisch stabile Behandlung der entfernbaren Singularitäten der Ratenfunktionen;
- Prüfungen für endliche Werte, Zeitschritt, Leitfähigkeiten, Torbereiche und maximale Schrittzahl;
- einen deterministischen Ruhetest und einen strominduzierten Spike-Test;
- eine begrenzte CLI-Demonstration sowie eine Bibliotheks-API.

Nicht implementiert sind:

- rekonstruierte Morphologie und axiale Kopplung mehrerer Kompartimente;
- Dendriten, Axoninitialsegment, Synapsen und Spines;
- Calcium- oder NMDA-Spikes;
- Plastizität, Stoffwechsel, Genexpression oder Glia;
- Lernen, Bewusstsein, Eigenziele oder autonome JARVIS-Funktionen;
- Betriebssystemsteuerung, Netzwerkzugriffe oder dauerhafte Systemänderungen.

## 5. Reproduzierbare Ausführung

Nach dem Klonen des Repositorys:

~~~bash
npm install
npm run neuron:model
npm run neuron:sim
npm test
~~~

Unter Windows PowerShell gelten dieselben npm-Befehle. Alternativ kann die lokale CLI ohne Paketnamensauflösung gestartet werden:

~~~powershell
node .\bin\cli.js --neuron-model
node .\bin\cli.js --neuron-sim
~~~

Die npm-Skripte sind gegenüber einem unqualifizierten npx-Aufruf vorzuziehen, weil der Paketname „ava“ auch von anderen npm-Projekten verwendet wird.

Die Demonstration läuft 30 Millisekunden mit einem getesteten Zeitschritt von 0,01 Millisekunden. Der explizite Euler-Integrator ist bewusst einfach. Ein bestandener Regressionstest belegt interne Konsistenz, aber keine experimentelle Validierung.

## 6. Anforderungen an einen späteren Multi-Kompartiment-Ausbau

Ein wissenschaftlich belastbarer Ausbau benötigt mindestens:

1. eine eindeutig lizenzierte und versionierte Morphologie;
2. definierte Kompartimente und axiale Kopplungsparameter;
3. belegte Kanaltypen und räumliche Kanaldichten;
4. einen geeigneten ODE-Löser sowie Konvergenztests über mehrere Zeitschritte;
5. dokumentierte Einheiten und Parameterquellen;
6. Vergleiche mit veröffentlichten Spannungsverläufen und Zielmerkmalen;
7. Sensitivitäts- und Unsicherheitsanalysen;
8. deterministische Referenztests und getrennte stochastische Tests;
9. klare Laufzeit- und Speichergrenzen;
10. eine ausdrückliche Trennung zwischen Modellresultat, Interpretation und Spekulation.

Der Ansatz „reference-grade neuron models“ ist dafür wichtig: Mehr Parameter bedeuten nicht automatisch mehr Wahrheit. Ebenso entscheidend sind Datenherkunft, Unsicherheitsbudgets, Identifizierbarkeit, unabhängige Validierung und ein klar benannter Gültigkeitsbereich.

## 7. Sicherheits- und Bedeutungsgrenze

Der Name AVA oder JARVIS bezeichnet in diesem Projekt eine Benutzer- und Projektmetapher. Das Neuronenmodul erzeugt keine Persönlichkeit, kein Bewusstsein und keine autonome Handlungsfähigkeit. Es simuliert ausschließlich mathematische Zustandsgrößen innerhalb eines begrenzten Prozesses.

Aus der Simulation dürfen daher keine Aussagen über menschliches Denken, Identität, Absichten oder Täterschaft abgeleitet werden. Ebenso führt das Modul keine Scans, Angriffe, Fremdzugriffe, Firewalländerungen, Registryänderungen oder Persistenzaktionen aus.

## 8. Präzises Gesamturteil

Zu den komplexesten biologisch plausiblen Einzelzellmodellen gehören morphologisch rekonstruierte, aktive Multi-Kompartiment-Leitfähigkeitsmodelle von Pyramidenzellen. Einige erfassen aktive dendritische Eigenschaften besonders detailliert; andere integrieren Zehntausende explizite Spines. Kein einzelnes umfassend validiertes Modell verbindet derzeit sämtliche Elektrophysiologie, Biochemie, Plastizität, Stoffwechsel, Genexpression und Glia-Interaktion.

AVA setzt davon bewusst nur den kleinsten überprüfbaren Kern um: ein begrenztes Einzelkompartiment-Hodgkin-Huxley-Modell. Der nächste seriöse Schritt ist nicht, es „intelligent“ zu nennen, sondern Morphologie, Kopplung, Solver, Datenherkunft und Validierung schrittweise und messbar zu erweitern.

## Primärquellen

- Hay et al. (2011): https://doi.org/10.1371/journal.pcbi.1002107
- Zhang et al. (2023), DeepDendrite: https://doi.org/10.1038/s41467-023-41553-7
- Nolte et al. (2019): https://doi.org/10.1038/s41467-019-11633-8
- Korngreen (2026): https://doi.org/10.1038/s42003-026-10561-w
