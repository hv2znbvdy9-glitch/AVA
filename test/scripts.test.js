'use strict';

const assert = require('assert');
const fs = require('fs');
const path = require('path');
const {execFileSync} = require('child_process');

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

const scriptPath = path.join(__dirname, '..', 'scripts', 'AvaSocPortalV5.ps1');
const scriptContents = fs.readFileSync(scriptPath, 'utf8');

console.log('script tests\n');

test('AVA SOC Portal V5 script should exist', () => {
	assert.ok(fs.existsSync(scriptPath));
});

test('AVA SOC Portal V5 script should parse without PowerShell syntax errors', () => {
	const escapedPath = scriptPath.replace(/'/g, "''");
	const parseCommand = [
		"$tokens = $null",
		"$errors = $null",
		`[System.Management.Automation.Language.Parser]::ParseFile('${escapedPath}', [ref]$tokens, [ref]$errors) | Out-Null`,
		"if ($errors.Count -gt 0) {",
		"\t$errors | ForEach-Object { $_.Message }",
		"\texit 1",
		"}",
	].join('; ');

	execFileSync('pwsh', ['-NoProfile', '-Command', parseCommand], {stdio: 'pipe'});
});

test('AVA SOC Portal V5 script should not contain pasted template artifacts', () => {
	assert.ok(!scriptContents.includes('<__filter_complete__>'));
	assert.ok(!scriptContents.includes('</tbody></table></div>'));
	assert.ok(!scriptContents.includes('2&gt;&amp;1'));
});

test('AVA SOC Portal V5 script should close the alerts table before the next section', () => {
	assert.ok(scriptContents.includes('<h2>Alerts</h2>'));
	assert.ok(scriptContents.includes('</tbody></table>\n</div>\n\n<div class="section card">\n<h2>Firewall Profiles</h2>'));
});

console.log(`\n${passed} passing, ${failed} failing`);
process.exit(failed > 0 ? 1 : 0);
