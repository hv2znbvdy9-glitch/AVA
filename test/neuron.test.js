'use strict';

const assert = require('assert');
const { HodgkinHuxleyCompartment, rates, simulate } = require('../src/neuron/hodgkin-huxley');

const singularM = rates(-40);
const singularN = rates(-55);
assert.ok(Number.isFinite(singularM.alphaM));
assert.ok(Number.isFinite(singularN.alphaN));

const resting = new HodgkinHuxleyCompartment();
const restTrace = simulate({ durationMs: 5, dt: 0.01, compartment: resting });
assert.ok(restTrace.every(sample => Number.isFinite(sample.voltage)));
assert.ok(Math.abs(restTrace.at(-1).voltage + 65) < 1);

const stimulated = simulate({
  durationMs: 30,
  dt: 0.01,
  current: timeMs => (timeMs >= 5 && timeMs < 25 ? 10 : 0),
});
assert.ok(Math.max(...stimulated.map(sample => sample.voltage)) > 0);
assert.throws(() => new HodgkinHuxleyCompartment().step(0.2), /dt/);

console.log('Hodgkin-Huxley tests passed');
