'use strict';

const crypto = require('crypto');
const fs = require('fs');
const os = require('os');
const path = require('path');

function ensureDir(dirPath) {
if (!fs.existsSync(dirPath)) {
fs.mkdirSync(dirPath, {recursive: true});
}
}

function htmlEncode(value) {
if (value === null || value === undefined) {
return '';
}

return String(value)
.replace(/&/g, '&amp;')
.replace(/</g, '&lt;')
.replace(/>/g, '&gt;')
.replace(/"/g, '&quot;')
.replace(/'/g, '&#39;');
}

function sha256Text(text) {
return crypto.createHash('sha256').update(text, 'utf8').digest('hex');
}

function writeJsonLine(filePath, object) {
fs.appendFileSync(filePath, `${JSON.stringify(object)}\n`, 'utf8');
}

function readJsonFile(filePath) {
if (!fs.existsSync(filePath)) {
return null;
}

try {
return JSON.parse(fs.readFileSync(filePath, 'utf8'));
} catch {
return null;
}
}

function toIso(nowProvider) {
return nowProvider().toISOString();
}

function normalizeInterfaces(networkInterfaces) {
const rows = [];
for (const [name, values] of Object.entries(networkInterfaces || {})) {
for (const info of values || []) {
rows.push({
name,
family: info.family,
address: info.address,
netmask: info.netmask,
mac: info.mac,
internal: Boolean(info.internal),
cidr: info.cidr || '',
});
}
}

return rows;
}

function buildSnapshot(nowProvider) {
const cpus = os.cpus();

return {
time: toIso(nowProvider),
computer: os.hostname(),
user: os.userInfo().username,
mode: 'LOCAL_DEFENSIVE_READ_ONLY',
defender: {
status: 'unknown',
reason: 'Windows Defender status is not collected by this Node.js safe local mode.',
},
firewall: {
status: 'unknown',
reason: 'Firewall profile status is not collected by this Node.js safe local mode.',
},
system: {
platform: process.platform,
release: os.release(),
arch: process.arch,
node: process.version,
uptime_seconds: os.uptime(),
total_memory_bytes: os.totalmem(),
free_memory_bytes: os.freemem(),
cpu_count: cpus.length,
},
processes: [{
pid: process.pid,
ppid: process.ppid,
title: process.title,
execPath: process.execPath,
argv: process.argv,
}],
connections: [],
network: {
interfaces: normalizeInterfaces(os.networkInterfaces()),
},
wlan: [],
};
}

function saveBaseline(filePath, snapshot) {
fs.writeFileSync(filePath, JSON.stringify(snapshot, null, 2), 'utf8');
}

function loadBaseline(filePath) {
return readJsonFile(filePath);
}

function addAlert(severity, title, message, score, data, nowProvider) {
return {
time: toIso(nowProvider),
severity,
title,
message,
score,
data,
};
}

function buildAnalysis(snapshot, baseline, nowProvider) {
const alerts = [];
let score = 0;

if (snapshot.system.free_memory_bytes < 128 * 1024 * 1024) {
score += 20;
alerts.push(addAlert('LOW', 'Low free memory', 'System free memory is below 128MB.', 20, {
free_memory_bytes: snapshot.system.free_memory_bytes,
}, nowProvider));
}

const delta = {
baseline_exists: Boolean(baseline),
new_network_interfaces: [],
};

if (baseline) {
const oldInterfaceKeys = new Set(
(baseline.network && baseline.network.interfaces ? baseline.network.interfaces : [])
.map((item) => `${item.name}|${item.address}|${item.mac}`)
);

for (const current of snapshot.network.interfaces) {
const key = `${current.name}|${current.address}|${current.mac}`;
if (!oldInterfaceKeys.has(key)) {
delta.new_network_interfaces.push(current);
score += 5;
}
}
}

return {
time: toIso(nowProvider),
score: Math.min(score, 999),
alert_count: alerts.length,
alerts,
delta,
principles: 'LOCAL / DEFENSIVE / READ-ONLY / NO AUTO-SPREAD',
core_sentence: 'Fakten vor Angst. Baseline vor Chaos. Sichtbarkeit vor Kontrolle.',
};
}

function toRows(items, props, colSpan) {
if (!items || items.length === 0) {
return `<tr><td colspan="${colSpan}" style="color:#8fa3ad;">Keine Daten gefunden.</td></tr>`;
}

return items.map((item) => {
const cells = props.map((prop) => `<td>${htmlEncode(item[prop])}</td>`).join('');
return `<tr>${cells}</tr>`;
}).join('\n');
}

function renderPortal(snapshot, analysis, tangleState) {
const health = analysis.score >= 500 ? 'CRITICAL' : analysis.score >= 300 ? 'HIGH' : analysis.score >= 150 ? 'WARN' : 'OK';
const alertRows = analysis.alerts.length === 0 ?
'<tr><td colspan="5" style="color:#8fa3ad;">Keine Alerts gefunden.</td></tr>' :
analysis.alerts.map((alert) => `<tr><td>${htmlEncode(alert.severity)}</td><td>${htmlEncode(alert.title)}</td><td>${htmlEncode(alert.message)}</td><td>${htmlEncode(alert.score)}</td><td>${htmlEncode(alert.time)}</td></tr>`).join('\n');
const interfaceRows = toRows(snapshot.network.interfaces.slice(0, 100), ['name', 'family', 'address', 'netmask', 'mac', 'internal', 'cidr'], 7);
const processRows = toRows(snapshot.processes.slice(0, 100), ['title', 'pid', 'ppid', 'execPath', 'argv'], 5);

return `<!doctype html>
<html lang="de">
<head>
<meta charset="utf-8">
<meta http-equiv="refresh" content="60">
<title>AVA 3.14 SAFE LOCAL NODE</title>
<style>
body{font-family:Consolas,"Segoe UI",monospace;background:#05080c;color:#eaf6ff;padding:30px}
.card{background:#0c1520dd;border:1px solid #17384f;padding:16px;margin:12px 0}
.big{font-size:30px;color:#22a7ff}
table{width:100%;border-collapse:collapse}
th,td{padding:8px;border-bottom:1px solid rgba(255,255,255,.08);text-align:left;vertical-align:top;font-size:12px}
th{color:#22a7ff}
.status-OK{color:#19ff8f}.status-WARN{color:#ffcc66}.status-HIGH,.status-CRITICAL{color:#ff5d6c}
.hash{word-break:break-all;color:#8fa3ad}
</style>
</head>
<body>
<div class="card"><b>AVA 3.14 SAFE LOCAL NODE</b> · LOCAL / DEFENSIVE / READ-ONLY</div>
<div class="card"><div class="big status-${health}">${health}</div><div>Score: ${analysis.score} · Alerts: ${analysis.alert_count}</div></div>
<div class="card"><b>Kernsatz:</b> ${htmlEncode(analysis.core_sentence)}</div>
<div class="card"><b>Tangle Last Hash:</b><div class="hash">${htmlEncode(tangleState.last_hash || 'N/A')}</div></div>
<div class="card"><h2>Alerts</h2><table><tbody><tr><th>Severity</th><th>Title</th><th>Message</th><th>Score</th><th>Time</th></tr>
${alertRows}
</tbody></table></div>
<div class="card"><h2>Network Interfaces</h2><table><tbody><tr><th>Name</th><th>Family</th><th>Address</th><th>Netmask</th><th>MAC</th><th>Internal</th><th>CIDR</th></tr>
${interfaceRows}
</tbody></table></div>
<div class="card"><h2>Process View</h2><table><tbody><tr><th>Title</th><th>PID</th><th>PPID</th><th>ExecPath</th><th>Args</th></tr>
${processRows}
</tbody></table></div>
</body>
</html>`;
}

function writeTangle(tangleLogPath, tangleStatePath, event, nowProvider) {
const previous = readJsonFile(tangleStatePath);
const payload = {
time: toIso(nowProvider),
computer: event.computer,
user: event.user,
type: event.type,
summary: event.summary,
previous_hash: previous ? previous.last_hash : null,
data: event.data,
};

const hash = sha256Text(JSON.stringify(payload));
payload.hash = hash;
writeJsonLine(tangleLogPath, payload);

const state = {
updated: toIso(nowProvider),
last_hash: hash,
};

fs.writeFileSync(tangleStatePath, JSON.stringify(state, null, 2), 'utf8');
return state;
}

function runSafeLocalNode(options = {}) {
const nowProvider = typeof options.now === 'function' ? options.now : () => new Date();
const root = options.root || path.join(os.homedir(), 'Desktop', 'AVA_3_14_SAFE_LOCAL_NODE');
const logDir = path.join(root, 'Logs');
const stateDir = path.join(root, 'State');
const reportDir = path.join(root, 'Reports');
const portalDir = path.join(root, 'Portal');

for (const dirPath of [root, logDir, stateDir, reportDir, portalDir]) {
ensureDir(dirPath);
}

const paths = {
root,
snapshotJson: path.join(reportDir, 'snapshot_latest.json'),
analysisJson: path.join(reportDir, 'analysis_latest.json'),
alertLog: path.join(logDir, 'alerts.jsonl'),
eventLog: path.join(logDir, 'events.jsonl'),
tangleLog: path.join(logDir, 'tangle.jsonl'),
tangleState: path.join(stateDir, 'tangle_state.json'),
baselinePath: path.join(stateDir, 'baseline.json'),
portalHtml: path.join(portalDir, 'index.html'),
};

const snapshot = buildSnapshot(nowProvider);
const baseline = loadBaseline(paths.baselinePath);
const analysis = buildAnalysis(snapshot, baseline, nowProvider);

if (!baseline) {
saveBaseline(paths.baselinePath, snapshot);
}

for (const alert of analysis.alerts) {
writeJsonLine(paths.alertLog, alert);
}

writeJsonLine(paths.eventLog, snapshot);
fs.writeFileSync(paths.snapshotJson, JSON.stringify(snapshot, null, 2), 'utf8');
fs.writeFileSync(paths.analysisJson, JSON.stringify(analysis, null, 2), 'utf8');

const tangleState = writeTangle(paths.tangleLog, paths.tangleState, {
computer: snapshot.computer,
user: snapshot.user,
type: 'AVA_3_14_SAFE_LOCAL_NODE',
summary: 'Lokaler defensiver Snapshot erstellt',
data: {
time: snapshot.time,
computer: snapshot.computer,
user: snapshot.user,
score: analysis.score,
alert_count: analysis.alert_count,
mode: 'LOCAL_DEFENSIVE_READ_ONLY_NO_AUTOSPREAD',
},
}, nowProvider);

const html = renderPortal(snapshot, analysis, tangleState);
fs.writeFileSync(paths.portalHtml, html, 'utf8');

return {snapshot, analysis, paths, tangleState};
}

module.exports = {runSafeLocalNode};
