'use strict';

const assert = require('assert');
const {run, runAll} = require('../src/run');

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

test('should return empty stderr on success', () => {
	const result = run('echo hello', {silent: true});
	assert.strictEqual(result.stderr, '');
});

test('should capture stderr on failure', () => {
	const result = run('node -e "process.stdout.write(\'out\'); process.stderr.write(\'error output\'); process.exit(1)"', {silent: true});
	assert.ok(result.stderr.includes('error output'));
	assert.strictEqual(result.stdout, 'out');
	assert.notStrictEqual(result.exitCode, 0);
});

test('should accept a cwd option', () => {
	const result = run('node -e "console.log(process.cwd())"', {silent: true, cwd: '/tmp'});
	assert.strictEqual(result.stdout.trim(), '/tmp');
	assert.strictEqual(result.exitCode, 0);
});

test('runAll should run multiple commands and return results array', () => {
	const results = runAll(['echo hello', 'echo world'], {silent: true});
	assert.strictEqual(results.length, 2);
	assert.strictEqual(results[0].stdout.trim(), 'hello');
	assert.strictEqual(results[0].exitCode, 0);
	assert.strictEqual(results[1].stdout.trim(), 'world');
	assert.strictEqual(results[1].exitCode, 0);
});

test('runAll should return per-command exit codes', () => {
	const results = runAll(['echo ok', 'node -e "process.exit(2)"'], {silent: true});
	assert.strictEqual(results[0].exitCode, 0);
	assert.strictEqual(results[1].exitCode, 2);
});

test('runAll should throw if commands is not an array', () => {
	assert.throws(() => runAll('echo hello'), {message: 'commands must be an array'});
	assert.throws(() => runAll(null), {message: 'commands must be an array'});
});

test('runAll should return empty array for empty input', () => {
	const results = runAll([], {silent: true});
	assert.deepStrictEqual(results, []);
});

console.log(`\n${passed} passing, ${failed} failing`);
process.exit(failed > 0 ? 1 : 0);
