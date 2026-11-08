'use strict';

const assert = require('assert');
const {
	axialCouplingCurrent,
	cableEquationDerivative,
	conductanceCurrent,
	eulerStep,
} = require('../src/neuron/cable');
const {HAY_L5B_REFERENCE, neuronModelData, neuronModelReport} = require('../src/neuron-model');

assert.strictEqual(conductanceCurrent(2, 10, 5), 10);
assert.strictEqual(conductanceCurrent(2, 0, 5), -10);
assert.strictEqual(axialCouplingCurrent(-60, -50, 2), 20);
assert.strictEqual(axialCouplingCurrent(-50, -60, 2), -20);

const compartments = [
	{voltage: -60, capacitance: 2, conductances: [{conductance: 1, reversalPotential: -70}]},
	{voltage: -50, capacitance: 1},
];
const derivative = cableEquationDerivative(compartments, [{from: 0, to: 1, conductance: 2}], [0, 0]);
assert.deepStrictEqual(derivative, [5, -20]);
assert.deepStrictEqual(eulerStep([-60, -50], derivative, 0.1), [-59.5, -52]);
assert.deepStrictEqual(compartments.map(({voltage}) => voltage), [-60, -50]);
assert.deepStrictEqual(
	cableEquationDerivative([{voltage: -65, capacitance: 1}], [], [2]),
	[2],
);

for (const invoke of [
	() => conductanceCurrent(-1, 0, 0),
	() => conductanceCurrent(1, Number.NaN, 0),
	() => axialCouplingCurrent(0, 1, Number.POSITIVE_INFINITY),
	() => cableEquationDerivative([{voltage: 0, capacitance: 0}]),
	() => cableEquationDerivative([{voltage: 0, capacitance: 1}], [{from: 0, to: 0, conductance: 1}]),
	() => cableEquationDerivative([{voltage: 0, capacitance: 1}], [], [Number.NaN]),
	() => eulerStep([1], [1], 0),
	() => eulerStep([1], [], 1),
]) {
	assert.throws(invoke);
}

assert.strictEqual(HAY_L5B_REFERENCE.year, 2011);
assert.strictEqual(HAY_L5B_REFERENCE.doi, '10.1371/journal.pcbi.1002107');
assert.strictEqual(HAY_L5B_REFERENCE.fullModelImplemented, false);
assert.strictEqual(HAY_L5B_REFERENCE.neuronSimulationImplemented, false);
assert.strictEqual(neuronModelData().hayL5bReference.scope, HAY_L5B_REFERENCE.scope);
assert.ok(neuronModelReport().includes('kein vollständiges Hay-Modell'));

console.log('Generic cable and Hay reference-layer tests passed');
