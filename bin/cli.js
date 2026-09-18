#!/usr/bin/env node
'use strict';

const {run, runAllParallel} = require('../src/run');
const {ava, AVA_COLOR} = require('../src/color');
const {overview} = require('../src/overview');
const {runSafeLocalNode} = require('../src/safe-local-node');
const {repairWindowsSystemFilesReport} = require('../src/repair-windows-system-files');
const {neuronModelReport} = require('../src/neuron-model');
const {githubProfileReport} = require('../src/github-profile-report');
const {simulate} = require('../src/neuron/hodgkin-huxley');

const args = process.argv.slice(2);
const githubProfileFlags = ['--github-profile-report', '--profile-report'];
const githubProfileCommands = ['github-profile-report', 'profile-report'];
const wantsGithubProfileReport = githubProfileFlags.some((flag) => args.includes(flag));
const githubProfileCommand = githubProfileCommands.includes(args[0]);

function printNeuronSimulation() {
	const durationMs = 30;
	const dt = 0.01;
	const trace = simulate({
		durationMs,
		dt,
		current: (timeMs) => (timeMs >= 5 && timeMs < 25 ? 10 : 0),
	});
	const peakVoltageMv = Math.max(...trace.map((sample) => sample.voltage));
	console.log(JSON.stringify({
		model: 'classic-single-compartment-hodgkin-huxley',
		scope: 'deterministic-teaching-prototype',
		durationMs,
		dtMs: dt,
		samples: trace.length,
		peakVoltageMv: Number(peakVoltageMv.toFixed(6)),
		spiked: peakVoltageMv > 0,
	}, null, 2));
}

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

if (args.includes('--repair-windows-system-files')) {
	console.log(repairWindowsSystemFilesReport());
	process.exit(0);
}

if (args.includes('--neuron-model')) {
	console.log(neuronModelReport());
	process.exit(0);
}

if (args.includes('--neuron-sim')) {
	printNeuronSimulation();
	process.exit(0);
}

if (wantsGithubProfileReport) {
	console.log(githubProfileReport());
	process.exit(0);
}

if (args.length === 0) {
	console.error('Usage: ava <command>');
	console.error('       ava run <command>');
	console.error('       ava --parallel <cmd1> [cmd2 ...]');
	console.error('       ava --safe-local-node');
	console.error('       ava --repair-windows-system-files');
	console.error('       ava --neuron-model');
	console.error('       ava --neuron-sim');
	console.error('       ava --github-profile-report');
	console.error('       ava --profile-report');
	console.error('Example: ava "echo hello"');
	process.exit(1);
}

if (args[0] === 'safe-local-node') {
	const result = runSafeLocalNode();
	console.log(`SAFE LOCAL NODE completed at: ${result.paths.root}`);
	console.log(`Portal: ${result.paths.portalHtml}`);
	process.exit(0);
}

if (args[0] === 'repair-windows-system-files') {
	console.log(repairWindowsSystemFilesReport());
	process.exit(0);
}

if (args[0] === 'neuron-model') {
	console.log(neuronModelReport());
	process.exit(0);
}

if (args[0] === 'neuron-sim') {
	printNeuronSimulation();
	process.exit(0);
}

if (githubProfileCommand) {
	console.log(githubProfileReport());
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
