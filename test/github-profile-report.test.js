'use strict';

const assert = require('assert');
const path = require('path');
const {execFileSync} = require('child_process');
const {
	githubProfileReport,
	githubProfileReportData,
	GITHUB_PROFILE_REPORT_DATA,
	GITHUB_PROFILE_REPOSITORIES,
} = require('../src/github-profile-report');

let passed = 0;
let failed = 0;

function test(name, fn) {
	try {
		fn();
		passed++;
		console.log(`  ✓ ${name}`);
	} catch (error) {
		failed++;
		console.error(`  ✗ ${name}`);
		console.error(`    ${error.message}`);
	}
}

console.log('github profile report tests\n');

test('githubProfileReport should include the AVA 016101 heading and summary', () => {
	const report = githubProfileReport();
	assert.ok(report.includes('AVA 016101 – Hörfassung: GitHub-Profilbericht'));
	assert.ok(report.includes('Du hast insgesamt **175 offene Issues**'));
	assert.ok(report.includes('PowerShell-Projekten'));
});

test('githubProfileReportData should expose repository metadata copies', () => {
	const data = githubProfileReportData();
	assert.strictEqual(data.username, 'hv2znbvdy9-glitch');
	assert.strictEqual(data.repositories.length, 3);
	assert.notStrictEqual(data.repositories, GITHUB_PROFILE_REPORT_DATA.repositories);
	assert.notStrictEqual(data.repositories[0].permissions, GITHUB_PROFILE_REPORT_DATA.repositories[0].permissions);
});

test('report constants should stay frozen and stable', () => {
	assert.strictEqual(GITHUB_PROFILE_REPOSITORIES.length, 3);
	assert.ok(Object.isFrozen(GITHUB_PROFILE_REPOSITORIES));
	assert.ok(Object.isFrozen(GITHUB_PROFILE_REPORT_DATA));
	assert.ok(githubProfileReport().includes('AVA-007'));
	assert.ok(!githubProfileReport().includes('/home/runner/'));
});

test('CLI flag --github-profile-report should print the report', () => {
	const cliPath = path.join(__dirname, '..', 'bin', 'cli.js');
	const stdout = execFileSync(process.execPath, [cliPath, '--github-profile-report'], {encoding: 'utf8'});
	assert.ok(stdout.includes('Benutzername:** hv2znbvdy9-glitch'));
});

test('CLI command github-profile-report should print the report', () => {
	const cliPath = path.join(__dirname, '..', 'bin', 'cli.js');
	const stdout = execFileSync(process.execPath, [cliPath, 'github-profile-report'], {encoding: 'utf8'});
	assert.ok(stdout.includes('**Ende der AVA 016101 Hörfassung.**'));
});

test('CLI alias --profile-report should print the report', () => {
	const cliPath = path.join(__dirname, '..', 'bin', 'cli.js');
	const stdout = execFileSync(process.execPath, [cliPath, '--profile-report'], {encoding: 'utf8'});
	assert.ok(stdout.includes('## Repositories'));
});

console.log(`\n${passed} passing, ${failed} failing`);
process.exit(failed > 0 ? 1 : 0);
