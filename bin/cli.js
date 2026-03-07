#!/usr/bin/env node
'use strict';

const {run} = require('../src/run');
const {ava: brandColor, AVA_COLOR} = require('../src/color');
const {overview} = require('../src/overview');

const args = process.argv.slice(2);

if (args[0] === '--color') {
	console.log(`AVA brand color: ${brandColor()} (${AVA_COLOR})`);
	process.exit(0);
}

if (args[0] === '--overview') {
	console.log(overview);
	process.exit(0);
}

if (args.length === 0) {
	console.error('Usage: ava <command>');
	console.error('Example: ava "echo hello"');
	process.exit(1);
}

const command = args.join(' ');
const result = run(command, {silent: false});
process.exit(result.exitCode);
