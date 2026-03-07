'use strict';

const assert = require('assert');
const {overview, OVERVIEW_TEXT} = require('../src/overview');

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

console.log('overview tests\n');

test('OVERVIEW_TEXT should be a non-empty string', () => {
	assert.strictEqual(typeof OVERVIEW_TEXT, 'string');
	assert.ok(OVERVIEW_TEXT.length > 0);
});

test('OVERVIEW_TEXT should start with the AVA brand header line', () => {
	assert.ok(OVERVIEW_TEXT.startsWith('AVA <2 — Session Overview'));
});

test('OVERVIEW_TEXT should describe the Talk/Train/Test structure', () => {
	assert.ok(OVERVIEW_TEXT.includes('Talk'));
	assert.ok(OVERVIEW_TEXT.includes('Train'));
	assert.ok(OVERVIEW_TEXT.includes('Test'));
});

test('overview() should return OVERVIEW_TEXT', () => {
	assert.strictEqual(overview(), OVERVIEW_TEXT);
});

console.log(`\n${passed} passing, ${failed} failing`);
process.exit(failed > 0 ? 1 : 0);
