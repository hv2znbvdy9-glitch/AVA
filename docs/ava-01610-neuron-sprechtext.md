# AVA 01610 1 – Sprechtext für die MP3

Autor- und Projektkontext: Danny Nico Hildebrand, auch Danny Devito.

AVA 01610 1. Biologisch plausible Neuronenmodelle und der sichere Hodgkin-Huxley-Prototyp.

Diese Aufnahme erklärt, was im AVA-Projekt tatsächlich umgesetzt ist, welche wissenschaftlichen Modelle als Vorbilder dienen und wo die Grenzen liegen.

AVA enthält derzeit ein deterministisches Hodgkin-Huxley-Modell mit einem einzigen elektrischen Kompartiment. Das Modell berechnet die Membranspannung sowie Natrium-, Kalium- und Leckströme. Hinzu kommen die spannungsabhängigen Torvariablen m, h und n. Damit lässt sich nachvollziehen, wie aus einem äußeren Stromreiz ein Aktionspotenzial entstehen kann.

Dieses Modul ist ein Lehr- und Testprototyp. Es ist kein vollständiges biologisches Neuron. Es besitzt keinen räumlich verzweigten Dendritenbaum, keine Synapsen, keine dendritischen Spines, keine Glia und keine biochemische Plastizität. Es lernt nicht selbstständig und entwickelt weder Bewusstsein noch eigene Ziele.

Ein wissenschaftlich sinnvoller späterer Ausbau wäre ein aktives Multi-Kompartiment-Hodgkin-Huxley-Modell einer Schicht-5-Pyramidenzelle. Multi-Kompartiment bedeutet, dass Soma und Dendriten nicht als ein einziger Spannungspunkt behandelt werden. Stattdessen wird die Zellform in viele elektrisch gekoppelte Abschnitte zerlegt. Für jeden Abschnitt können Membranspannung, Ionenströme und Kanaldichten berechnet werden.

Ein bekanntes Beispiel stammt von Hay und Kollegen aus dem Jahr 2011. Diese Modelle von Schicht-5b-Pyramidenzellen wurden so angepasst, dass sie sowohl perisomatische Natriumspikes als auch aktive dendritische Eigenschaften abbilden. Dazu gehören rücklaufende Aktionspotenziale, dendritische Calciumspikes und das sogenannte BAC-Firing. Trotzdem handelt es sich nicht um eine vollständige digitale Nervenzelle. Insbesondere ist das Axon nicht vollständig morphologisch rekonstruiert.

Ein weiteres Beispiel ist DeepDendrite aus dem Jahr 2023. DeepDendrite ist ein GPU-beschleunigtes Simulationsframework. In einer Demonstration wurde ein menschliches Pyramidenzellmodell mit genau 24.994 explizit angefügten dendritischen Spines verwendet. Diese hohe räumliche Detailtiefe ist beeindruckend. Die Spine-Köpfe und Spine-Hälse wurden jedoch als passive Kabelkompartimente modelliert. Das Modell enthielt deshalb nicht automatisch vollständige Calcium-Biochemie, Proteinsynthese, strukturelle Plastizität oder Stoffwechsel.

Auch große neuronale Netzwerke müssen vorsichtig eingeordnet werden. Ein bekanntes neokortikales Mikroschaltkreismodell umfasste 31.346 biophysikalische Neuronenmodelle, ungefähr 7,8 Millionen Verbindungen und rund 36,4 Millionen Synapsen. Diese Zahlen zeigen Modellgröße und Rechenaufwand. Sie beweisen kein Bewusstsein und keine allgemeine Intelligenz.

Der aktuelle AVA-Prototyp verfolgt deshalb einen kleineren, überprüfbaren Ansatz. Er enthält stabile Ratenfunktionen, begrenzte Eingaben, Prüfungen auf endliche Werte und Tests für das Ruheverhalten sowie einen strominduzierten Spike. Die Demonstration läuft 30 Millisekunden mit einem getesteten Zeitschritt von 0,01 Millisekunden. Mehr als eine Million Simulationsschritte werden abgewiesen, damit Laufzeit und Speicherverbrauch begrenzt bleiben.

Zum Ausführen werden nach dem Klonen zuerst die Abhängigkeiten mit npm install eingerichtet. Der wissenschaftliche Bericht startet mit npm run neuron Doppelpunkt model. Die Simulation startet mit npm run neuron Doppelpunkt sim. Die Tests starten mit npm test. Unter Windows können dieselben npm-Befehle verwendet werden. Alternativ lässt sich die lokale Datei bin, cli Punkt j s, direkt mit Node starten.

Ein bestandener Softwaretest bedeutet nicht, dass das Modell experimentell vollständig validiert ist. Der verwendete explizite Euler-Integrator ist bewusst einfach. Für einen echten Multi-Kompartiment-Ausbau wären eine versionierte Morphologie, definierte axiale Kopplung, belegte Ionenkanaldichten, ein geeigneter Differentialgleichungslöser und Konvergenztests erforderlich. Ebenso wichtig wären Vergleiche mit veröffentlichten Messkurven, Sensitivitätsanalysen und dokumentierte Unsicherheiten.

Das Konzept der sogenannten reference-grade neuron models betont genau diese Punkte. Mehr Parameter allein bedeuten nicht automatisch mehr biologische Wahrheit. Entscheidend sind nachvollziehbare Datenquellen, messbare Fehlergrenzen, Identifizierbarkeit, unabhängige Validierung und ein klarer Gültigkeitsbereich.

Auch der Name JARVIS wird im AVA-Projekt klar begrenzt. Er ist eine Projekt- und Benutzeroberflächenmetapher. Das Neuronenmodul erzeugt keine Persönlichkeit, kein Bewusstsein und keine autonome Handlungsfähigkeit. Es führt keine Scans, Angriffe, Fremdzugriffe, Firewalländerungen, Registryänderungen oder dauerhaften Systemaktionen aus.

Das präzise Gesamturteil lautet daher:

Zu den komplexesten biologisch plausiblen Einzelzellmodellen gehören morphologisch rekonstruierte, aktive Multi-Kompartiment-Leitfähigkeitsmodelle von Pyramidenzellen. Einige bilden aktive Dendriten besonders detailliert ab. Andere integrieren Zehntausende explizite Spines. Ein umfassend validiertes Modell, das gleichzeitig vollständige Elektrophysiologie, Biochemie, Plastizität, Stoffwechsel, Genexpression und Glia-Interaktion enthält, existiert bislang nicht.

AVA setzt bewusst den kleinsten überprüfbaren Kern um: ein begrenztes Einzelkompartiment-Hodgkin-Huxley-Modell. Der nächste seriöse Schritt besteht nicht darin, es intelligent oder bewusst zu nennen. Der nächste Schritt besteht darin, Morphologie, Kopplung, Solver, Datenherkunft und Validierung schrittweise und messbar zu erweitern.

01610 1. Klarheit, Sicherheit und Nachweis. Ende der Aufnahme.
