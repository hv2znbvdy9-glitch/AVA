'use strict';

const assert = require('assert');
const {AVA_COLOR, hexToRgb, colorize, ava} = require('../src/color');

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

console.log('color tests\n');

test('AVA_COLOR should be the brand hex value', () => {
	assert.strictEqual(AVA_COLOR, '#0969DA');
});

test('hexToRgb should parse #0969DA correctly', () => {
	const rgb = hexToRgb('#0969DA');
	assert.strictEqual(rgb.r, 9);
	assert.strictEqual(rgb.g, 105);
	assert.strictEqual(rgb.b, 218);
});

test('hexToRgb should work without leading #', () => {
	const rgb = hexToRgb('0969DA');
	assert.strictEqual(rgb.r, 9);
	assert.strictEqual(rgb.g, 105);
	assert.strictEqual(rgb.b, 218);
});

test('hexToRgb should parse #ffffff correctly', () => {
	const rgb = hexToRgb('#ffffff');
	assert.strictEqual(rgb.r, 255);
	assert.strictEqual(rgb.g, 255);
	assert.strictEqual(rgb.b, 255);
});

test('colorize should wrap text in ANSI escape codes', () => {
	const result = colorize('hello', '#0969DA');
	assert.ok(result.includes('hello'));
	assert.ok(result.startsWith('\x1b[38;2;'));
	assert.ok(result.endsWith('\x1b[0m'));
});

test('colorize should include the correct RGB values for #0969DA', () => {
	const result = colorize('test', '#0969DA');
	assert.ok(result.includes('38;2;9;105;218'));
});

test('ava() should return a string containing AVA <2', () => {
	const result = ava();
	assert.ok(result.includes('AVA <2'));
});

test('ava() should use the brand color in its ANSI output', () => {
	const result = ava();
	assert.ok(result.includes('38;2;9;105;218'));
});

console.log(`\n${passed} passing, ${failed} failing`);
process.exit(failed > 0 ? 1 : 0);
