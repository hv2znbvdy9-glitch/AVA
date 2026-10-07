'use strict';

const assert = require('assert');
const {AVA_RADIO_PROFILE} = require('../src/voice/config');
const {processAudio} = require('../src/voice/engine');

assert.strictEqual(AVA_RADIO_PROFILE.name, 'AVA_RADIO_01610~1');
assert.strictEqual(AVA_RADIO_PROFILE.effects.pitch_shift, 3);
assert.ok(Object.isFrozen(AVA_RADIO_PROFILE));
assert.ok(Object.isFrozen(AVA_RADIO_PROFILE.effects));

const input = new Float32Array(48000);
input[0] = 1;
const processed = processAudio(input);
assert.ok(processed instanceof Float32Array);
assert.ok(processed.length < input.length);
assert.ok(processed.every((sample) => Number.isFinite(sample) && sample >= -1 && sample <= 1));
assert.strictEqual(input[0], 1);

assert.deepStrictEqual(processAudio([], {sampleRate: 48000}), new Float32Array(0));
assert.throws(() => processAudio('audio'), /samples must be/);
assert.throws(() => processAudio([1.1]), /range \[-1, 1\]/);
assert.throws(() => processAudio([Number.NaN]), /finite values/);
assert.throws(() => processAudio([], {sampleRate: 7999}), /sampleRate/);
assert.throws(
	() => processAudio([], {profile: {...AVA_RADIO_PROFILE, effects: {...AVA_RADIO_PROFILE.effects, pitch_shift: 13}}}),
	/pitch_shift/,
);

console.log('voice tests passed');
