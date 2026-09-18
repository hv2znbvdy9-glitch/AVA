'use strict';

const assert = require('assert');
const path = require('path');
const {execFileSync} = require('child_process');
const {
	repairWindowsSystemFilesReport,
	repairWindowsSystemFilesData,
	REPAIR_WINDOWS_SYSTEM_FILES_REFERENCES,
} = require('../src/repair-windows-system-files');

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

test('repairWindowsSystemFilesReport should include the offline repair flow', () => {
	const report = repairWindowsSystemFilesReport();
	assert.ok(report.includes('Windows-Systemdateien aus WinRE/WinPE reparieren'));
	assert.ok(report.includes('wpeutil reboot'));
	assert.ok(report.includes('sfc /scannow /offbootdir=C:\\ /offwindir=C:\\Windows'));
	assert.ok(report.includes('DISM /Image:C:\\ /Cleanup-Image /RestoreHealth'));
});

test('repairWindowsSystemFilesData should expose commands and reference copies', () => {
	const data = repairWindowsSystemFilesData();
	assert.strictEqual(data.environment, 'Windows Recovery Environment (WinRE/WinPE)');
	assert.strictEqual(data.commands.length, 5);
	assert.notStrictEqual(data.references, REPAIR_WINDOWS_SYSTEM_FILES_REFERENCES);
	assert.ok(data.references.every((item) => typeof item.url === 'string' && item.url.startsWith('https://')));
});

test('REPAIR_WINDOWS_SYSTEM_FILES_REFERENCES should stay frozen and stable', () => {
	assert.strictEqual(REPAIR_WINDOWS_SYSTEM_FILES_REFERENCES.length, 4);
	assert.ok(Object.isFrozen(REPAIR_WINDOWS_SYSTEM_FILES_REFERENCES));
	assert.ok(REPAIR_WINDOWS_SYSTEM_FILES_REFERENCES[1].title.includes('WinRE'));
	assert.ok(!repairWindowsSystemFilesReport().includes('/home/runner/'));
});

test('CLI flag --repair-windows-system-files should print the guide', () => {
	const cliPath = path.join(__dirname, '..', 'bin', 'cli.js');
	const stdout = execFileSync(process.execPath, [cliPath, '--repair-windows-system-files'], {encoding: 'utf8'});
	assert.ok(stdout.includes('bcdedit'));
});

test('CLI command repair-windows-system-files should print the guide', () => {
	const cliPath = path.join(__dirname, '..', 'bin', 'cli.js');
	const stdout = execFileSync(process.execPath, [cliPath, 'repair-windows-system-files'], {encoding: 'utf8'});
	assert.ok(stdout.includes('Kein icacls C:\\Windows /reset /T'));
});

console.log(`\n${passed} passing, ${failed} failing`);
process.exit(failed > 0 ? 1 : 0);
