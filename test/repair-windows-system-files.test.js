'use strict';

const assert = require('assert');
const path = require('path');
const {execFileSync} = require('child_process');
const {repairWindowsSystemFilesReport, repairWindowsSystemFilesData, REPAIR_WINDOWS_SYSTEM_FILES_REFERENCES} = require('../src/repair-windows-system-files');

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

console.log('repair windows system files tests\n');

test('repairWindowsSystemFilesReport should include WinRE and WinPE guidance', () => {
	const report = repairWindowsSystemFilesReport();
	assert.ok(report.includes('WinRE'));
	assert.ok(report.includes('WinPE'));
	assert.ok(report.includes('Phase 1'));
	assert.ok(report.includes('Phase 3'));
});

test('repairWindowsSystemFilesData should expose the structured repair metadata', () => {
	const data = repairWindowsSystemFilesData();
	assert.strictEqual(data.category, 'windows-system-repair-guide');
	assert.strictEqual(data.phases, 3);
	assert.strictEqual(data.steps, 20);
	assert.ok(data.references.every((item) => typeof item.url === 'string' && item.url.startsWith('https://')));
});

test('REPAIR_WINDOWS_SYSTEM_FILES_REFERENCES should stay frozen', () => {
	assert.strictEqual(REPAIR_WINDOWS_SYSTEM_FILES_REFERENCES.length, 3);
	assert.ok(Object.isFrozen(REPAIR_WINDOWS_SYSTEM_FILES_REFERENCES));
	assert.ok(!repairWindowsSystemFilesReport().includes('/home/runner/'));
});

test('CLI flag --repair-windows-system-files should print the guide', () => {
	const cliPath = path.join(__dirname, '..', 'bin', 'cli.js');
	const stdout = execFileSync(process.execPath, [cliPath, '--repair-windows-system-files'], {encoding: 'utf8'});
	assert.ok(stdout.includes('AVA Windows System Repair Guide'));
});

test('CLI command repair-windows-system-files should print the guide', () => {
	const cliPath = path.join(__dirname, '..', 'bin', 'cli.js');
	const stdout = execFileSync(process.execPath, [cliPath, 'repair-windows-system-files'], {encoding: 'utf8'});
	assert.ok(stdout.includes('sfc /scannow'));
});

console.log(`\n${passed} passing, ${failed} failing`);
process.exit(failed > 0 ? 1 : 0);
