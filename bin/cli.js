#!/usr/bin/env node
'use strict';

const {run} = require('../src/run');

const args = process.argv.slice(2);

if (args.length === 0) {
	console.error('Usage: ava <command>');
	console.error('Example: ava "echo hello"');
	process.exit(1);
}

const command = args.join(' ');

try {
	const result = run(command, {silent: false});
	process.exit(result.exitCode);
} catch (error) {
	console.error(`Error: ${error.message}`);
	process.exit(1);
}
