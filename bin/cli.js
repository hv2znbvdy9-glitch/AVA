#!/usr/bin/env node
'use strict';

const {run} = require('../src/run');
const {ava} = require('../src/color');

const args = process.argv.slice(2);

if (args.length === 0) {
	console.error(`Usage: ${ava('ava')} <command>`);
	console.error(`Example: ${ava('ava')} "echo hello"`);
	process.exit(1);
}

const command = args.join(' ');
const result = run(command, {silent: false});
process.exit(result.exitCode);
