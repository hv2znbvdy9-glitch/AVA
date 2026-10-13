'use strict';

const assert = require('node:assert/strict');
const {MAX_TARGET_NODES, MAX_SAMPLE_SIZE, simulateScale} = require('../src/scale-lab');

const small = simulateScale({nodeCount: 100, sampleSize: 100, seed: 1610});
assert.equal(small.target.logicalNodes, 100);
assert.equal(small.target.sampledNodes, 100);
assert.equal(small.boundaries.physicalServersCreated, 0);
assert.equal(small.boundaries.networkCallsMade, 0);
assert.equal(small.boundaries.medicalAssessmentPerformed, false);
assert.equal(small.results.logicalStateBytes, 100 * 512);

const large = simulateScale({nodeCount: MAX_TARGET_NODES, sampleSize: 2_000, seed: 1610});
assert.equal(large.target.logicalNodes, 690_000_000);
assert.equal(large.target.sampledNodes, 2_000);
assert.equal(large.results.logicalStateBytes, 690_000_000 * 512);
assert.ok(Number.isFinite(large.results.estimatedMessagesPerSecond));
assert.equal(large.boundaries.physicalServersCreated, 0);
assert.equal(large.boundaries.processesOrWorkersCreated, 0);

const repeatA = simulateScale({nodeCount: 50_000, sampleSize: 1_000, seed: 7});
const repeatB = simulateScale({nodeCount: 50_000, sampleSize: 1_000, seed: 7});
assert.equal(repeatA.results.sampledFailedNodes, repeatB.results.sampledFailedNodes);
assert.equal(repeatA.results.sampledFailureFraction, repeatB.results.sampledFailureFraction);

const energyScenario = simulateScale({nodeCount: 10, sampleSize: 10, energyWattsPerNode: 0.25});
assert.equal(energyScenario.results.estimatedPowerKwFromExplicitAssumption, 0.0025);
assert.equal(energyScenario.boundaries.energyMeasured, false);
assert.equal(simulateScale({nodeCount: 10, sampleSize: 10}).results.estimatedPowerKwFromExplicitAssumption, null);

assert.throws(() => simulateScale({nodeCount: 0}), /nodeCount/);
assert.throws(() => simulateScale({nodeCount: MAX_TARGET_NODES + 1}), /nodeCount/);
assert.throws(() => simulateScale({sampleSize: MAX_SAMPLE_SIZE + 1}), /sampleSize/);
assert.throws(() => simulateScale({failureProbability: 1.1}), /failureProbability/);
assert.throws(() => simulateScale({energyWattsPerNode: -1}), /energyWattsPerNode/);

console.log('scale-lab tests passed');
