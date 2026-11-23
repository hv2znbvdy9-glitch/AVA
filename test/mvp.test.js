'use strict';

const assert = require('assert');
const {
	STATUS,
	createEpisode,
	enterProtectionMode,
	hasEmergencySigns,
	evaluateEpisode,
	summarizeEpisode,
	buildTrend,
} = require('../src/mvp');

let passed = 0;
let failed = 0;

function test(name, fn) {
	try {
		fn();
		passed++;
		console.log(`  ✓ ${name}`);
	} catch (error) {
		failed++;
		console.error(`  ✗ ${name}`);
		console.error(`    ${error.message}`);
	}
}

function createSampleEpisode(overrides = {}) {
	return Object.assign({
		timestamp: '2026-11-23T23:00:00.000Z',
		durationMinutes: 12,
		sleepHours: 6,
		stressLevel: 7,
		earPressure: true,
		headache: 'mild',
		medicationsSubstances: 'none',
		pulse: 78,
		immediateContext: 'after loud noise',
		changes: {
			speech: false,
			strength: false,
			vision: false,
			orientation: false,
		},
		notes: 'control-loss feeling with ear pressure',
		foreignControlFeeling: true,
	}, overrides);
}

console.log('mvp tests\n');

test('createEpisode should enforce required fields', () => {
	assert.throws(() => createEpisode({
		durationMinutes: 5,
	}), {message: /missing required episode fields/i});
});

test('protection mode should use the required safety rule', () => {
	const mode = enterProtectionMode();
	assert.strictEqual(mode.enabled, true);
	assert.strictEqual(mode.rule, 'Keine Aktion gegen andere, erst objektive Prüfung.');
});

test('hasEmergencySigns should detect emergency neurological signs', () => {
	const emergencyEpisode = createSampleEpisode({
		changes: {
			speech: true,
			strength: false,
			vision: false,
			orientation: false,
		},
	});
	assert.strictEqual(hasEmergencySigns(emergencyEpisode), true);
});

test('evaluateEpisode should set Notfall on emergency signs', () => {
	const evaluation = evaluateEpisode(createSampleEpisode({
		changes: {
			speech: false,
			strength: true,
			vision: false,
			orientation: false,
		},
	}));
	assert.strictEqual(evaluation.status, STATUS.EMERGENCY);
	assert.strictEqual(evaluation.emergency, true);
});

test('evaluateEpisode should set ärztlich zeitnah for repeated non-emergency episodes', () => {
	const firstEpisode = createSampleEpisode();
	const secondEpisode = createSampleEpisode({timestamp: '2026-11-24T00:00:00.000Z'});
	const evaluation = evaluateEpisode(secondEpisode, [firstEpisode]);
	assert.strictEqual(evaluation.status, STATUS.MEDICAL_SOON);
	assert.strictEqual(evaluation.emergency, false);
});

test('summarizeEpisode should return compact VIV summary shape', () => {
	const episode = createSampleEpisode();
	const evaluation = evaluateEpisode(episode);
	const summary = summarizeEpisode(episode, evaluation);
	assert.strictEqual(summary.status, STATUS.OBSERVE);
	assert.strictEqual(summary.when, episode.timestamp);
	assert.strictEqual(summary.howLongMinutes, episode.durationMinutes);
	assert.strictEqual(summary.warningSigns.speech, false);
});

test('buildTrend should expose frequency, trigger and symptom patterns', () => {
	const first = createSampleEpisode({immediateContext: 'after loud noise'});
	const second = createSampleEpisode({
		timestamp: '2026-11-24T00:00:00.000Z',
		immediateContext: 'during stress',
		foreignControlFeeling: false,
	});
	const trend = buildTrend([first, second]);
	assert.strictEqual(trend.totalEpisodes, 2);
	assert.strictEqual(trend.frequency, 2);
	assert.strictEqual(trend.statusCounts[STATUS.MEDICAL_SOON], 1);
	assert.strictEqual(trend.triggerPatterns['after loud noise'], 1);
	assert.strictEqual(trend.triggerPatterns['during stress'], 1);
	assert.strictEqual(trend.symptomCombinations.none, 2);
});

console.log(`\n${passed} passing, ${failed} failing`);
process.exit(failed > 0 ? 1 : 0);
