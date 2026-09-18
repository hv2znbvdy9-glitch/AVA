'use strict';

const assert = require('assert');
const path = require('path');
const {execFileSync} = require('child_process');
const {githubProfileReport, profileReport, githubProfileData, GITHUB_PROFILE_REFERENCES} = require('../src/github-profile-report');

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

test('githubProfileReport should include the user and repositories', () => {
	const report = githubProfileReport();
	assert.ok(report.includes('hv2znbvdy9-glitch'));
	assert.ok(report.includes('AVA'));
	assert.ok(report.includes('AVA-007'));
	assert.ok(report.includes('DEVITO'));
});

test('githubProfileData should expose profile metadata', () => {
	const data = githubProfileData();
	assert.strictEqual(typeof data.username, 'string');
	assert.strictEqual(data.profileType, 'single-user');
	assert.strictEqual(data.repositories.length, 3);
	assert.ok(data.repositories.every((repo) => typeof repo.url === 'string' && repo.url.startsWith('https://')));
});

test('GITHUB_PROFILE_REFERENCES should stay stable', () => {
	assert.strictEqual(GITHUB_PROFILE_REFERENCES.length, 1);
	assert.ok(Object.isFrozen(GITHUB_PROFILE_REFERENCES));
	assert.ok(!githubProfileReport().includes('/home/runner/'));
});

test('CLI flag --github-profile-report should print the report', () => {
	const cliPath = path.join(__dirname, '..', 'bin', 'cli.js');
	const stdout = execFileSync(process.execPath, [cliPath, '--github-profile-report'], {encoding: 'utf8'});
	assert.ok(stdout.includes('GitHub-Profilbericht'));
});

test('CLI alias --profile-report should print the report', () => {
	const cliPath = path.join(__dirname, '..', 'bin', 'cli.js');
	const stdout = execFileSync(process.execPath, [cliPath, '--profile-report'], {encoding: 'utf8'});
	assert.ok(stdout.includes('Benutzerübersicht'));
});

test('CLI command profile-report should print the report', () => {
	const cliPath = path.join(__dirname, '..', 'bin', 'cli.js');
	const stdout = execFileSync(process.execPath, [cliPath, 'profile-report'], {encoding: 'utf8'});
	assert.ok(stdout.includes('AVA 016101'));
});

test('profileReport alias should return the same report text', () => {
	assert.strictEqual(profileReport(), githubProfileReport());
});

console.log(`\n${passed} passing, ${failed} failing`);
process.exit(failed > 0 ? 1 : 0);
