'use strict';

const {run, runAll, runAsync, runAllParallel} = require('./run');
const {AVA_COLOR, hexToRgb, colorize, ava} = require('./color');
const {overview, OVERVIEW_TEXT} = require('./overview');
const {runSafeLocalNode} = require('./safe-local-node');
const {
	repairWindowsSystemFilesReport,
	repairWindowsSystemFilesData,
	REPAIR_WINDOWS_SYSTEM_FILES_REPORT,
	REPAIR_WINDOWS_SYSTEM_FILES_REFERENCES,
} = require('./repair-windows-system-files');
const {STATE_LABELS, clampScore, classifyState, calculateScore} = require('./state');
const {neuronModelReport, neuronModelData, NEURON_MODEL_REPORT, NEURON_MODEL_REFERENCES} = require('./neuron-model');
const {
	avatar01610Report,
	avatar01610Data,
	AVATAR_01610_REPORT,
	AVATAR_01610_LAYERS,
	AVATAR_01610_CYCLE,
	AVATAR_01610_PRINCIPLES,
} = require('./avatar-01610');
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
	repairWindowsSystemFilesReport,
	repairWindowsSystemFilesData,
	REPAIR_WINDOWS_SYSTEM_FILES_REPORT,
	REPAIR_WINDOWS_SYSTEM_FILES_REFERENCES,
	STATE_LABELS,
	clampScore,
	classifyState,
	calculateScore,
	neuronModelReport,
	neuronModelData,
	NEURON_MODEL_REPORT,
	NEURON_MODEL_REFERENCES,
	avatar01610Report,
	avatar01610Data,
	AVATAR_01610_REPORT,
	AVATAR_01610_LAYERS,
	AVATAR_01610_CYCLE,
	AVATAR_01610_PRINCIPLES,
	HodgkinHuxleyCompartment,
	neuronRates,
	simulateNeuron,
	neuronSteadyState,
};
