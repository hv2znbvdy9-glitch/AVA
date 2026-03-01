'use strict';

const {execSync} = require('child_process');

/**
 * Execute a command string in a child process.
 * @param {string} command - The command to run.
 * @param {object} [options] - Options for execution.
 * @param {boolean} [options.silent] - If true, suppress stdout output.
 * @param {string} [options.cwd] - Working directory for the command.
 * @returns {{stdout: string, exitCode: number}} Result of the execution.
 */
function run(command, options = {}) {
	if (!command || typeof command !== 'string') {
		throw new Error('A command string is required');
	}

	const execOptions = {
		encoding: 'utf8',
		cwd: options.cwd || process.cwd(),
		stdio: options.silent ? 'pipe' : 'inherit',
	};

	try {
		const stdout = execSync(command, execOptions) || '';
		return {stdout: stdout.toString(), exitCode: 0};
	} catch (error) {
		return {
			stdout: error.stdout ? error.stdout.toString() : '',
			exitCode: error.status || 1,
		};
	}
}

module.exports = {run};
