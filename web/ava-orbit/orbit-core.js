'use strict';

// Shared browser/Node logic. No network, DOM, or clock side effects.
(function(root, factory) {
	if (typeof module === 'object' && module.exports) module.exports = factory();
	else root.AvaOrbit = factory();
}(typeof globalThis !== 'undefined' ? globalThis : this, function() {
	const SOURCE = 'https://celestrak.org/NORAD/elements/gp.php?GROUP=stations&FORMAT=csv';
	const REFRESH_MS = 2 * 60 * 60 * 1000;
	const MAX_AGE_MS = 7 * 24 * 60 * 60 * 1000;
	const MAX_BYTES = 1000000;
	const FIELDS = ['MEAN_MOTION', 'ECCENTRICITY', 'INCLINATION', 'RA_OF_ASC_NODE',
		'ARG_OF_PERICENTER', 'MEAN_ANOMALY', 'EPHEMERIS_TYPE', 'ELEMENT_SET_NO',
		'REV_AT_EPOCH', 'BSTAR', 'MEAN_MOTION_DOT', 'MEAN_MOTION_DDOT'];

	function parseCsv(text) {
		if (typeof text !== 'string' || text.length > MAX_BYTES) throw new Error('CSV fehlt oder ist zu groß.');
		const rows = [];
		let row = [], field = '', quoted = false, closed = false;
		text = text.replace(/^\uFEFF/, '');
		for (let i = 0; i <= text.length; i++) {
			const c = text[i];
			if (quoted) {
				if (c === undefined) throw new Error('CSV enthält ein offenes Anführungszeichen.');
				if (c === '"' && text[i + 1] === '"') { field += '"'; i++; }
				else if (c === '"') { quoted = false; closed = true; }
				else field += c;
			} else if (c === '"' && !field && !closed) quoted = true;
			else if (c === ',' || c === '\r' || c === '\n' || c === undefined) {
				row.push(field); field = ''; closed = false;
				if (c !== ',') {
					if (row.some(value => value.trim())) rows.push(row);
					row = [];
					if (c === '\r' && text[i + 1] === '\n') i++;
				}
			} else {
				if (closed || c === '"') throw new Error('Ungültige CSV-Formatierung.');
				field += c;
			}
		}
		return rows;
	}

	function epochMs(value) {
		if (typeof value !== 'string' || !/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?Z?$/.test(value)) return NaN;
		return Date.parse(value.endsWith('Z') ? value : value + 'Z');
	}

	function parseElements(text) {
		const [headers, ...rows] = parseCsv(text);
		const required = ['OBJECT_NAME', 'OBJECT_ID', 'EPOCH', 'NORAD_CAT_ID', ...FIELDS];
		if (!headers || new Set(headers).size !== headers.length || required.some(k => !headers.includes(k))) {
			throw new Error('Die Datei enthält keine unterstützten CelesTrak-CSV-Bahnelemente.');
		}
		if (rows.length > 1000) throw new Error('Zu viele Objekte für diese Stationsansicht.');
		const records = [], rejected = [];
		const ids = new Set();
		for (const [index, row] of rows.entries()) {
			const record = Object.create(null);
			headers.forEach((h, i) => { record[h] = row[i]; });
			const id = String(record.NORAD_CAT_ID || '');
			const validNumbers = FIELDS.every(k => record[k] !== undefined && record[k].trim() !== '' && Number.isFinite(Number(record[k])));
			if (row.length !== headers.length || !validNumbers || !/^[1-9]\d{0,8}$/.test(id) ||
				!record.OBJECT_NAME || record.OBJECT_NAME.length > 120 || !Number.isFinite(epochMs(record.EPOCH)) ||
				Number(record.MEAN_MOTION) <= 0 || Number(record.MEAN_MOTION) > 20 ||
				Number(record.ECCENTRICITY) < 0 || Number(record.ECCENTRICITY) >= 1 ||
				Number(record.INCLINATION) < 0 || Number(record.INCLINATION) > 180 ||
				['RA_OF_ASC_NODE', 'ARG_OF_PERICENTER', 'MEAN_ANOMALY'].some(k => Number(record[k]) < 0 || Number(record[k]) >= 360) || ids.has(id)) {
				rejected.push(index + 2); continue;
			}
			FIELDS.forEach(k => { record[k] = Number(record[k]); });
			record.NORAD_CAT_ID = Number(id);
			record.EPOCH = new Date(epochMs(record.EPOCH)).toISOString();
			ids.add(id);
			records.push(record);
		}
		if (!records.length) throw new Error('Keine gültigen Bahnelemente in der Datei.');
		return {records, rejected};
	}

	function validateSnapshot(value) {
		if (!value || value.schemaVersion !== 1 || value.source !== SOURCE || !Number.isFinite(Date.parse(value.retrievedAt))) {
			throw new Error('Ungültiger Datenstand.');
		}
		return {...value, ...parseElements(value.csv)};
	}

	function canRefresh(lastAttempt, now) {
		return !Number.isFinite(lastAttempt) || now < lastAttempt || now - lastAttempt >= REFRESH_MS;
	}

	function positionAt(record, satrec, date, satellite) {
		const time = date.getTime();
		if (!Number.isFinite(time) || Math.abs(time - epochMs(record.EPOCH)) > MAX_AGE_MS) return null;
		try {
			const result = satellite.propagate(satrec, date);
			if (!result || !result.position || !result.velocity || satrec.error) return null;
			const p = result.position, v = result.velocity;
			if (![p.x, p.y, p.z, v.x, v.y, v.z].every(Number.isFinite)) return null;
			const gmst = satellite.gstime(date);
			const geo = satellite.eciToGeodetic(p, gmst);
			const ecf = satellite.eciToEcf(p, gmst);
			const out = {latitude: geo.latitude * 180 / Math.PI, longitude: geo.longitude * 180 / Math.PI,
				altitudeKm: geo.height, speedKmS: Math.hypot(v.x, v.y, v.z),
				x: ecf.x * 1000, y: ecf.y * 1000, z: ecf.z * 1000};
			return Object.values(out).every(Number.isFinite) && out.altitudeKm >= 0 ? out : null;
		} catch (_) { return null; }
	}

	function csvCell(value) {
		let text = String(value ?? '');
		if (/^[\s]*[=+@-]/.test(text)) text = "'" + text;
		return '"' + text.replace(/"/g, '""') + '"';
	}

	function exportCsv(data) {
		const keys = ['name', 'noradId', 'timeUtc', 'epochUtc', 'retrievedAt', 'latitude', 'longitude', 'altitudeKm', 'speedKmS', 'source', 'method'];
		return keys.join(',') + '\r\n' + keys.map(k => csvCell(data[k])).join(',') + '\r\n';
	}

	return {SOURCE, REFRESH_MS, MAX_AGE_MS, MAX_BYTES, parseCsv, parseElements, epochMs, validateSnapshot, canRefresh, positionAt, exportCsv};
}));
