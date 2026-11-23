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
const {
	neuronModelReport,
	neuronModelData,
	NEURON_MODEL_REPORT,
	NEURON_MODEL_REFERENCES,
	HAY_L5B_REFERENCE,
} = require('./neuron-model');
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
const {
	axialCouplingCurrent,
	cableEquationDerivative,
	conductanceCurrent,
	eulerStep,
} = require('./neuron/cable');
const {
	MAX_COMPARTMENTS,
	simulateMultiCompartment,
} = require('./neuron/multi-compartment');
const {
	MAP3D_ARTICLE,
	MAP3D_LIBRARIES,
	map3dLibrariesData,
	map3dLibrariesReport,
} = require('./map3d-libraries');
const {AVA_RADIO_PROFILE} = require('./voice/config');
const {processAudio} = require('./voice/engine');
const {MAX_TARGET_NODES, simulateScale} = require('./scale-lab');

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
	HAY_L5B_REFERENCE,
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
	axialCouplingCurrent,
	cableEquationDerivative,
	conductanceCurrent,
	eulerStep,
	MAX_COMPARTMENTS,
	simulateMultiCompartment,
	MAP3D_ARTICLE,
	MAP3D_LIBRARIES,
	map3dLibrariesData,
	map3dLibrariesReport,
	AVA_RADIO_PROFILE,
	processAudio,
	MAX_TARGET_NODES,
	simulateScale,
};
