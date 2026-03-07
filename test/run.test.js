'use strict';

const assert = require('assert');
const {run, runAll} = require('../src/run');
const {hexToRgb, colorize, ava, AVA_COLOR} = require('../src/color');

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

async function testAsync(name, fn) {
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

console.log('\ncolor tests\n');

test('hexToRgb: should parse #0969DA correctly', () => {
	const {r, g, b} = hexToRgb(AVA_COLOR);
	assert.strictEqual(r, 9);
	assert.strictEqual(g, 105);
	assert.strictEqual(b, 218);
});

test('hexToRgb: should work without the leading #', () => {
	const {r, g, b} = hexToRgb('0969DA');
	assert.strictEqual(r, 9);
	assert.strictEqual(g, 105);
	assert.strictEqual(b, 218);
});

test('hexToRgb: should throw on invalid hex color', () => {
	assert.throws(() => hexToRgb('gg0000'), {message: 'Invalid hex color: gg0000'});
	assert.throws(() => hexToRgb('#xyz'), {message: 'Invalid hex color: #xyz'});
});

test('colorize: should wrap text with ANSI 24-bit color codes', () => {
	const result = colorize('hello', '#0969DA');
	assert.ok(result.startsWith('\x1b[38;2;9;105;218m'));
	assert.ok(result.endsWith('\x1b[0m'));
	assert.ok(result.includes('hello'));
});

test('ava: should colorize text with the AVA brand color', () => {
	const result = ava('AVA');
	assert.ok(result.startsWith('\x1b[38;2;9;105;218m'));
	assert.ok(result.endsWith('\x1b[0m'));
	assert.ok(result.includes('AVA'));
});

async function main() {
	await testAsync('runAll: should run a battery of commands and return a matrix of results', async () => {
		const results = await runAll(['echo foo', 'echo bar'], {silent: true});
		assert.strictEqual(results.length, 2);
		assert.strictEqual(results[0].command, 'echo foo');
		assert.strictEqual(results[0].stdout.trim(), 'foo');
		assert.strictEqual(results[0].exitCode, 0);
		assert.strictEqual(results[1].command, 'echo bar');
		assert.strictEqual(results[1].stdout.trim(), 'bar');
		assert.strictEqual(results[1].exitCode, 0);
	});

	await testAsync('runAll: should include non-zero exit codes in results', async () => {
		const results = await runAll(
			['echo ok', 'node -e "process.exit(2)"'],
			{silent: true}
		);
		assert.strictEqual(results[0].exitCode, 0);
		assert.notStrictEqual(results[1].exitCode, 0);
	});

	await testAsync('runAll: should run commands with concurrency > 1', async () => {
		const results = await runAll(
			['echo a', 'echo b', 'echo c'],
			{silent: true, concurrency: 2}
		);
		assert.strictEqual(results.length, 3);
		assert.strictEqual(results[0].stdout.trim(), 'a');
		assert.strictEqual(results[1].stdout.trim(), 'b');
		assert.strictEqual(results[2].stdout.trim(), 'c');
	});

	await testAsync('runAll: should throw if commands is not an array', async () => {
		await assert.rejects(async () => runAll('echo hello'), {message: 'A commands array is required'});
		await assert.rejects(async () => runAll(null), {message: 'A commands array is required'});
	});

	await testAsync('runAll: should return an empty array for an empty commands list', async () => {
		const results = await runAll([], {silent: true});
		assert.deepStrictEqual(results, []);
	});

	console.log(`\n${passed} passing, ${failed} failing`);
	process.exit(failed > 0 ? 1 : 0);
}

main();
