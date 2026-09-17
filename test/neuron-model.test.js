'use strict';

const assert = require('assert');
const path = require('path');
const {execFileSync} = require('child_process');
const {neuronModelReport, neuronModelData, NEURON_MODEL_REFERENCES} = require('../src/neuron-model');

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

console.log('neuron model tests\n');

test('neuronModelReport should include the multi-compartment HH candidate', () => {
	const report = neuronModelReport();
	assert.ok(report.includes('Multi-Kompartiment-Hodgkin-Huxley-Modell'));
	assert.ok(report.includes('Schicht-5-Pyramidenzelle'));
	assert.ok(report.includes('kein vollständig rekonstruiertes Axon'));
	assert.ok(report.includes('kein experimentell angepasstes Hay-Modell'));
	assert.ok(!report.includes('/home/runner/'));
});

test('neuronModelData should expose candidate and references', () => {
	const data = neuronModelData();
	assert.strictEqual(typeof data.candidate, 'string');
	assert.strictEqual(data.implementation.id, 'ava-neuro-hh-l5-prototype/v1');
	assert.strictEqual(data.references.length, 4);
	assert.ok(data.references.every((item) => typeof item.url === 'string' && item.url.startsWith('https://')));
});

test('NEURON_MODEL_REFERENCES should contain stable source entries', () => {
	assert.strictEqual(NEURON_MODEL_REFERENCES.length, 4);
	assert.ok(NEURON_MODEL_REFERENCES[0].title.includes('Hay et al.'));
});

test('CLI flag --neuron-model should print the report', () => {
	const cliPath = path.join(__dirname, '..', 'bin', 'cli.js');
	const stdout = execFileSync(process.execPath, [cliPath, '--neuron-model'], {encoding: 'utf8'});
	assert.ok(stdout.includes('AVA Neuronenmodell-Analyse'));
});

test('CLI command neuron-model should print the report', () => {
	const cliPath = path.join(__dirname, '..', 'bin', 'cli.js');
	const stdout = execFileSync(process.execPath, [cliPath, 'neuron-model'], {encoding: 'utf8'});
	assert.ok(stdout.includes('DeepDendrite'));
});

console.log(`\n${passed} passing, ${failed} failing`);
process.exit(failed > 0 ? 1 : 0);
