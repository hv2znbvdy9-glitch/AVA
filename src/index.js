'use strict';

const {run, runAll, runAsync, runAllParallel} = require('./run');
const {AVA_COLOR, hexToRgb, colorize, ava} = require('./color');
const {overview, OVERVIEW_TEXT} = require('./overview');
const {runSafeLocalNode} = require('./safe-local-node');
const {STATE_LABELS, clampScore, classifyState, calculateScore} = require('./state');
const {neuronModelReport, neuronModelData, NEURON_MODEL_REPORT, NEURON_MODEL_REFERENCES} = require('./neuron-model');
const {
	HodgkinHuxleyCompartment,
	rates: neuronRates,
	simulate: simulateNeuron,
	steadyState: neuronSteadyState,
} = require('./neuron/hodgkin-huxley');
const {
	MODEL_ID,
	MODEL_SCOPE,
	COMPARTMENTS,
	COUPLINGS,
	PROTOCOLS,
	simulateMultiCompartmentHH,
	validateSimulation,
	writeNeuroEvidence,
} = require('./neuro-hh');

module.exports = {
	run,
	runAll,
	runAsync,
	runAllParallel,
	AVA_COLOR,
	hexToRgb,
	colorize,
	ava,
	overview,
	OVERVIEW_TEXT,
	runSafeLocalNode,
	STATE_LABELS,
	clampScore,
	classifyState,
	calculateScore,
	neuronModelReport,
	neuronModelData,
	NEURON_MODEL_REPORT,
	NEURON_MODEL_REFERENCES,
	HodgkinHuxleyCompartment,
	neuronRates,
	simulateNeuron,
	neuronSteadyState,
	MODEL_ID,
	MODEL_SCOPE,
	COMPARTMENTS,
	COUPLINGS,
	PROTOCOLS,
	simulateMultiCompartmentHH,
	validateSimulation,
	writeNeuroEvidence,
};
