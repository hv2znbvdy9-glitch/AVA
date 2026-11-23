'use strict';

const {run, runAll} = require('./run');
const {AVA_COLOR, hexToRgb, colorize, ava} = require('./color');
const {overview, OVERVIEW_TEXT} = require('./overview');
const {
	STATUS,
	REQUIRED_FIELDS,
	createEpisode,
	missingRequiredFields,
	enterProtectionMode,
	hasEmergencySigns,
	evaluateEpisode,
	summarizeEpisode,
	buildTrend,
} = require('./mvp');

module.exports = {
	run,
	runAll,
	AVA_COLOR,
	hexToRgb,
	colorize,
	ava,
	overview,
	OVERVIEW_TEXT,
	STATUS,
	REQUIRED_FIELDS,
	createEpisode,
	missingRequiredFields,
	enterProtectionMode,
	hasEmergencySigns,
	evaluateEpisode,
	summarizeEpisode,
	buildTrend,
};
