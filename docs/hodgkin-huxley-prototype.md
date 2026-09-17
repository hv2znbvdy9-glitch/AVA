# AVA Hodgkin-Huxley-Lehrprototyp

> Projektkontext: AVA 01610 1  
> Autorzuordnung: Danny Nico Hildebrand – Danny Devito

Dieses Modul implementiert deterministisch das klassische Hodgkin-Huxley-Membranmodell in einem einzelnen Kompartiment. Es ist ein ausführbarer, abhängigkeitenarmer Einstieg in die weiterführende Analyse biologisch plausibler Neuronenmodelle.

Es ist ausdrücklich kein Hay-L5b-Modell, kein DeepDendrite-Modell, kein Lernsystem, kein Bewusstsein und kein autonomer AVA- oder JARVIS-Agent.

## Implementierter Umfang

- Natrium-, Kalium- und Leckströme;
- spannungsabhängige m-, h- und n-Tore;
- stabile Ratenfunktionen an den entfernbaren Singularitäten;
- Prüfungen für endliche Werte, Zeitschritt, Leitfähigkeiten, Torbereiche und Gesamtschrittzahl;
- deterministische Regressionstests für Ruheverhalten und einen strominduzierten Spike;
- begrenzte CLI-Ausgabe mit einer kompakten Zusammenfassung.

Nicht implementiert sind rekonstruierte Morphologie, gekoppelte Dendritenkompartimente, Synapsen, Spines, Calcium- oder NMDA-Spikes, Plastizität, Stoffwechsel, Genexpression, Glia, Lernen oder Agency.

## Ausführen

~~~bash
npm install
npm run neuron:sim
~~~

Direkter lokaler Aufruf:

~~~bash
node ./bin/cli.js --neuron-sim
~~~

Unter Windows PowerShell:

~~~powershell
node .\bin\cli.js --neuron-sim
~~~

Die Demonstration simuliert 30 ms mit einem getesteten Zeitschritt von 0,01 ms. Sie meldet den Spannungshöchstwert und ob die Spannung 0 mV überschritten hat. Sie führt keine Netzwerk-, Betriebssystem-, Persistenz- oder Geräteaktion aus.

## Bibliotheksnutzung

~~~js
const {simulateNeuron} = require('./src');

const trace = simulateNeuron({
  durationMs: 30,
  dt: 0.01,
  current: (timeMs) => (timeMs >= 5 && timeMs < 25 ? 10 : 0),
});

console.log(Math.max(...trace.map((sample) => sample.voltage)));
~~~

Die Einheiten folgen der klassischen Formulierung: Zeit in ms, Spannung in mV, Kapazität in μF/cm², Leitfähigkeit in mS/cm² und Stromdichte in μA/cm².

Der explizite Euler-Integrator akzeptiert höchstens 0,1 ms; 0,01 ms ist der getestete Referenzwert. Simulationen mit mehr als 1.000.000 Schritten werden abgewiesen, um Speicherbedarf und Laufzeit zu begrenzen.

## Wissenschaftliche Grenze

Die Regressionstests prüfen interne numerische Eigenschaften. Sie sind keine experimentelle Validierung. Ein belastbarer Multi-Kompartiment-Ausbau muss Morphologie und axiale Kopplung definieren, validierte Kanalverteilungen verwenden, einen geeigneten ODE-Löser einsetzen, Parameterquellen dokumentieren, veröffentlichte Messkurven vergleichen und Konvergenz-, Sensitivitäts- sowie Unsicherheitsanalysen enthalten.

Die vollständige Einordnung steht in [Biologisch plausible Neuronenmodelle](biologisch-plausible-neuronenmodelle.md).
