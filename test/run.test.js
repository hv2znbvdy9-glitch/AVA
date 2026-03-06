'use strict';

const assert = require('assert');
const {run} = require('../src/run');

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

console.log('run command tests\n');

test('should execute a simple command and return stdout', () => {
	const result = run('echo hello', {silent: true});
	assert.strictEqual(result.stdout.trim(), 'hello');
	assert.strictEqual(result.exitCode, 0);
});

test('should return exit code 0 on success', () => {
	const result = run('node -e "process.exit(0)"', {silent: true});
	assert.strictEqual(result.exitCode, 0);
});

test('should return non-zero exit code on failure', () => {
	const result = run('node -e "process.exit(1)"', {silent: true});
	assert.notStrictEqual(result.exitCode, 0);
});

test('should throw if no command is provided', () => {
	assert.throws(() => run(''), {message: 'A command string is required'});
	assert.throws(() => run(null), {message: 'A command string is required'});
	assert.throws(() => run(undefined), {message: 'A command string is required'});
});

test('should accept a cwd option', () => {
	const result = run('node -e "console.log(process.cwd())"', {silent: true, cwd: '/tmp'});
	assert.strictEqual(result.stdout.trim(), '/tmp');
	assert.strictEqual(result.exitCode, 0);
});

test('should return empty stderr on success', () => {
	const result = run('echo hello', {silent: true});
	assert.strictEqual(result.stderr, '');
});

test('should capture stderr on failure', () => {
	const result = run('node -e "process.stderr.write(\'err\\n\'); process.exit(1)"', {silent: true});
	assert.strictEqual(result.stderr.trim(), 'err');
	assert.notStrictEqual(result.exitCode, 0);
});

console.log(`\n${passed} passing, ${failed} failing`);
process.exit(failed > 0 ? 1 : 0);
