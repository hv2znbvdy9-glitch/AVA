'use strict';

const http = require('http');
const fs = require('fs');
const path = require('path');

const ROOT = path.resolve(__dirname, '../web/ava-orbit');
const FILES = new Map([
	['/', ['index.html', 'text/html']], ['/index.html', ['index.html', 'text/html']],
	['/styles.css', ['styles.css', 'text/css']], ['/app.js', ['app.js', 'text/javascript']],
	['/orbit-core.js', ['orbit-core.js', 'text/javascript']],
	['/data/stations.json', ['data/stations.json', 'application/json']],
	['/vendor/satellite.min.js', ['vendor/satellite.min.js', 'text/javascript']],
	['/vendor/satellite-LICENSE.md', ['vendor/satellite-LICENSE.md', 'text/plain']]
]);

function createServer() {
	return http.createServer((req, res) => {
		res.setHeader('X-Content-Type-Options', 'nosniff');
		res.setHeader('Referrer-Policy', 'no-referrer');
		res.setHeader('Cache-Control', 'no-cache');
		if (!['GET', 'HEAD'].includes(req.method)) {
			res.writeHead(405, {Allow: 'GET, HEAD'}); res.end(); return;
		}
		const pathname = (req.url || '').split('?')[0];
		if (pathname === '/health') {
			res.writeHead(200, {'Content-Type': 'application/json'});
			res.end(req.method === 'HEAD' ? undefined : JSON.stringify({app: 'AVA Orbit', status: 'ok'})); return;
		}
		const entry = FILES.get(pathname);
		if (!entry) { res.writeHead(404); res.end('Not found'); return; }
		fs.readFile(path.join(ROOT, entry[0]), (error, data) => {
			if (error) { res.writeHead(500); res.end('Asset unavailable'); return; }
			res.writeHead(200, {'Content-Type': entry[1] + '; charset=utf-8'});
			res.end(req.method === 'HEAD' ? undefined : data);
		});
	});
}

if (require.main === module) {
	const port = Number(process.env.AVA_ORBIT_PORT || 4173);
	if (!Number.isInteger(port) || port < 1 || port > 65535) {
		console.error('AVA_ORBIT_PORT muss zwischen 1 und 65535 liegen.'); process.exitCode = 1;
	} else {
		const server = createServer();
		server.on('error', error => { console.error('AVA Orbit: ' + error.message); process.exitCode = 1; });
		server.listen(port, '127.0.0.1', () => console.log('AVA Orbit: http://127.0.0.1:' + port + '\nNur auf diesem Rechner. Beenden mit Strg+C.'));
	}
}

module.exports = {createServer};
