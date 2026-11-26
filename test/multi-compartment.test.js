'use strict';

const assert = require('assert');
const path = require('path');
const {execFileSync} = require('child_process');
const {MAX_COMPARTMENTS, simulateMultiCompartment} = require('../src/neuron/multi-compartment');
const {simulate} = require('../src/neuron/hodgkin-huxley');

// Default topology: three active HH compartments, only the soma is stimulated.
const trace = simulateMultiCompartment({
	durationMs: 30,
	dt: 0.01,
	current: (timeMs, index) => (index === 0 && timeMs >= 5 && timeMs < 25 ? 10 : 0),
});

assert.strictEqual(trace.length, 3001);
assert.strictEqual(trace[0].compartments.length, 3);
assert.strictEqual(trace[0].timeMs, 0);
assert.ok(Math.abs(trace[trace.length - 1].timeMs - 30) < 1e-9);

// Resting state is preserved without stimulation.
for (const sample of trace.slice(0, 400)) {
	for (const compartment of sample.compartments) {
		assert.ok(Math.abs(compartment.voltage + 65) < 0.5, `resting drift: ${compartment.voltage}`);
	}
}

// All values remain finite and gates stay in [0, 1].
for (const sample of trace) {
	for (const compartment of sample.compartments) {
		assert.ok(Number.isFinite(compartment.voltage));
		for (const gate of ['m', 'h', 'n']) {
			assert.ok(compartment[gate] >= 0 && compartment[gate] <= 1);
		}
	}
}

// The stimulated soma spikes.
const somaPeak = Math.max(...trace.map((sample) => sample.compartments[0].voltage));
assert.ok(somaPeak > 0, `expected soma spike, peak was ${somaPeak}`);

// Coupling must cause a response beyond the small unstimulated resting drift.
const neighborPeak = Math.max(...trace.map((sample) => sample.compartments[1].voltage));
const uncoupled = simulateMultiCompartment({
	durationMs: 30,
	dt: 0.01,
	connections: [],
	current: (timeMs, index) => (index === 0 && timeMs >= 5 && timeMs < 25 ? 10 : 0),
});
const restingPeak = Math.max(...uncoupled.map((sample) => sample.compartments[1].voltage));
assert.ok(neighborPeak > restingPeak + 1, `expected coupled response, peak was ${neighborPeak}`);

// Uncoupled compartment stays at rest while the coupled neighbor depolarizes.
const isolated = simulateMultiCompartment({
	durationMs: 30,
	dt: 0.01,
	compartments: [{}, {}, {}],
	connections: [{from: 0, to: 1, conductance: 1}],
	current: (timeMs, index) => (index === 0 && timeMs >= 5 && timeMs < 25 ? 10 : 0),
});
const isolatedPeak = Math.max(...isolated.map((sample) => sample.compartments[2].voltage));
assert.ok(Math.abs(isolatedPeak + 65) < 0.5, `uncoupled compartment drifted to ${isolatedPeak}`);

// A single compartment without connections reproduces the classic simulation.
const single = simulateMultiCompartment({
	durationMs: 30,
	dt: 0.01,
	compartments: [{}],
	connections: [],
	current: (timeMs) => (timeMs >= 5 && timeMs < 25 ? 10 : 0),
});
const classic = simulate({
	durationMs: 30,
	dt: 0.01,
	current: (timeMs) => (timeMs >= 5 && timeMs < 25 ? 10 : 0),
});
assert.strictEqual(single.length, classic.length);
single.forEach((sample, index) => {
	assert.strictEqual(sample.timeMs, classic[index].timeMs);
	for (const field of ['voltage', 'm', 'h', 'n']) {
		assert.ok(
			Math.abs(sample.compartments[0][field] - classic[index][field]) < 1e-9,
			`sample ${index}.${field} diverged from single-compartment reference`,
		);
	}
});

// The end time appears once, even when duration / dt rounds above an integer.
for (const [durationMs, expectedSamples] of [[0.07, 8], [0.025, 4], [0.007, 2]]) {
	let calls = 0;
	const shortTrace = simulateMultiCompartment({
		durationMs,
		dt: 0.01,
		current: (timeMs, index) => {
			assert.ok(timeMs < durationMs, 'do not evaluate current after the final sample');
			assert.ok(Number.isInteger(index) && index >= 0 && index < 3);
			calls += 1;
			return 0;
		},
	});
	assert.strictEqual(shortTrace.length, expectedSamples);
	assert.strictEqual(shortTrace.at(-1).timeMs, durationMs);
	assert.strictEqual(calls, (expectedSamples - 1) * 3);
	shortTrace.slice(1).forEach((sample, index) => {
		assert.ok(sample.timeMs > shortTrace[index].timeMs, 'timestamps must strictly increase');
	});
}

// Pure axial coupling conserves charge even with unequal capacitances.
// Disable membrane currents explicitly; the defaults have active Na/K channels.
const passive = simulateMultiCompartment({
	durationMs: 0.5,
	dt: 0.01,
	compartments: [
		{voltage: -70, parameters: {capacitance: 1, gNa: 0, gK: 0, gLeak: 0}},
		{voltage: -50, parameters: {capacitance: 3, gNa: 0, gK: 0, gLeak: 0}},
	],
	connections: [{from: 0, to: 1, conductance: 2}],
});
let previousDifference = 20;
for (const sample of passive) {
	const [first, second] = sample.compartments;
	assert.ok(Math.abs(first.voltage + 3 * second.voltage + 220) < 1e-10, 'axial charge conservation');
	const difference = second.voltage - first.voltage;
	assert.ok(difference > 0 && difference <= previousDifference, 'voltages must approach equilibrium');
	previousDifference = difference;
}
assert.ok(passive.at(-1).compartments[0].voltage > -70);
assert.ok(passive.at(-1).compartments[1].voltage < -50);

