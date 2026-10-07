'use strict';

function shiftPitch(samples, semitones) {
	if (samples.length === 0 || semitones === 0) {
		return new Float32Array(samples);
	}

	const ratio = 2 ** (semitones / 12);
	const outputLength = Math.max(1, Math.round(samples.length / ratio));
	const output = new Float32Array(outputLength);

	for (let index = 0; index < output.length; index++) {
		const position = index * ratio;
		const left = Math.floor(position);
		const right = Math.min(left + 1, samples.length - 1);
		const fraction = position - left;
		output[index] = samples[left] + (samples[right] - samples[left]) * fraction;
	}

	return output;
}

function applyRadioFilter(samples, sampleRate) {
	const output = new Float32Array(samples.length);
	const highPassCutoff = Math.min(300, sampleRate * 0.45);
	const lowPassCutoff = Math.min(3400, sampleRate * 0.45);
	const highPassAlpha = Math.exp((-2 * Math.PI * highPassCutoff) / sampleRate);
	const lowPassAlpha = 1 - Math.exp((-2 * Math.PI * lowPassCutoff) / sampleRate);
	let previousInput = 0;
	let previousHighPass = 0;
	let previousLowPass = 0;

	for (let index = 0; index < samples.length; index++) {
		const highPass = highPassAlpha * (previousHighPass + samples[index] - previousInput);
		previousInput = samples[index];
		previousHighPass = highPass;
		previousLowPass += lowPassAlpha * (highPass - previousLowPass);
		output[index] = previousLowPass;
	}

	return output;
}

function applyGlitch(samples, sampleRate) {
	const output = new Float32Array(samples);
	const glitchLength = Math.max(1, Math.floor(sampleRate * 0.012));
	const interval = Math.floor(sampleRate * 0.6);

	for (let start = interval; start + glitchLength <= samples.length; start += interval) {
		const sourceStart = Math.max(0, start - glitchLength);
		for (let offset = 0; offset < glitchLength; offset++) {
			output[start + offset] = samples[sourceStart + offset];
		}
	}

	return output;
}

function applyEcho(samples, sampleRate) {
	const output = new Float32Array(samples.length);
	const delay = Math.max(1, Math.floor(sampleRate * 0.12));
	const feedback = 0.28;

	for (let index = 0; index < samples.length; index++) {
		const delayed = index >= delay ? output[index - delay] * feedback : 0;
		output[index] = samples[index] + delayed;
	}

	return output;
}

function applyDistortion(samples, amount) {
	if (amount === 0) {
		return new Float32Array(samples);
	}

	const drive = 1 + amount * 20;
	const normalization = Math.tanh(drive);
	const output = new Float32Array(samples.length);

	for (let index = 0; index < samples.length; index++) {
		output[index] = Math.tanh(samples[index] * drive) / normalization;
	}

	return output;
}

function clampSamples(samples) {
	const output = new Float32Array(samples.length);
	for (let index = 0; index < samples.length; index++) {
		output[index] = Math.max(-1, Math.min(1, samples[index]));
	}
	return output;
}

module.exports = {
	shiftPitch,
	applyRadioFilter,
	applyGlitch,
	applyEcho,
	applyDistortion,
	clampSamples,
};
