'use strict';

(async function() {
	const $ = id => document.getElementById(id);
	const core = window.AvaOrbit;
	const storageKey = 'ava-orbit-stations-v1';
	const attemptKey = storageKey + '-attempt';
	const fmt = (value, digits = 2) => Number(value).toLocaleString('de-DE', {minimumFractionDigits: digits, maximumFractionDigits: digits});
	const utc = value => new Date(value).toISOString().replace('T', ' ').slice(0, 19);
	let snapshot, selected, viewer, route, items = [], pausedAt = null, offset = 0, exportData = null;
	let lastPaint = 0, lastPath = 0, busy = false, lastAttempt = NaN, map2d = false;
	try { const saved = localStorage.getItem(attemptKey); if (saved !== null) lastAttempt = Number(saved); } catch (_) { /* Storage is optional. */ }
	const time = () => new Date((pausedAt === null ? Date.now() : pausedAt) + offset * 60000);
	const status = text => { $('data-status').textContent = text; };
	const failGlobe = text => { $('globe-error').textContent = text; $('globe-error').hidden = false; };

	function exportEnabled(value) { $('export').disabled = !value; }
	function updateRefresh() {
		const ready = core.canRefresh(lastAttempt, Date.now());
		$('refresh').disabled = busy || !ready;
		$('refresh').textContent = busy ? 'Lade Bahndaten …' : ready ? 'Daten aktualisieren' : 'Abrufpause · 2 Stunden';
		$('refresh').title = ready ? 'Öffentliche Bahnelemente von CelesTrak laden' : 'Nächster Abruf ab ' + utc(lastAttempt + core.REFRESH_MS) + ' UTC';
	}

	function renderList() {
		const query = $('search').value.trim().toLowerCase();
		const visible = items.filter(item => (item.record.OBJECT_NAME + ' ' + item.record.NORAD_CAT_ID).toLowerCase().includes(query));
		$('objects').replaceChildren();
		$('count').textContent = visible.length + (query ? '/' + items.length : '');
		for (const item of visible) {
			const button = document.createElement('button');
			button.className = 'object'; button.type = 'button';
			button.setAttribute('aria-pressed', String(selected === item));
			const title = document.createElement('span'); title.textContent = item.record.OBJECT_NAME;
			const sub = document.createElement('small'); sub.textContent = 'NORAD ' + item.record.NORAD_CAT_ID;
			button.append(title, sub);
			button.addEventListener('click', () => { select(item); focus(); });
			$('objects').append(button);
		}
		if (!visible.length) {
			const empty = document.createElement('p'); empty.className = 'empty'; empty.textContent = 'Keine passenden Objekte.'; $('objects').append(empty);
		}
	}

	function select(item) {
		selected = item;
		$('selected-name').textContent = item.record.OBJECT_NAME;
		$('selected-id').textContent = 'NORAD ' + item.record.NORAD_CAT_ID + ' · ' + item.record.OBJECT_ID;
		$('inclination').textContent = fmt(item.record.INCLINATION) + '°';
		$('period').textContent = fmt(1440 / item.record.MEAN_MOTION, 1);
		$('epoch').textContent = utc(item.record.EPOCH);
		if (viewer) for (const other of items) {
			other.entity.point.pixelSize = other === item ? 11 : 5;
			other.entity.point.color = other === item ? Cesium.Color.fromCssColorString('#e9c58b') : Cesium.Color.fromCssColorString('#b7f5d4');
			other.entity.label.show = other === item;
		}
		renderList(); lastPath = 0; paint(true);
	}

	function setSnapshot(value, description) {
		const next = core.validateSnapshot(value);
		const oldId = selected?.record.NORAD_CAT_ID || 25544;
		const nextItems = next.records.map(record => ({record, satrec: satellite.json2satrec(record)}));
		if (viewer) viewer.entities.removeAll();
		route = null;
		snapshot = next; items = nextItems;
		if (viewer) for (const item of items) {
			item.entity = viewer.entities.add({id: String(item.record.NORAD_CAT_ID),
				position: Cesium.Cartesian3.ZERO, show: false,
				point: {pixelSize: 5, color: Cesium.Color.fromCssColorString('#b7f5d4'), outlineColor: Cesium.Color.BLACK, outlineWidth: 1},
				label: {text: item.record.OBJECT_NAME, font: '14px sans-serif', show: false,
					pixelOffset: new Cesium.Cartesian2(0, -23), fillColor: Cesium.Color.WHITE,
					showBackground: true, backgroundColor: Cesium.Color.fromCssColorString('#0c1922').withAlpha(.85)}});
		}
		$('retrieved').textContent = utc(snapshot.retrievedAt);
		status(description + ' · ' + items.length + ' Objekte' + (next.rejected.length ? ' · ' + next.rejected.length + ' ungültige Zeilen ausgelassen' : '') + '.');
		select(items.find(item => item.record.NORAD_CAT_ID === oldId) || items[0]);
	}

	function makePath(date) {
		if (!viewer || !selected) return;
		if (route) { viewer.entities.remove(route); route = null; }
		const points = [];
		// Independent satrec for samples: deep-space propagation may mutate internal state.
		const satrec = satellite.json2satrec(selected.record);
		for (let minute = -45; minute <= 45; minute += 1) {
			const p = core.positionAt(selected.record, satrec, new Date(date.getTime() + minute * 60000), satellite);
			if (p) points.push(new Cesium.Cartesian3(p.x, p.y, p.z));
		}
		if (points.length > 1) route = viewer.entities.add({polyline: {positions: points, width: 2,
			arcType: Cesium.ArcType.NONE, material: Cesium.Color.fromCssColorString('#e9c58b')}});
	}

	function paint(force = false) {
		const now = Date.now();
		if (!force && now - lastPaint < 1000) return;
		lastPaint = now;
		const date = time();
		$('clock').textContent = utc(date);
		$('time-mode').textContent = (pausedAt !== null ? 'Zeit pausiert' : offset ? 'Zeitversatz aktiv' : 'Aktuelle Zeit') + ' · Positionen berechnet';
		updateRefresh();
		if (!selected) return;
		let point;
		for (const item of items) {
			const p = core.positionAt(item.record, item.satrec, date, satellite);
			if (viewer) { item.entity.show = Boolean(p); if (p) item.entity.position = new Cesium.Cartesian3(p.x, p.y, p.z); }
			if (item === selected) point = p;
		}
		const ageHours = (Date.now() - core.epochMs(selected.record.EPOCH)) / 3600000;
		$('age').textContent = ageHours < 0 ? 'Bahnepoche liegt in der Zukunft' : fmt(ageHours, 1) + ' Stunden seit Bahnepoche' + (ageHours > 48 ? ' · veraltet' : '');
		$('age').classList.toggle('stale', ageHours > 48 || ageHours < 0);
		for (const id of ['altitude', 'speed', 'latitude', 'longitude']) $(id).textContent = '—';
		exportData = null; exportEnabled(false); $('focus').disabled = !viewer || !point;
		if (point) {
			$('altitude').textContent = fmt(point.altitudeKm, 1); $('speed').textContent = fmt(point.speedKmS, 3);
			$('latitude').textContent = fmt(point.latitude, 3) + '°'; $('longitude').textContent = fmt(point.longitude, 3) + '°';
			exportData = {name: selected.record.OBJECT_NAME, noradId: selected.record.NORAD_CAT_ID,
				timeUtc: date.toISOString(), epochUtc: selected.record.EPOCH, retrievedAt: snapshot.retrievedAt,
				latitude: point.latitude, longitude: point.longitude, altitudeKm: point.altitudeKm, speedKmS: point.speedKmS,
				source: core.SOURCE, method: 'SGP4 (satellite.js 6.0.1), calculated; not measured'};
			exportEnabled(true);
		} else $('age').textContent += ' · Für diese Zeit keine gültige Position (max. ±7 Tage)';
		if (force || now - lastPath > 30000) { makePath(date); lastPath = now; }
		if (viewer) { viewer.clock.currentTime = Cesium.JulianDate.fromDate(date); viewer.scene.requestRender(); }
	}

	function focus() {
		if (!viewer || !selected || !exportData) return;
		viewer.camera.flyTo({destination: Cesium.Cartesian3.fromDegrees(exportData.longitude, exportData.latitude, 12000000), duration: window.matchMedia('(prefers-reduced-motion: reduce)').matches ? 0 : 1.2});
	}

	async function refresh() {
		if (busy || !core.canRefresh(lastAttempt, Date.now())) return;
		busy = true; lastAttempt = Date.now();
		try { localStorage.setItem(attemptKey, String(lastAttempt)); } catch (_) { /* Optional. */ }
		updateRefresh();
		const controller = new AbortController();
		const timeout = setTimeout(() => controller.abort(), 15000);
		try {
			const response = await fetch(core.SOURCE, {signal: controller.signal, credentials: 'omit', referrerPolicy: 'no-referrer'});
			if (!response.ok) throw new Error('HTTP ' + response.status);
			const text = await response.text();
			const value = {schemaVersion: 1, source: core.SOURCE, retrievedAt: new Date().toISOString(), csv: text};
			// Validate before replacing the last usable data set.
			core.validateSnapshot(value);
			setSnapshot(value, 'Von CelesTrak abgerufen');
			try { localStorage.setItem(storageKey, JSON.stringify(value)); } catch (_) { status('Abruf erfolgreich. Browser-Speicher nicht verfügbar; Daten gelten für diese Sitzung.'); }
		} catch (_) {
			status('Abruf nicht möglich (Netzwerk, CORS oder Quelle). ' + (snapshot ? 'Gespeicherter Datenstand bleibt erhalten.' : 'Kein Datenstand verfügbar.') + ' Nächster Versuch nach zwei Stunden.');
		} finally { clearTimeout(timeout); busy = false; updateRefresh(); }
	}

	$('search').addEventListener('input', renderList);
	$('refresh').addEventListener('click', refresh);
	$('focus').addEventListener('click', focus);
	$('home').addEventListener('click', () => viewer?.camera.flyTo({destination: Cesium.Cartesian3.fromDegrees(15, 20, 25000000), duration: .7}));
	$('view').addEventListener('click', () => { if (!viewer) return; map2d = !map2d; if (map2d) viewer.scene.morphTo2D(0); else viewer.scene.morphTo3D(0); $('view').textContent = map2d ? '3D-Globus' : '2D-Karte'; });
	$('pause').addEventListener('click', () => { pausedAt = pausedAt === null ? Date.now() : null; $('pause').textContent = pausedAt === null ? 'Zeit pausieren' : 'Zeit fortsetzen'; paint(true); });
	$('offset').addEventListener('input', () => { offset = Number($('offset').value); $('offset-label').textContent = (offset > 0 ? '+' : '') + offset + ' min'; paint(true); });
	$('now').addEventListener('click', () => { offset = 0; pausedAt = null; $('offset').value = 0; $('offset-label').textContent = '0 min'; $('pause').textContent = 'Zeit pausieren'; paint(true); });
	$('export').addEventListener('click', () => {
		if (!exportData) return;
		const url = URL.createObjectURL(new Blob(['\uFEFF' + core.exportCsv(exportData)], {type: 'text/csv;charset=utf-8'}));
		const link = document.createElement('a'); link.href = url;
		link.download = 'AVA-Orbit-' + exportData.noradId + '-' + exportData.timeUtc.replace(/[:.]/g, '-') + '.csv';
		document.body.append(link); link.click(); link.remove(); setTimeout(() => URL.revokeObjectURL(url), 1000);
	});

	if (!window.satellite || !core) { status('Berechnungsbibliothek konnte nicht geladen werden.'); failGlobe('Benötigte Dateien fehlen. Bitte die Seite neu laden.'); return; }
	try {
		if (!window.Cesium) throw new Error('CDN nicht erreichbar');
		Cesium.Ion.defaultAccessToken = '';
		viewer = new Cesium.Viewer('globe', {baseLayer: false, baseLayerPicker: false, geocoder: false,
			timeline: false, animation: false, homeButton: false, sceneModePicker: false, navigationHelpButton: false,
			fullscreenButton: false, selectionIndicator: false, infoBox: false, shouldAnimate: false, showRenderLoopErrors: false,
			terrainProvider: new Cesium.EllipsoidTerrainProvider(), requestRenderMode: true, maximumRenderTimeChange: Infinity});
		viewer.scene.backgroundColor = Cesium.Color.fromCssColorString('#070f18');
		viewer.scene.globe.baseColor = Cesium.Color.fromCssColorString('#23465b');
		viewer.camera.setView({destination: Cesium.Cartesian3.fromDegrees(15, 20, 25000000)});
		$('home').disabled = false; $('view').disabled = false;
		// A delayed basemap must not block the independent catalogue and telemetry.
		Cesium.TileMapServiceImageryProvider.fromUrl(Cesium.buildModuleUrl('Assets/Textures/NaturalEarthII'))
			.then(provider => { viewer.imageryLayers.addImageryProvider(provider); viewer.scene.requestRender(); })
			.catch(() => failGlobe('Grundkarte nicht verfügbar. Bahnen und Positionsdaten bleiben nutzbar.'));
		viewer.screenSpaceEventHandler.setInputAction(click => {
			const picked = viewer.scene.pick(click.position);
			if (picked?.id) { const item = items.find(entry => entry.entity === picked.id); if (item) select(item); }
		}, Cesium.ScreenSpaceEventType.LEFT_CLICK);
	} catch (_) { failGlobe('3D-Ansicht oder Grundkarte nicht verfügbar. Prüfe WebGL und die Verbindung zu cesium.com. Positionsdaten funktionieren unabhängig davon.'); }

	try {
		let cached;
		try { cached = core.validateSnapshot(JSON.parse(localStorage.getItem(storageKey))); } catch (_) { /* Read bundled snapshot instead. */ }
		if (cached) setSnapshot(cached, 'Gespeicherter Browser-Datenstand');
		else {
			const response = await fetch('data/stations.json');
			if (!response.ok) throw new Error('Datenstand fehlt');
			setSnapshot(await response.json(), 'Mitgelieferter Datenstand');
		}
	} catch (_) { status('Kein gültiger Datenstand verfügbar. Bitte „Daten aktualisieren“ verwenden.'); $('objects').textContent = 'Keine Daten geladen.'; }
	updateRefresh(); paint(true);
	setInterval(() => { if (!document.hidden) paint(); }, 1000);
	document.addEventListener('visibilitychange', () => { if (!document.hidden) paint(true); });
}()).catch(() => {
	document.getElementById('data-status').textContent = 'Startfehler. Bitte Seite neu laden oder Browser-Konsole prüfen.';
});
