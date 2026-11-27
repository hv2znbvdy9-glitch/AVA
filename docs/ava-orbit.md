# AVA Orbit · 01610–15769

Kostenloser 3D-Globus mit öffentlichen Satelliten-Bahnelementen von CelesTrak. Die erste Version zeigt die Gruppe **Space stations**: Auswahl und Suche nach Name/NORAD-ID, SGP4-Positionen, Bahnkurve ±45 Minuten, Zeitversatz ±90 Minuten, Pause, 2D-Karte und CSV-Export.

## Start auf Windows, Linux und macOS

Voraussetzung: Node.js LTS und ein aktueller Browser mit WebGL. Im Repository:

```sh
npm run orbit:start
```

Danach **http://127.0.0.1:4173** im Browser öffnen. Unter Windows alternativ `scripts\START_AVA_ORBIT.cmd` doppelt anklicken. Der Server bleibt bis Strg+C aktiv. Er bindet nur an die Loopback-Adresse; keine Administratorrechte, Installation zusätzlicher npm-Pakete oder Firewalländerungen nötig. Ein anderer Port ist mit `AVA_ORBIT_PORT` möglich; die Konsole zeigt die tatsächlich verwendete Adresse.

Die Browser-Dateien in `web/ava-orbit/` lassen sich auch auf einem statischen HTTPS-Host veröffentlichen. Kein API-Schlüssel und kein Cesium-ion-Konto erforderlich. Die GitHub-Actions-Tests prüfen Software auf GitHub-Runnern; sie starten nichts auf einem persönlichen Laptop.

## Daten und Aussagegrenzen

- Quelle: [CelesTrak GP data, Stations, CSV](https://celestrak.org/NORAD/elements/gp.php?GROUP=stations&FORMAT=csv). Abrufzeit, Original-CSV und dessen SHA-256 stehen in `data/stations.json`.
- Die mitgelieferte Momentaufnahme stammt vom 24.11.2026 (UTC). Sie ist ein Startdatenstand, kein automatisch gepflegter Live-Feed.
- **Bahnepoche** ist der Bezugszeitpunkt der Bahnelemente. **Abrufzeit** ist der Zeitpunkt des Downloads. **Darstellungszeit** ist der gewählte Zeitpunkt der Berechnung.
- Positionen werden mit SGP4 berechnet, nicht gemessen. Koordinaten sind geodätische Breite/Länge; Höhe in Kilometern über dem Referenzellipsoid, Geschwindigkeit als Betrag im Inertialsystem in km/s. Die Umlaufdauer wird aus der mittleren Bewegung abgeleitet.
- Nach 48 Stunden seit Bahnepoche erscheint ein Altershinweis. Mehr als sieben Tage Abstand zwischen Darstellungszeit und Bahnepoche werden nicht propagiert. Diese Grenzen sind Anzeigegrenzen und keine Genauigkeitsgarantie. Manöver können die Vorhersage schon früher verschlechtern.
- Katalogdaten zeigen weder vollständige Satellitenbestände noch Sensoraufnahmen oder Personen. Ein Überflug identifiziert kein Beobachtungsziel.
- Zusammen fliegende Module haben teilweise identische Bahnelemente und überlagern sich deshalb.

## Aktualisierung und Fehlerverhalten

„Daten aktualisieren“ lädt ausschließlich den festen CelesTrak-Endpoint. Der Browser speichert den letzten erfolgreichen Datenstand und den Zeitpunkt des letzten Abrufversuchs. Maximal ein Versuch pro zwei Stunden pro Browser; auch Fehler führen zu dieser Pause. Es gibt keine Hintergrundabfragen, solange die Seite geschlossen ist. Das schützt die öffentliche Quelle; es ist kein serverweiter Rate-Limiter. [CelesTrak-Nutzungshinweise](https://celestrak.org/NORAD/elements/)

Bei Netzwerk-, CORS- oder HTTP-Fehlern bleibt der vorhandene Datenstand stehen. Ein ungültiger Download ersetzt ihn nicht. Wenn der Browser lokale Speicherung sperrt, funktionieren Anzeige und Export für die Sitzung; der Abrufzeitpunkt kann dann nach Neuladen nicht erhalten bleiben. Ungültige CSV-Zeilen werden gezählt und ausgelassen. Bei mehr als sieben Tage alten Bahnelementen können neue Daten nötig sein, bevor wieder Positionen erscheinen.

## Bibliotheken und Grundkarte

- [CesiumJS 1.146](https://github.com/CesiumGS/cesium), Apache-2.0: JavaScript, Widgets und Natural Earth II aus dem offiziellen Cesium-CDN. Bei blockiertem CDN/WebGL bleibt die numerische Auswertung verfügbar. Keine kostenpflichtigen ion-Assets, kein Geländemodell; verwendet wird ein Ellipsoid.
- [satellite.js 6.0.1](https://github.com/shashwatak/satellite-js), MIT: unveränderte UMD-Datei lokal in `vendor/`, Lizenz beigefügt. SHA-256: `6fd7487abb99bec37ea2c8d1f5739b59143a6130a00b0faa6c44dd44585aebbf`.
- Es werden keine Zugangsdaten, Geolokalisierung oder privaten AVA-Systemdaten benötigt. Browseranfragen an Cesium und CelesTrak sind normale externe HTTPS-Anfragen. Der lokale Server stellt nur eine feste Liste von App-Dateien bereit.

## Prüfen

```sh
npm run orbit:test
npm test
```

Die Tests laufen ohne Netzwerkabruf: CSV-Format und Feldvalidierung, sechsstellige NORAD-IDs, deterministische SGP4-Auswertung zur gespeicherten Epoche, Altersgrenze, UTC-Auswertung, Export, Abrufpause sowie lokaler HTTP-Server und Pfadbegrenzung. Die bestehenden CI-Workflows führen `npm test` auch auf Windows aus. Damit wird kein Windows-Laptop ferngesteuert.
