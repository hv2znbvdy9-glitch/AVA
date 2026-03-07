'use strict';

const assert = require('assert');
const {hexToRgb, colorize, ava, AVA_COLOR} = require('../src/color');
const {overview} = require('../src/overview');

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

console.log('color and overview tests\n');

test('AVA_COLOR should be the brand hex color', () => {
	assert.strictEqual(AVA_COLOR, '#0969DA');
});

test('hexToRgb should parse hex color correctly', () => {
	const {r, g, b} = hexToRgb('#0969DA');
	assert.strictEqual(r, 9);
	assert.strictEqual(g, 105);
	assert.strictEqual(b, 218);
});

test('hexToRgb should work without leading #', () => {
	const {r, g, b} = hexToRgb('0969DA');
	assert.strictEqual(r, 9);
	assert.strictEqual(g, 105);
	assert.strictEqual(b, 218);
});

test('colorize should wrap text with ANSI escape codes', () => {
	const result = colorize('hello', '#0969DA');
	assert.ok(result.includes('hello'));
	assert.ok(result.includes('\x1b[38;2;9;105;218m'));
	assert.ok(result.includes('\x1b[0m'));
});

test('ava() should return a colorized AVA brand string', () => {
	const result = ava();
	assert.ok(result.includes('AVA <2'));
	assert.ok(result.includes('\x1b[38;2;9;105;218m'));
	assert.ok(result.includes('\x1b[0m'));
});

test('overview should be a non-empty string', () => {
	assert.strictEqual(typeof overview, 'string');
	assert.ok(overview.length > 0);
});

test('overview should contain AVA brand text', () => {
	assert.ok(overview.includes('AVA <2'));
});

test('overview should contain session key topics', () => {
	assert.ok(overview.includes('Structure'));
	assert.ok(overview.includes('Contextual Setup'));
	assert.ok(overview.includes('Review and Continuity'));
});

console.log(`\n${passed} passing, ${failed} failing`);
process.exit(failed > 0 ? 1 : 0);
