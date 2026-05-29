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
const nextLayerScriptPath = path.join(__dirname, '..', 'scripts', 'Ava314NextLayerAll.ps1');
const nextLayerScriptContents = fs.readFileSync(nextLayerScriptPath, 'utf8');
const safeLocalScriptPath = path.join(__dirname, '..', 'scripts', 'Ava314SafeLocalNode.ps1');
const safeLocalScriptContents = fs.readFileSync(safeLocalScriptPath, 'utf8');
const wlanSensorScriptPath = path.join(__dirname, '..', 'scripts', 'AVA_WLAN_TANGLE_SENSOR.ps1');
const wlanSensorScriptContents = fs.readFileSync(wlanSensorScriptPath, 'utf8');
const coreStackScriptPath = path.join(__dirname, '..', 'scripts', 'AvaCoreStack.ps1');
const coreStackScriptContents = fs.readFileSync(coreStackScriptPath, 'utf8');

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

test('AVA 3.14 NEXT LAYER script should exist', () => {
	assert.ok(fs.existsSync(nextLayerScriptPath));
});

test('AVA 3.14 NEXT LAYER script should parse without PowerShell syntax errors', () => {
	const escapedPath = nextLayerScriptPath.replace(/'/g, "''");
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

test('AVA 3.14 NEXT LAYER script should not contain pasted template artifacts', () => {
	assert.ok(!nextLayerScriptContents.includes('<__filter_complete__>'));
	assert.ok(!nextLayerScriptContents.includes('2&gt;&amp;1'));
});

test('AVA 3.14 SAFE LOCAL NODE script should exist', () => {
	assert.ok(fs.existsSync(safeLocalScriptPath));
});

test('AVA 3.14 SAFE LOCAL NODE script should parse without PowerShell syntax errors', () => {
	const escapedPath = safeLocalScriptPath.replace(/'/g, "''");
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

test('AVA 3.14 SAFE LOCAL NODE script should not contain pasted template artifacts', () => {
	assert.ok(!safeLocalScriptContents.includes('<__filter_complete__>'));
	assert.ok(!safeLocalScriptContents.includes('2&gt;&amp;1'));
});

test('AVA WLAN TANGLE SENSOR script should exist', () => {
	assert.ok(fs.existsSync(wlanSensorScriptPath));
});

test('AVA WLAN TANGLE SENSOR script should parse without PowerShell syntax errors', () => {
	const escapedPath = wlanSensorScriptPath.replace(/'/g, "''");
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

test('AVA WLAN TANGLE SENSOR script should define defensive WLAN collection outputs', () => {
	assert.ok(wlanSensorScriptContents.includes("netsh wlan show networks mode=bssid"));
	assert.ok(wlanSensorScriptContents.includes("arp -a"));
	assert.ok(wlanSensorScriptContents.includes("Get-NetNeighbor -AddressFamily IPv4"));
	assert.ok(wlanSensorScriptContents.includes("ava_wlan_guardian_v1.html"));
	assert.ok(wlanSensorScriptContents.includes("AVA_WLAN_GUARDIAN_V1"));
});

test('AVA CORE STACK script should exist', () => {
	assert.ok(fs.existsSync(coreStackScriptPath));
});

test('AVA CORE STACK script should parse without PowerShell syntax errors', () => {
	const escapedPath = coreStackScriptPath.replace(/'/g, "''");
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

test('AVA CORE STACK script should not contain pasted template artifacts', () => {
	assert.ok(!coreStackScriptContents.includes('<__filter_complete__>'));
	assert.ok(!coreStackScriptContents.includes('2&gt;&amp;1'));
});

test('AVA CORE STACK script should define core defensive functions', () => {
	assert.ok(coreStackScriptContents.includes('function Get-DefenderInfo'));
	assert.ok(coreStackScriptContents.includes('function Write-TangleEvent'));
	assert.ok(coreStackScriptContents.includes('function New-Snapshot'));
	assert.ok(coreStackScriptContents.includes('function Compare-WithBaseline'));
	assert.ok(coreStackScriptContents.includes('function Build-Portal'));
	assert.ok(coreStackScriptContents.includes('ava_core_portal.html'));
});

console.log(`\n${passed} passing, ${failed} failing`);
process.exit(failed > 0 ? 1 : 0);
