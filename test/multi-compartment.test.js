'use strict';

const assert = require('assert');
const {MAX_COMPARTMENTS, simulateMultiCompartment} = require('../src/neuron/multi-compartment');
const {simulate} = require('../src/neuron/hodgkin-huxley');

// Default topology: soma (index 0) stimulated, passive chain behind it.
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

// The axial neighbor depolarizes above rest through coupling.
const neighborPeak = Math.max(...trace.map((sample) => sample.compartments[1].voltage));
assert.ok(neighborPeak > -65, `expected depolarized neighbor, peak was ${neighborPeak}`);

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
	assert.ok(
		Math.abs(sample.compartments[0].voltage - classic[index].voltage) < 1e-9,
		`sample ${index} diverged from single-compartment reference`,
	);
});

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

console.log('Multi-compartment Hodgkin-Huxley tests passed');
