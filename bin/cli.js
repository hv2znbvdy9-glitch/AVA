#!/usr/bin/env node
'use strict';

const {run, runAllParallel} = require('../src/run');
const {ava, AVA_COLOR} = require('../src/color');
const {overview} = require('../src/overview');
const {runSafeLocalNode} = require('../src/safe-local-node');

const args = process.argv.slice(2);

if (args.includes('--color')) {
	console.log(`${ava()} (${AVA_COLOR})`);
	process.exit(0);
}

if (args.includes('--overview')) {
	console.log(overview());
	process.exit(0);
}

if (args.includes('--safe-local-node')) {
	const result = runSafeLocalNode();
	console.log(`SAFE LOCAL NODE completed at: ${result.paths.root}`);
	console.log(`Portal: ${result.paths.portalHtml}`);
	process.exit(0);
}

if (args.length === 0) {
	console.error('Usage: ava <command>');
	console.error('       ava run <command>');
	console.error('       ava --parallel <cmd1> [cmd2 ...]');
	console.error('       ava --safe-local-node');
	console.error('Example: ava "echo hello"');
	process.exit(1);
}

if (args[0] === 'safe-local-node') {
	const result = runSafeLocalNode();
	console.log(`SAFE LOCAL NODE completed at: ${result.paths.root}`);
	console.log(`Portal: ${result.paths.portalHtml}`);
	process.exit(0);
}

if (args[0] === 'run') {
	args.shift();
	if (args.length === 0) {
		console.error('Usage: ava run <command>');
		console.error('Example: ava run "echo hello"');
		process.exit(1);
	}
}

if (args[0] === '--parallel') {
	const commands = args.slice(1);
	if (commands.length === 0) {
		console.error('Usage: ava --parallel <cmd1> [cmd2 ...]');
		console.error('Example: ava --parallel "echo hello" "echo world"');
		process.exit(1);
	}

	runAllParallel(commands, {silent: false}).then((results) => {
		const worst = results.reduce((max, r) => Math.max(max, r.exitCode), 0);
		process.exit(worst);
	});
} else {
	const command = args.join(' ');
	const result = run(command, {silent: false});
	process.exit(result.exitCode);
}
