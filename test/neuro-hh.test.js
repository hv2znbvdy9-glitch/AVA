'use strict';

const assert = require('assert');
const crypto = require('crypto');
const fs = require('fs');
const os = require('os');
const path = require('path');

const {
	MODEL_ID,
	COMPARTMENTS,
	COUPLINGS,
	simulateMultiCompartmentHH,
	validateSimulation,
	writeNeuroEvidence,
} = require('../src/neuro-hh');

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
		console.error(`    ${error.stack || error.message}`);
	}
}

function sha256File(filePath) {
	return crypto.createHash('sha256').update(fs.readFileSync(filePath)).digest('hex');
}

console.log('neuro HH tests\n');

test('model should expose seven coupled compartments and active channel gradients', () => {
	assert.strictEqual(COMPARTMENTS.length, 7);
	assert.strictEqual(COUPLINGS.length, 6);
	assert.ok(COMPARTMENTS.find((item) => item.id === 'ais').gNa > COMPARTMENTS.find((item) => item.id === 'soma').gNa);
	assert.ok(COMPARTMENTS.find((item) => item.id === 'apical_distal').gCa > COMPARTMENTS.find((item) => item.id === 'soma').gCa);
	assert.ok(COMPARTMENTS.find((item) => item.id === 'tuft').gH > COMPARTMENTS.find((item) => item.id === 'soma').gH);
});

test('rest protocol should remain finite and subthreshold', () => {
	const result = simulateMultiCompartmentHH({protocol: 'rest'});
	const validation = validateSimulation(result);
	assert.strictEqual(result.model.id, MODEL_ID);
	assert.deepStrictEqual(validation, {ok: true, issues: []});
	assert.strictEqual(result.summary.spike_count, 0);
	assert.ok(result.summary.peak_voltage_mv.soma < -50);
});

test('somatic step should produce a propagated action potential', () => {
	const result = simulateMultiCompartmentHH({protocol: 'somatic-step'});
	assert.ok(result.summary.spike_count >= 1);
	assert.ok(result.summary.peak_voltage_mv.soma > 0);
	assert.ok(result.summary.peak_voltage_mv.apical_trunk > -20);
});

test('distal pulse should produce a local calcium event and influence the soma', () => {
	const result = simulateMultiCompartmentHH({protocol: 'distal-pulse'});
	assert.ok(result.summary.dendritic_calcium_event_count >= 1);
	assert.ok(result.summary.max_calcium_mm.apical_distal > 0.001);
	assert.ok(result.summary.peak_voltage_mv.soma > -20);
});

test('coincidence protocol should be deterministic', () => {
	const first = simulateMultiCompartmentHH({protocol: 'bac-coincidence'});
	const second = simulateMultiCompartmentHH({protocol: 'bac-coincidence'});
	assert.deepStrictEqual(first.summary, second.summary);
	assert.deepStrictEqual(first.trace, second.trace);
});

test('default step size should agree with a two-times finer integration', () => {
	const standard = simulateMultiCompartmentHH({protocol: 'bac-coincidence', dtMs: 0.01});
	const finer = simulateMultiCompartmentHH({protocol: 'bac-coincidence', dtMs: 0.005});
	assert.strictEqual(standard.summary.spike_count, finer.summary.spike_count);
	assert.strictEqual(
		standard.summary.dendritic_calcium_event_count,
		finer.summary.dendritic_calcium_event_count,
	);
	assert.ok(Math.abs(standard.summary.spike_times_ms[0] - finer.summary.spike_times_ms[0]) <= 0.02);
	assert.ok(Math.abs(standard.summary.peak_voltage_mv.soma - finer.summary.peak_voltage_mv.soma) < 0.1);
});

test('invalid configuration should stop before execution', () => {
	assert.throws(
		() => simulateMultiCompartmentHH({protocol: 'unknown'}),
		/Unknown protocol/,
	);
	assert.throws(
		() => simulateMultiCompartmentHH({protocol: 'rest', dtMs: 0.1}),
		/dtMs must be/,
	);
	assert.throws(
		() => simulateMultiCompartmentHH({
			protocol: 'rest',
			stimuli: [{compartment: 'not-a-compartment', startMs: 1, endMs: 2, amplitude: 1}],
		}),
		/Unknown stimulus compartment/,
	);
});

test('evidence writer should preserve separate immutable trigger directories and hashes', () => {
	const outputRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'ava-neuro-hh-'));
	const result = simulateMultiCompartmentHH({protocol: 'bac-coincidence'});
	const now = new Date('2026-09-17T12:00:00.000Z');
	const first = writeNeuroEvidence(result, {
		outputRoot,
		now,
		eventId: 'event-00000001',
	});
	const firstSummaryBefore = fs.readFileSync(first.summaryPath, 'utf8');
	const second = writeNeuroEvidence(result, {
		outputRoot,
		now,
		eventId: 'event-00000002',
	});

	assert.notStrictEqual(first.eventDirectory, second.eventDirectory);
	assert.strictEqual(fs.readFileSync(first.summaryPath, 'utf8'), firstSummaryBefore);
	assert.strictEqual(first.manifest.files[0].sha256, sha256File(first.summaryPath));
	assert.strictEqual(first.manifest.files[1].sha256, sha256File(first.tracePath));
	assert.throws(
		() => writeNeuroEvidence(result, {outputRoot, now, eventId: 'event-00000001'}),
		/EEXIST/,
	);
});

console.log(`\n${passed} passing, ${failed} failing`);
process.exit(failed > 0 ? 1 : 0);
