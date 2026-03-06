'use strict';

const {execSync} = require('child_process');

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

module.exports = {run};
