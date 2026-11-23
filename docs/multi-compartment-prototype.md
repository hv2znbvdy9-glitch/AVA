# AVA Multi-Kompartiment-Hodgkin-Huxley-Lehrprototyp

> Projektkontext: AVA 01610 1  
> Autorzuordnung: Danny Nico Hildebrand – Danny Devito

Dieses Modul erweitert den [Einzelkompartiment-Lehrprototypen](hodgkin-huxley-prototype.md)
um eine deterministische, streng begrenzte Kette elektrisch gekoppelter
Hodgkin-Huxley-Kompartimente. Es ist ein ausführbarer Zwischenschritt in
Richtung des in [Biologisch plausible Neuronenmodelle](biologisch-plausible-neuronenmodelle.md)
beschriebenen Ausbaupfads.

Es ist ausdrücklich kein Hay-L5b-Modell, keine NEURON-Simulation, kein
Lernsystem, kein Bewusstsein und kein autonomer AVA- oder JARVIS-Agent.

## Implementierter Umfang

- jedes Kompartiment ist das getestete klassische Einzelkompartiment-Hodgkin-Huxley-Modell
  (Na⁺-, K⁺- und Leckströme mit m-, h- und n-Toren);
- ohmsche axiale Kopplung zwischen frei wählbaren Kompartimentpaaren
  (`from`, `to`, `conductance`);
- kompartimentspezifische Stromeingabe über `current(timeMs, index)`;
- Ableitungen werden netzwerkweit vor jeder Zustandsänderung berechnet, sodass
  das Ergebnis unabhängig von der Kompartimentreihenfolge ist;
- Standardtopologie: stimuliertes Soma (Index 0) mit zwei passiv gekoppelten
  Segmenten;
- dieselben Begrenzungen wie das Einzelkompartiment-Modell: `dt` in
  (0, 0,1] ms, höchstens 1.000.000 Schritte, höchstens 10.000 Kompartimente;
- deterministische Regressionstests für Ruheverhalten, axiale Ausbreitung,
  isolierte Kompartimente, distale Stimulation und Übereinstimmung mit der
  Einzelkompartiment-Referenz bei einem einzelnen Kompartiment.

Nicht implementiert sind rekonstruierte Morphologie, die veröffentlichte
Hay-Modelltopologie und ihre Kanalverteilungen, ein Axoninitialsegment,
Synapsen, Spines, Calcium- oder NMDA-Spikes, Plastizität, Stoffwechsel,
Genexpression, Glia, Lernen oder Agency.

## Ausführen

~~~bash
npm install
npm run neuron:multi
~~~

Direkter lokaler Aufruf:

~~~bash
node ./bin/cli.js --neuron-multi
~~~

Unter Windows PowerShell:

~~~powershell
node .\bin\cli.js --neuron-multi
~~~

Die Demonstration simuliert drei gekoppelte Kompartimente über 30 ms mit dem
getesteten Zeitschritt 0,01 ms und meldet die Spannungshöchstwerte je
Kompartiment. Sie führt keine Netzwerk-, Betriebssystem-, Persistenz- oder
Geräteaktion aus.

## Bibliotheksnutzung

~~~js
const {simulateMultiCompartment} = require('ava');

const trace = simulateMultiCompartment({
  durationMs: 30,
  dt: 0.01,
  compartments: [{}, {}, {}],
  connections: [
    {from: 0, to: 1, conductance: 1},
    {from: 1, to: 2, conductance: 1},
  ],
  current: (timeMs, index) => (index === 0 && timeMs >= 5 && timeMs < 25 ? 10 : 0),
});

console.log(trace[0].compartments.length); // 3
console.log(Math.max(...trace.map((s) => s.compartments[0].voltage)));
~~~

Die Einheiten folgen der klassischen Formulierung: Zeit in ms, Spannung in mV,
Kapazität in μF/cm², Leitfähigkeit in mS/cm² und Stromdichte in μA/cm². Die
axiale Kopplungsleitfähigkeit ist ein Modellparameter des Prototyps und kein
aus einer Morphologie abgeleiteter Messwert.

## Wissenschaftliche Grenze

Die Regressionstests prüfen interne numerische Eigenschaften: Ruhestabilität,
endliche Werte, Torbereiche, axiale Ausbreitung und Übereinstimmung mit der
Einzelkompartiment-Referenz. Sie sind keine experimentelle Validierung. Die
gekoppelte Kette zeigt das Rechenprinzip der Kabelgleichung, bildet aber keine
ortsabhängigen Kanaldichten, keine dendritischen Calciumspikes und keine
rücklaufenden Aktionspotenziale einer realen Pyramidenzelle ab.

Die vollständige Einordnung und die Anforderungen an einen belastbaren
Multi-Kompartiment-Ausbau stehen in
[Biologisch plausible Neuronenmodelle](biologisch-plausible-neuronenmodelle.md),
Abschnitt 6.
