'use strict';

const {run, runAll, runAsync, runAllParallel} = require('./run');
const {AVA_COLOR, hexToRgb, colorize, ava} = require('./color');
const {overview, OVERVIEW_TEXT} = require('./overview');
const {runSafeLocalNode} = require('./safe-local-node');
const {STATE_LABELS, clampScore, classifyState, calculateScore} = require('./state');
const {neuronModelReport, neuronModelData, NEURON_MODEL_REPORT, NEURON_MODEL_REFERENCES} = require('./neuron-model');
const {
	githubProfileReport,
	githubProfileReportData,
	GITHUB_PROFILE_REPORT_DATA,
	GITHUB_PROFILE_REPOSITORIES,
} = require('./github-profile-report');
const {
	HodgkinHuxleyCompartment,
	rates: neuronRates,
	simulate: simulateNeuron,
	steadyState: neuronSteadyState,
} = require('./neuron/hodgkin-huxley');

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
	githubProfileReport,
	githubProfileReportData,
	GITHUB_PROFILE_REPORT_DATA,
	GITHUB_PROFILE_REPOSITORIES,
	neuronModelReport,
	neuronModelData,
	NEURON_MODEL_REPORT,
	NEURON_MODEL_REFERENCES,
	HodgkinHuxleyCompartment,
	neuronRates,
	simulateNeuron,
	neuronSteadyState,
};
