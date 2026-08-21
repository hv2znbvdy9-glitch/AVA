'use strict';

const assert = require('assert');
const os = require('os');
const {run, runAll, runAsync, runAllParallel} = require('../src/run');

let passed = 0;
let failed = 0;

async function test(name, fn) {
	try {
		await fn();
		passed++;
		console.log(`  ✓ ${name}`);
	} catch (error) {
		failed++;
		console.error(`  ✗ ${name}`);
		console.error(`    ${error.message}`);
	}
}

async function main() {
	console.log('run command tests\n');

	await test('should execute a simple command and return stdout', () => {
		const result = run('echo hello', {silent: true});
		assert.strictEqual(result.stdout.trim(), 'hello');
		assert.strictEqual(result.exitCode, 0);
	});

	await test('should return exit code 0 on success', () => {
		const result = run('node -e "process.exit(0)"', {silent: true});
		assert.strictEqual(result.exitCode, 0);
	});

	await test('should return non-zero exit code on failure', () => {
		const result = run('node -e "process.exit(1)"', {silent: true});
		assert.notStrictEqual(result.exitCode, 0);
	});

	await test('should throw if no command is provided', () => {
		assert.throws(() => run(''), {message: 'A command string is required'});
		assert.throws(() => run(null), {message: 'A command string is required'});
		assert.throws(() => run(undefined), {message: 'A command string is required'});
	});

	await test('should return empty stderr on success', () => {
		const result = run('echo hello', {silent: true});
		assert.strictEqual(result.stderr, '');
	});

	await test('should capture stderr on failure', () => {
		const result = run('node -e "process.stdout.write(\'out\'); process.stderr.write(\'error output\'); process.exit(1)"', {silent: true});
		assert.ok(result.stderr.includes('error output'));
		assert.strictEqual(result.stdout, 'out');
		assert.notStrictEqual(result.exitCode, 0);
	});

	await test('should accept a cwd option', () => {
		const cwd = os.tmpdir();
		const result = run('node -e "console.log(process.cwd())"', {silent: true, cwd});
		assert.strictEqual(result.stdout.trim(), cwd);
		assert.strictEqual(result.exitCode, 0);
	});

	await test('runAll should run multiple commands and return results array', () => {
		const results = runAll(['echo hello', 'echo world'], {silent: true});
		assert.strictEqual(results.length, 2);
		assert.strictEqual(results[0].stdout.trim(), 'hello');
		assert.strictEqual(results[0].exitCode, 0);
		assert.strictEqual(results[1].stdout.trim(), 'world');
		assert.strictEqual(results[1].exitCode, 0);
	});

	await test('runAll should return per-command exit codes', () => {
		const results = runAll(['echo ok', 'node -e "process.exit(2)"'], {silent: true});
		assert.strictEqual(results[0].exitCode, 0);
		assert.strictEqual(results[1].exitCode, 2);
	});

	await test('runAll should throw if commands is not an array', () => {
		assert.throws(() => runAll('echo hello'), {message: 'commands must be an array'});
		assert.throws(() => runAll(null), {message: 'commands must be an array'});
	});

	await test('runAll should return empty array for empty input', () => {
		const results = runAll([], {silent: true});
		assert.deepStrictEqual(results, []);
	});

	// runAsync tests
	await test('runAsync should execute a command and resolve with stdout', async () => {
		const result = await runAsync('echo hello', {silent: true});
		assert.strictEqual(result.stdout.trim(), 'hello');
		assert.strictEqual(result.exitCode, 0);
	});

	await test('runAsync should resolve with exit code 0 on success', async () => {
		const result = await runAsync('node -e "process.exit(0)"', {silent: true});
		assert.strictEqual(result.exitCode, 0);
	});

	await test('runAsync should resolve with non-zero exit code on failure', async () => {
		const result = await runAsync('node -e "process.exit(3)"', {silent: true});
		assert.strictEqual(result.exitCode, 3);
	});

	await test('runAsync should reject if no command is provided', async () => {
		await assert.rejects(() => runAsync(''), {message: 'A command string is required'});
		await assert.rejects(() => runAsync(null), {message: 'A command string is required'});
	});

	await test('runAsync should capture stderr', async () => {
		const result = await runAsync('node -e "process.stderr.write(\'err\')"', {silent: true});
		assert.ok(result.stderr.includes('err'));
	});

	await test('runAsync should accept a cwd option', async () => {
		const cwd = os.tmpdir();
		const result = await runAsync('node -e "console.log(process.cwd())"', {silent: true, cwd});
		assert.strictEqual(result.stdout.trim(), cwd);
	});

	// runAllParallel tests
	await test('runAllParallel should run commands in parallel and return results in order', async () => {
		const results = await runAllParallel(['echo hello', 'echo world'], {silent: true});
		assert.strictEqual(results.length, 2);
		assert.strictEqual(results[0].stdout.trim(), 'hello');
		assert.strictEqual(results[1].stdout.trim(), 'world');
	});

	await test('runAllParallel should return per-command exit codes', async () => {
		const results = await runAllParallel(['echo ok', 'node -e "process.exit(2)"'], {silent: true});
		assert.strictEqual(results[0].exitCode, 0);
		assert.strictEqual(results[1].exitCode, 2);
	});

	await test('runAllParallel should reject if commands is not an array', async () => {
		await assert.rejects(() => runAllParallel('echo hello'), {message: 'commands must be an array'});
		await assert.rejects(() => runAllParallel(null), {message: 'commands must be an array'});
	});

	await test('runAllParallel should resolve with empty array for empty input', async () => {
		const results = await runAllParallel([], {silent: true});
		assert.deepStrictEqual(results, []);
	});

	await test('runAllParallel should run faster than sequential for independent commands', async () => {
		const start = Date.now();
		await runAllParallel(
			['node -e "setTimeout(()=>{},1000)"', 'node -e "setTimeout(()=>{},1000)"'],
			{silent: true},
		);
		const elapsed = Date.now() - start;
		// Two one-second commands should overlap while allowing for process startup
		// variance across Linux, Windows, and macOS runners.
		assert.ok(elapsed < 1800, `Expected elapsed < 1800ms but got ${elapsed}ms`);
	});

	console.log(`\n${passed} passing, ${failed} failing`);
	process.exit(failed > 0 ? 1 : 0);
}

main();