// Reindexing a network must not change its physical trace.
const network = {
	durationMs: 1,
	dt: 0.01,
	compartments: [{voltage: -65}, {voltage: -64}, {voltage: -66}],
	connections: [{from: 0, to: 1, conductance: 0.6}, {from: 1, to: 2, conductance: 0.2}],
	current: (timeMs, index) => (index === 2 && timeMs >= 0.2 && timeMs < 0.8 ? 10 : 0),
};
const permutation = [2, 0, 1];
const original = simulateMultiCompartment(network);
const reordered = simulateMultiCompartment({
	...network,
	compartments: permutation.map((index) => network.compartments[index]),
	connections: network.connections.map(({from, to, conductance}) => ({
		from: permutation.indexOf(from), to: permutation.indexOf(to), conductance,
	})),
	current: (timeMs, index) => network.current(timeMs, permutation[index]),
});
assert.strictEqual(reordered.length, original.length);
reordered.forEach((sample, step) => {
	assert.strictEqual(sample.timeMs, original[step].timeMs);
	permutation.forEach((oldIndex, newIndex) => {
		for (const field of ['voltage', 'm', 'h', 'n']) {
			assert.ok(Math.abs(sample.compartments[newIndex][field]
				- original[step].compartments[oldIndex][field]) < 1e-10, `reindexing changed ${field}`);
		}
	});
});

// Stored samples own their states; later mutations cannot rewrite history.
const originalSecondVoltage = original[1].compartments[0].voltage;
original[0].compartments[0].voltage = 123;
assert.strictEqual(original[1].compartments[0].voltage, originalSecondVoltage);
assert.strictEqual(network.compartments[0].voltage, -65, 'options must remain unchanged');

// Determinism: identical runs produce identical traces.
const repeat = simulateMultiCompartment({
	durationMs: 10,
	dt: 0.01,
	current: (timeMs, index) => (index === 0 && timeMs >= 2 && timeMs < 8 ? 10 : 0),
});
const repeatAgain = simulateMultiCompartment({
	durationMs: 10,
	dt: 0.01,
	current: (timeMs, index) => (index === 0 && timeMs >= 2 && timeMs < 8 ? 10 : 0),
});
assert.deepStrictEqual(repeat, repeatAgain);

// Per-compartment stimulus can target the distal segment.
const distal = simulateMultiCompartment({
	durationMs: 30,
	dt: 0.01,
	current: (timeMs, index) => (index === 2 && timeMs >= 5 && timeMs < 25 ? 30 : 0),
});
const distalPeak = Math.max(...distal.map((sample) => sample.compartments[2].voltage));
assert.ok(distalPeak > 0, `expected distal spike, peak was ${distalPeak}`);

// Input validation.
for (const invoke of [
	() => simulateMultiCompartment({durationMs: 0}),
	() => simulateMultiCompartment({durationMs: Number.NaN}),
	() => simulateMultiCompartment({dt: 0}),
	() => simulateMultiCompartment({dt: 0.2}),
	() => simulateMultiCompartment({current: 5}),
	() => simulateMultiCompartment({compartments: []}),
	() => simulateMultiCompartment({compartments: [{}], connections: [{from: 0, to: 0, conductance: 1}]}),
	() => simulateMultiCompartment({compartments: [{}], connections: [{from: 0, to: 1, conductance: 1}]}),
	() => simulateMultiCompartment({compartments: [{}, {}], connections: [{from: 0, to: 1, conductance: -1}]}),
	() => simulateMultiCompartment({compartments: [{}], connections: [{}]}),
	() => simulateMultiCompartment({compartments: [null]}),
	() => simulateMultiCompartment({
		compartments: Array.from({length: MAX_COMPARTMENTS + 1}, () => ({})),
		durationMs: 0.01,
	}),
	() => simulateMultiCompartment({durationMs: MAX_COMPARTMENTS, dt: 0.0001}),
	() => simulateMultiCompartment({durationMs: 1, current: () => Number.NaN}),
]) {
	assert.throws(invoke);
}

// Both public CLI aliases and the library export must reach the simulator.
assert.strictEqual(require('../src/index').simulateMultiCompartment, simulateMultiCompartment);
const cliPath = path.join(__dirname, '..', 'bin', 'cli.js');
for (const command of ['--neuron-multi', 'neuron-multi']) {
	const summary = JSON.parse(execFileSync(process.execPath, [cliPath, command], {encoding: 'utf8'}));
	assert.strictEqual(summary.model, 'coupled-multi-compartment-hodgkin-huxley');
	assert.strictEqual(summary.samples, 3001);
	assert.strictEqual(summary.compartments, 3);
	assert.strictEqual(summary.spiked, true);
	assert.strictEqual(summary.peakVoltageMv.length, 3);
	assert.ok(summary.peakVoltageMv.every(Number.isFinite));
}

console.log('Multi-compartment Hodgkin-Huxley tests passed');
