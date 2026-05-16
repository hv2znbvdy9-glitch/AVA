'use strict';

const assert = require('assert');
const fs = require('fs');
const os = require('os');
const path = require('path');

const {runSafeLocalNode} = require('../src/safe-local-node');

let passed = 0;
let failed = 0;

function test(name, fn) {
try {
fn();
passed++;
console.log(`  ✓ ${name}`);
} catch (error) {
failed++;
console.error(`  ✗ ${name}`);
console.error(`    ${error.message}`);
}
}

function makeTempRoot() {
return fs.mkdtempSync(path.join(os.tmpdir(), 'ava-safe-local-'));
}

function readJson(filePath) {
return JSON.parse(fs.readFileSync(filePath, 'utf8'));
}

console.log('safe local node tests\n');

test('runSafeLocalNode should create snapshot, analysis, portal and state files', () => {
const root = makeTempRoot();
const result = runSafeLocalNode({root});

assert.ok(fs.existsSync(result.paths.snapshotJson));
assert.ok(fs.existsSync(result.paths.analysisJson));
assert.ok(fs.existsSync(result.paths.portalHtml));
assert.ok(fs.existsSync(result.paths.tangleLog));
assert.ok(fs.existsSync(result.paths.tangleState));
assert.ok(fs.existsSync(result.paths.baselinePath));

const snapshot = readJson(result.paths.snapshotJson);
const analysis = readJson(result.paths.analysisJson);
assert.strictEqual(snapshot.mode, 'LOCAL_DEFENSIVE_READ_ONLY');
assert.strictEqual(analysis.principles, 'LOCAL / DEFENSIVE / READ-ONLY / NO AUTO-SPREAD');
});

test('runSafeLocalNode should append tangle entries with a hash chain', () => {
const root = makeTempRoot();
const first = runSafeLocalNode({root});
const second = runSafeLocalNode({root});

const lines = fs.readFileSync(second.paths.tangleLog, 'utf8').trim().split('\n').filter(Boolean);
assert.strictEqual(lines.length, 2);

const firstEntry = JSON.parse(lines[0]);
const secondEntry = JSON.parse(lines[1]);
assert.ok(firstEntry.hash);
assert.strictEqual(secondEntry.previous_hash, firstEntry.hash);
});

console.log(`\n${passed} passing, ${failed} failing`);
process.exit(failed > 0 ? 1 : 0);
