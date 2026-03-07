#!/usr/bin/env node
'use strict';

const {run} = require('../src/run');
const {ava, AVA_COLOR} = require('../src/color');
const {overview} = require('../src/overview');

const args = process.argv.slice(2);

if (args.includes('--color')) {
	console.log(`${ava()} (${AVA_COLOR})`);
	process.exit(0);
}

if (args.includes('--overview')) {
	console.log(overview());
	process.exit(0);
}

if (args.length === 0) {
	console.error('Usage: ava <command>');
	console.error('       ava run <command>');
	console.error('Example: ava "echo hello"');
	process.exit(1);
}

if (args[0] === 'run') {
	args.shift();
	if (args.length === 0) {
		console.error('Usage: ava run <command>');
		console.error('Example: ava run "echo hello"');
		process.exit(1);
	}
}

const command = args.join(' ');
const result = run(command, {silent: false});
process.exit(result.exitCode);
