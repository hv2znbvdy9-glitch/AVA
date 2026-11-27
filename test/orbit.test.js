'use strict';

const assert = require('assert');
const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const core = require('../web/ava-orbit/orbit-core');
const satellite = require('../web/ava-orbit/vendor/satellite.min');
const {createServer} = require('../src/orbit-server');
const snapshot = require('../web/ava-orbit/data/stations.json');

function get(port, requestPath, method = 'GET') {
	return new Promise((resolve, reject) => {
		const request = http.request({host: '127.0.0.1', port, path: requestPath, method}, response => {
			const chunks = [];
			response.on('data', chunk => chunks.push(chunk));
			response.on('end', () => resolve({status: response.statusCode, headers: response.headers, body: Buffer.concat(chunks).toString()}));
		});
		request.on('error', reject); request.end();
	});
}

(async function() {
	assert.deepStrictEqual(core.parseCsv('\uFEFFname,id\r\n"A, \"\"B\"\"",123\r\n'), [['name', 'id'], ['A, "B"', '123']]);
	assert.throws(() => core.parseCsv('"unterminated'), /offenes/);
	assert.throws(() => core.parseCsv('"value"trailing'), /Formatierung/);
	assert.throws(() => core.parseCsv('x'.repeat(core.MAX_BYTES + 1)), /groß/);
	assert.throws(() => core.parseElements('<html>upstream unavailable</html>'), /Bahnelemente/);
	assert.throws(() => core.validateSnapshot({...snapshot, source: 'https://example.com/'}), /Datenstand/);
	assert.throws(() => core.validateSnapshot({...snapshot, retrievedAt: 'invalid'}), /Datenstand/);
	assert.strictEqual(crypto.createHash('sha256').update(snapshot.csv).digest('hex'), snapshot.sha256);
	const {records} = core.validateSnapshot(snapshot);
	assert(records.length > 0);
	const iss = records.find(r => r.NORAD_CAT_ID === 25544);
	assert(iss, 'The recorded fixture must contain ISS');
	const epoch = new Date(iss.EPOCH);
	const p = core.positionAt(iss, satellite.json2satrec(iss), epoch, satellite);
	assert(p && p.altitudeKm > 300 && p.altitudeKm < 500 && p.speedKmS > 7 && p.speedKmS < 8);
	// Published fixture is deterministic at its epoch, independent of test runner clock/timezone.
	assert(Math.abs(p.altitudeKm - 415.9928949237792) < 0.001);
	const later = core.positionAt(iss, satellite.json2satrec(iss), new Date(epoch.getTime() + 60000), satellite);
	assert(later && Math.abs(p.latitude - later.latitude) > .1);
	assert.strictEqual(core.positionAt(iss, satellite.json2satrec(iss), new Date(epoch.getTime() + core.MAX_AGE_MS + 1), satellite), null);
	assert.strictEqual(core.positionAt(iss, satellite.json2satrec(iss), new Date('invalid'), satellite), null);
	assert.strictEqual(core.positionAt(iss, {}, epoch, {propagate() { return {position: {x: NaN}, velocity: {x: 0}}; }}), null);
	const rows = core.parseCsv(snapshot.csv);
	const column = name => rows[0].indexOf(name);
	const join = data => data.map(row => row.join(',')).join('\n');
	const largeId = rows[1].slice(); largeId[column('NORAD_CAT_ID')] = '123456';
	assert.strictEqual(core.parseElements(join([rows[0], largeId])).records[0].NORAD_CAT_ID, 123456);
	const invalid = rows[1].slice(); invalid[column('ECCENTRICITY')] = '1.2';
	const filtered = core.parseElements(join([rows[0], rows[1], invalid]));
	assert.strictEqual(filtered.records.length, 1); assert.deepStrictEqual(filtered.rejected, [3]);
	const missing = rows[1].slice(); missing[column('BSTAR')] = '';
	assert.throws(() => core.parseElements(join([rows[0], missing])), /Keine gültigen/);
	assert.strictEqual(core.epochMs('2026-11-23T11:04:33.960'), Date.parse('2026-11-23T11:04:33.960Z'));
	assert(Number.isNaN(core.epochMs('not a timestamp')));
	assert(core.canRefresh(NaN, 100)); assert(!core.canRefresh(100, 101));
	assert(!core.canRefresh(100, 100 + core.REFRESH_MS - 1)); assert(core.canRefresh(100, 100 + core.REFRESH_MS));
	const csv = core.exportCsv({name: '=HYPERLINK("evil")', noradId: 123456, method: 'calculated'});
	assert(csv.includes('"\'=HYPERLINK(""evil"")"')); assert(csv.includes('"123456"'));
	const library = fs.readFileSync(path.join(__dirname, '../web/ava-orbit/vendor/satellite.min.js'));
	assert.strictEqual(crypto.createHash('sha256').update(library).digest('hex'), '6fd7487abb99bec37ea2c8d1f5739b59143a6130a00b0faa6c44dd44585aebbf');
	const server = createServer();
	await new Promise((resolve, reject) => { server.once('error', reject); server.listen(0, '127.0.0.1', resolve); });
	try {
		assert.strictEqual(server.address().address, '127.0.0.1');
		const port = server.address().port;
		const root = await get(port, '/'); assert.strictEqual(root.status, 200); assert(root.body.includes('AVA Orbit'));
		const health = await get(port, '/health'); assert.strictEqual(JSON.parse(health.body).status, 'ok');
		const data = await get(port, '/data/stations.json'); assert.strictEqual(data.status, 200); core.validateSnapshot(JSON.parse(data.body));
		assert.strictEqual(data.headers['x-content-type-options'], 'nosniff');
		const script = await get(port, '/app.js', 'HEAD'); assert.strictEqual(script.status, 200); assert.strictEqual(script.body, '');
		for (const route of ['/../package.json', '/%2e%2e/package.json', '/.git/config', '/data/../../package.json', '/unknown']) {
			assert.strictEqual((await get(port, route)).status, 404, route);
		}
		assert.strictEqual((await get(port, '/', 'POST')).status, 405);
	} finally { await new Promise(resolve => server.close(resolve)); }
	console.log('AVA Orbit: CSV validation, SGP4 propagation, provenance, stale data, refresh limits, export and local HTTP tests passed.');
}()).catch(error => { console.error(error); process.exitCode = 1; });
