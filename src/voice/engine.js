'use strict';

const {AVA_RADIO_PROFILE} = require('./config');
const {
	shiftPitch,
	applyRadioFilter,
	applyGlitch,
	applyEcho,
	applyDistortion,
	clampSamples,
} = require('./filters');

function validateSamples(samples) {
	if (!Array.isArray(samples) && !(samples instanceof Float32Array)) {
		throw new TypeError('samples must be an array or Float32Array');
	}

	for (const sample of samples) {
		if (!Number.isFinite(sample) || sample < -1 || sample > 1) {
			throw new RangeError('samples must contain finite values in the range [-1, 1]');
		}
	}
}

function validateSampleRate(sampleRate) {
	if (!Number.isInteger(sampleRate) || sampleRate < 8000 || sampleRate > 192000) {
		throw new RangeError('sampleRate must be an integer between 8000 and 192000');
	}
}

function validateProfile(profile) {
	if (!profile || typeof profile !== 'object' || !profile.effects || typeof profile.effects !== 'object') {
		throw new TypeError('profile must contain an effects object');
	}

	const {pitch_shift: pitchShift, distortion} = profile.effects;
	if (!Number.isFinite(pitchShift) || pitchShift < -12 || pitchShift > 12) {
		throw new RangeError('profile pitch_shift must be between -12 and 12 semitones');
	}
	if (!Number.isFinite(distortion) || distortion < 0 || distortion > 1) {
		throw new RangeError('profile distortion must be between 0 and 1');
	}
	for (const effect of ['echo', 'radio_filter', 'glitch']) {
		if (typeof profile.effects[effect] !== 'boolean') {
			throw new TypeError(`profile ${effect} must be a boolean`);
		}
	}
}

function processAudio(samples, {sampleRate = 48000, profile = AVA_RADIO_PROFILE} = {}) {
	validateSamples(samples);
	validateSampleRate(sampleRate);
	validateProfile(profile);

	let output = new Float32Array(samples);
	const {pitch_shift: pitchShift, echo, radio_filter: radioFilter, glitch, distortion} = profile.effects;

	output = shiftPitch(output, pitchShift);
	if (radioFilter) {
		output = applyRadioFilter(output, sampleRate);
	}
	if (glitch) {
		output = applyGlitch(output, sampleRate);
	}
	if (echo) {
		output = applyEcho(output, sampleRate);
	}
	output = applyDistortion(output, distortion);
	return clampSamples(output);
}

module.exports = {processAudio};
