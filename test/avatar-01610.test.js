'use strict';

const assert = require('assert');
const path = require('path');
const {execFileSync} = require('child_process');
const {
	avatar01610Report,
	avatar01610Data,
	AVATAR_01610_LAYERS,
	AVATAR_01610_CYCLE,
	AVATAR_01610_PRINCIPLES,
} = require('../src/avatar-01610');
const library = require('../src');

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

console.log('avatar 01610 tests\n');

test('report distinguishes the metaphor from physical claims', () => {
	const report = avatar01610Report();
	assert.ok(report.includes('Beobachtung → Evidenz → Interpretation'));
	assert.ok(report.includes('Quantenbegriffe'));
	assert.ok(report.includes('keine Behauptung'));
});

test('structured data exposes framework layers and evidence cycle', () => {
	const data = avatar01610Data();
	assert.deepStrictEqual(data.layers, ['physisch', 'mental', 'digital', 'sozial', 'symbolisch']);
	assert.deepStrictEqual(data.cycle, [
		'Beobachtung',
		'Evidenz',
		'Interpretation',
		'Entscheidung',
		'Handlung',
		'Erfahrung',
		'Anpassung',
	]);
	assert.strictEqual(data.quantumIdentity.type, 'Metapher');
	assert.strictEqual(data.quantumIdentity.claimAboutPhysicalCollapse, false);
	assert.strictEqual(data.omniscient, false);
});

test('framework constants are frozen and data results are isolated', () => {
	assert.ok(Object.isFrozen(AVATAR_01610_LAYERS));
	assert.ok(Object.isFrozen(AVATAR_01610_CYCLE));
	assert.ok(Object.isFrozen(AVATAR_01610_PRINCIPLES));
	const data = avatar01610Data();
	data.layers.push('changed');
	data.cycle.pop();
	assert.strictEqual(avatar01610Data().layers.length, AVATAR_01610_LAYERS.length);
	assert.strictEqual(avatar01610Data().cycle.length, AVATAR_01610_CYCLE.length);
});

test('library exports report and structured data functions', () => {
	assert.strictEqual(library.avatar01610Report, avatar01610Report);
	assert.deepStrictEqual(library.avatar01610Data(), avatar01610Data());
});

test('CLI flag and command print the report', () => {
	const cliPath = path.join(__dirname, '..', 'bin', 'cli.js');
	for (const command of ['--avatar-01610', 'avatar-01610']) {
		const stdout = execFileSync(process.execPath, [cliPath, command], {encoding: 'utf8'});
		assert.ok(stdout.includes('AVA 01610 – AVATAR–01610 DEVITO'));
		assert.ok(stdout.includes('Evidenz'));
	}
});

console.log(`\n${passed} passing, ${failed} failing`);
process.exit(failed > 0 ? 1 : 0);
