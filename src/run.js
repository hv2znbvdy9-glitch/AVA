'use strict';

const {execSync, exec} = require('child_process');

/**
 * Execute a command string in a child process.
 * @param {string} command - The command to run.
 * @param {object} [options] - Options for execution.
 * @param {boolean} [options.silent] - If true, suppress stdout output.
 * @param {string} [options.cwd] - Working directory for the command.
 * @returns {{stdout: string, stderr: string, exitCode: number}} Result of the execution.
 */
function run(command, options = {}) {
	if (!command || typeof command !== 'string') {
		throw new Error('A command string is required');
	}

	const execOptions = {
		encoding: 'utf8',
		cwd: options.cwd || process.cwd(),
		stdio: 'pipe',
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
			exitCode: error.status || 1,
		};
	}
}

/**
 * Execute a battery of command strings and return a matrix of results.
 * Commands within each batch run in true parallel using async child processes.
 * @param {string[]} commands - The commands to run.
 * @param {object} [options] - Options applied to every command.
 * @param {boolean} [options.silent] - If true, suppress stdout/stderr output.
 * @param {string} [options.cwd] - Working directory for every command.
 * @param {number} [options.concurrency] - Max commands to run in parallel (default: 1).
 * @returns {Promise<Array<{command: string, stdout: string, exitCode: number}>>} Matrix of results.
 */
async function runAll(commands, options = {}) {
	if (!Array.isArray(commands)) {
		throw new Error('A commands array is required');
	}

	const concurrency = options.concurrency && options.concurrency > 0
		? Math.floor(options.concurrency)
		: 1;

	const execOptions = {
		encoding: 'utf8',
		cwd: options.cwd || process.cwd(),
	};

	function execAsync(cmd) {
		return new Promise((resolve) => {
			exec(cmd, execOptions, (error, stdout, stderr) => {
				const output = stdout || '';
				const errOutput = stderr || '';
				if (!options.silent) {
					if (output) {
						process.stdout.write(output);
					}

					if (errOutput) {
						process.stderr.write(errOutput);
					}
				}

				resolve({
					command: cmd,
					stdout: output,
					exitCode: error ? (error.code || 1) : 0,
				});
			});
		});
	}

	const results = new Array(commands.length);

	for (let i = 0; i < commands.length; i += concurrency) {
		const batch = commands.slice(i, i + concurrency);
		const batchResults = await Promise.all(batch.map(execAsync));
		for (let j = 0; j < batchResults.length; j++) {
			results[i + j] = batchResults[j];
		}
	}

	return results;
}

module.exports = {run, runAll};
