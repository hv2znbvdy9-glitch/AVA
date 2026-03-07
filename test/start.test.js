'use strict';

const assert = require('assert');
const {start, START_BANNER} = require('../src/start');

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

console.log('start banner tests\n');

test('START_BANNER should be a non-empty string', () => {
	assert.strictEqual(typeof START_BANNER, 'string');
	assert.ok(START_BANNER.length > 0);
});

test('START_BANNER should contain "START - JETZT!"', () => {
	assert.ok(START_BANNER.includes('START - JETZT!'));
});

test('START_BANNER should describe the session structure', () => {
	assert.ok(START_BANNER.includes('Talk'));
	assert.ok(START_BANNER.includes('Train'));
	assert.ok(START_BANNER.includes('Test'));
});

test('start() should print the banner without throwing', () => {
	const lines = [];
	const original = console.log;
	console.log = (...args) => lines.push(args.join(' '));
	try {
		start();
	} finally {
		console.log = original;
	}
	assert.ok(lines.join('\n').includes('START - JETZT!'));
});

console.log(`\n${passed} passing, ${failed} failing`);
process.exit(failed > 0 ? 1 : 0);
