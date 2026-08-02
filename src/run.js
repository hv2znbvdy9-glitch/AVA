'use strict';

const {spawnSync} = require('child_process');

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
		shell: true,
	};

	const result = spawnSync(command, execOptions);

	const stdout = result.stdout ? result.stdout.toString() : '';
	const stderrCaptured = result.stderr ? result.stderr.toString() : '';
	const stderr = stderrCaptured || (result.error ? result.error.message : '');
	const exitCode = result.status === null ? 1 : result.status;

	if (!options.silent) {
		if (stdout) {
			process.stdout.write(stdout);
		}

		if (stderr) {
			process.stderr.write(stderr);
		}
	}

	return {
		stdout,
		stderr,
		exitCode,
	};
}

module.exports = {run};
