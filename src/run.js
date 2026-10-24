'use strict';

const {execSync, exec} = require('child_process');

/**
 * Execute a command string in a child process.
 * @param {string} command - The command to run.
 * @param {object} [options] - Options for execution.
 * @param {boolean} [options.silent] - If true, suppress stdout output.
 * @param {string} [options.cwd] - Working directory for the command.
 * @param {number} [options.timeout] - Optional positive timeout in milliseconds.
 * @returns {{stdout: string, stderr: string, exitCode: number}} Result of the execution.
 */
function run(command, options = {}) {
	if (!command || typeof command !== 'string') {
		throw new Error('A command string is required');
	}

	const timeout = getTimeout(options);
	const execOptions = {
		encoding: 'utf8',
		cwd: options.cwd || process.cwd(),
		stdio: 'pipe',
		timeout,
	};

	try {
		const stdout = execSync(command, execOptions) || '';
		const output = stdout.toString();
		if (!options.silent && output) {
			process.stdout.write(output);
		}

		return {stdout: output, stderr: '', exitCode: 0};
	} catch (error) {
		const output = error.stdout ? error.stdout.toString() : '';
		const stderr = error.stderr ? error.stderr.toString() : '';
		if (!options.silent) {
			if (output) {
				process.stdout.write(output);
			}

			if (stderr) {
				process.stderr.write(stderr);
			}
		}

		return {
			stdout: output,
			stderr,
			exitCode: getExitCode(error, timeout),
		};
	}
}

/**
 * Execute an array of command strings sequentially.
 * @param {string[]} commands - The commands to run in order.
 * @param {object} [options] - Options passed to each run() call.
 * @returns {{stdout: string, stderr: string, exitCode: number}[]} Results for each command.
 */
function runAll(commands, options = {}) {
	if (!Array.isArray(commands)) {
		throw new Error('commands must be an array');
	}

	return commands.map((command) => run(command, options));
}

/**
 * Execute a command string asynchronously in a child process.
 * @param {string} command - The command to run.
 * @param {object} [options] - Options for execution.
 * @param {boolean} [options.silent] - If true, suppress stdout/stderr output.
 * @param {string} [options.cwd] - Working directory for the command.
 * @param {number} [options.timeout] - Optional positive timeout in milliseconds.
 * @returns {Promise<{stdout: string, stderr: string, exitCode: number}>} Resolves with the result.
 */
function runAsync(command, options = {}) {
	if (!command || typeof command !== 'string') {
		return Promise.reject(new Error('A command string is required'));
	}

	let timeout;
	try {
		timeout = getTimeout(options);
	} catch (error) {
		return Promise.reject(error);
	}

	const execOptions = {
		encoding: 'utf8',
		cwd: options.cwd || process.cwd(),
		timeout,
	};

	return new Promise((resolve) => {
		exec(command, execOptions, (error, stdout, stderr) => {
			const out = stdout || '';
			const err = stderr || '';

			if (!options.silent) {
				if (out) process.stdout.write(out);
				if (err) process.stderr.write(err);
			}

			resolve({
				stdout: out,
				stderr: err,
				exitCode: getExitCode(error, timeout),
			});
		});
	});
}

function getTimeout(options) {
	if (options.timeout === undefined) {
		return undefined;
	}

	if (!Number.isSafeInteger(options.timeout) || options.timeout <= 0) {
		throw new Error('timeout must be a positive integer in milliseconds');
	}

	return options.timeout;
}

function getExitCode(error, timeout) {
	if (!error) {
		return 0;
	}

	if (timeout !== undefined && (error.killed || error.code === 'ETIMEDOUT')) {
		return 124;
	}

	if (Number.isInteger(error.status)) {
		return error.status;
	}

	return Number.isInteger(error.code) ? error.code : 1;
}

/**
 * Execute an array of command strings in parallel.
 * @param {string[]} commands - The commands to run concurrently.
 * @param {object} [options] - Options passed to each runAsync() call.
 * @returns {Promise<{stdout: string, stderr: string, exitCode: number}[]>} Resolves with results in input order.
 */
function runAllParallel(commands, options = {}) {
	if (!Array.isArray(commands)) {
		return Promise.reject(new Error('commands must be an array'));
	}

	return Promise.all(commands.map((command) => runAsync(command, options)));
}

module.exports = {run, runAll, runAsync, runAllParallel};
