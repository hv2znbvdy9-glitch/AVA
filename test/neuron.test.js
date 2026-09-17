'use strict';

const assert = require('assert');
const path = require('path');
const {execFileSync} = require('child_process');
const {
	HodgkinHuxleyCompartment,
	MAX_STEPS,
	rates,
	simulate,
} = require('../src/neuron/hodgkin-huxley');

const singularM = rates(-40);
const singularN = rates(-55);
assert.ok(Math.abs(singularM.alphaM - 1) < 1e-12);
assert.ok(Math.abs(singularN.alphaN - 0.1) < 1e-12);

const resting = new HodgkinHuxleyCompartment();
const restTrace = simulate({durationMs: 5, dt: 0.01, compartment: resting});
assert.ok(restTrace.every((sample) => Number.isFinite(sample.voltage)));
assert.ok(restTrace.every((sample) => ['m', 'h', 'n'].every((gate) => sample[gate] >= 0 && sample[gate] <= 1)));
assert.ok(Math.abs(restTrace.at(-1).voltage + 65) < 1);
assert.strictEqual(restTrace.at(-1).timeMs, 5);

const stimulated = simulate({
	durationMs: 30,
	dt: 0.01,
	current: (timeMs) => (timeMs >= 5 && timeMs < 25 ? 10 : 0),
});
assert.ok(Math.max(...stimulated.map((sample) => sample.voltage)) > 0);

for (const dt of [0, -0.01, 0.2, Number.NaN, Number.POSITIVE_INFINITY]) {
	assert.throws(() => simulate({durationMs: 1, dt}), /dt/);
}
assert.throws(
	() => new HodgkinHuxleyCompartment({parameters: {gNa: -1}}),
	/gNa/,
);
assert.throws(
	() => simulate({durationMs: (MAX_STEPS + 1) * 0.01, dt: 0.01}),
	/exceeds/,
);

const cliPath = path.join(__dirname, '..', 'bin', 'cli.js');
const summary = JSON.parse(execFileSync(process.execPath, [cliPath, '--neuron-sim'], {encoding: 'utf8'}));
assert.strictEqual(summary.model, 'classic-single-compartment-hodgkin-huxley');
assert.strictEqual(summary.spiked, true);
assert.ok(summary.peakVoltageMv > 0);

console.log('Hodgkin-Huxley tests passed');
