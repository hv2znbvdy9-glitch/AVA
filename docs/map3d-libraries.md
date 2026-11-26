# Open-Source-Bibliotheken für 3D-Karten und 3D-Globen

> Projektkontext: AVA 01610 1  
> Autorzuordnung: Danny Nico Hildebrand – Danny Devito  
> Status: kuratierte Referenzliste; keine Integration, keine Abhängigkeit

Diese Liste fasst die 16 freien und quelloffenen Bibliotheken und Frameworks
aus dem MEDevel.com-Artikel von Hamza Musa (23. September 2025) zusammen:

<https://medevel.com/16-open-source-library-frameworks-to-build-3d-maps-and-3d-globe/>

AVA bindet keines dieser Projekte ein. Das Modul `src/map3d-libraries.js`
liefert ausschließlich strukturierte Metadaten (Name, Sprache, Laufzeit,
Schwerpunkt, Repository) und einen CLI-Bericht. Es führt keine Netzwerk-,
Betriebssystem- oder Installationsaktionen aus.

## Ausführen

~~~bash
npm run map3d:libraries
~~~

Direkter lokaler Aufruf:

~~~bash
node ./bin/cli.js --map3d-libraries
~~~

## Bibliotheksnutzung

~~~js
const {map3dLibrariesData, map3dLibrariesReport, MAP3D_LIBRARIES} = require('ava');

console.log(MAP3D_LIBRARIES.length); // 16
console.log(map3dLibrariesData().article.author); // "Hamza Musa"
console.log(map3dLibrariesReport());
~~~

## Einordnung der Werkzeuggruppen

- **Browser-Globen und Vektorkarten (WebGL/WebGPU):** CesiumJS, deck.gl,
  Kepler.gl, maprayJS, MapLibre GL JS, OpenGlobus, Tangram, map3d, TerriaJS.
- **Eingebettete und native Renderer:** MapLibre Native, Tangram ES,
  osgEarth, Ascend Maps (Tangram NG), azul (macOS).
- **Wissenschaftliche und robotische 3D-Modelle:** GemPy (geologische
  Strukturmodelle), OctoMap (3D-Belegungskarten für SLAM).
- **Kachel-Infrastruktur:** Martin (Vektorkacheln aus PostGIS/MBTiles).

## Grenzen

Die Einträge sind redaktionelle Metadaten. Sie erheben keinen Anspruch auf
Vollständigkeit, Aktualität der verlinkten Releases oder eine Bewertung der
Projektqualität. Lizenzen, Plattformunterstützung und Funktionsumfang sind im
jeweils verlinkten Projekt zu prüfen, bevor eines davon verwendet wird.
