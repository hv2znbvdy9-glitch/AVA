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
const spywareRiskAuditScriptPath = path.join(__dirname, '..', 'scripts', 'AVA_SPYWARE_RISK_AUDIT.ps1');
const spywareRiskAuditScriptContents = fs.readFileSync(spywareRiskAuditScriptPath, 'utf8');
const securityGuardianScriptPath = path.join(__dirname, '..', 'scripts', 'SecurityGuardian.ps1');
const securityGuardianScriptContents = fs.readFileSync(securityGuardianScriptPath, 'utf8');
const symbolicMemoryPortalScriptPath = path.join(__dirname, '..', 'scripts', 'AvaSymbolicMemoryPortal.ps1');
const symbolicMemoryPortalScriptContents = fs.readFileSync(symbolicMemoryPortalScriptPath, 'utf8');
const wandersmannMemoryCoreScriptPath = path.join(__dirname, '..', 'scripts', 'WandersmannMemoryCore.ps1');
const wandersmannMemoryCoreScriptContents = fs.readFileSync(wandersmannMemoryCoreScriptPath, 'utf8');
const safeAuditScriptPath = path.join(__dirname, '..', 'scripts', 'AVA_SAFE_AUDIT_CHAT_MODE_v1.ps1');
const safeAuditScriptContents = fs.readFileSync(safeAuditScriptPath, 'utf8');
const safeAuditStarterPath = path.join(__dirname, '..', 'scripts', 'START_AVA_SAFE_AUDIT_ADMIN.cmd');
const safeAuditStarterContents = fs.readFileSync(safeAuditStarterPath, 'utf8');

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
	assert.ok(coreStackScriptContents.includes('function Get-ProcessGraph'));
	assert.ok(coreStackScriptContents.includes('function Get-RemoteIpReputation'));
	assert.ok(coreStackScriptContents.includes('function Get-RiskAssessment'));
	assert.ok(coreStackScriptContents.includes('function Update-TrendState'));
	assert.ok(coreStackScriptContents.includes('function Get-AvaFileIntegrity'));
	assert.ok(coreStackScriptContents.includes('ava_core_portal.html'));
	assert.ok(coreStackScriptContents.includes('Portal-Dashboard mit Zeitachse'));
	assert.ok(coreStackScriptContents.includes('Trendanalyse über mehrere Tage'));
	assert.ok(coreStackScriptContents.includes('AVA Memory ↔ Alert ↔ Prozess ↔ Netzwerk'));
	assert.ok(coreStackScriptContents.includes('Integritätsprüfung der AVA-Dateien selbst'));
});

// ---------------------------------------------------------------------------
// AVA SOC Portal V6 — Safe Graph Engine
// ---------------------------------------------------------------------------

const v6ScriptPath = path.join(__dirname, '..', 'scripts', 'AvaSocPortalV6.ps1');
const v6ScriptContents = fs.readFileSync(v6ScriptPath, 'utf8');

test('AVA SOC Portal V6 script should exist', () => {
	assert.ok(fs.existsSync(v6ScriptPath));
});

test('AVA SOC Portal V6 script should parse without PowerShell syntax errors', () => {
	const escapedPath = v6ScriptPath.replace(/'/g, "''");
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

test('AVA SOC Portal V6 script should not contain pasted template artifacts', () => {
	assert.ok(!v6ScriptContents.includes('<__filter_complete__>'));
	assert.ok(!v6ScriptContents.includes('2&gt;&amp;1'));
});

test('AVA SOC Portal V6 script should define Timeline Engine and Heatmap features', () => {
	assert.ok(v6ScriptContents.includes('function New-TimelineEvent'));
	assert.ok(v6ScriptContents.includes('function Build-HeatmapHtml'));
	assert.ok(v6ScriptContents.includes('function Build-TimelineHtml'));
	assert.ok(v6ScriptContents.includes('ava_soc_portal_v6.html'));
	assert.ok(v6ScriptContents.includes('AVA SOC PORTAL V6'));
});

// ---------------------------------------------------------------------------
// AVA SOC Portal V7 — Safe Memory Layer
// ---------------------------------------------------------------------------

const v7ScriptPath = path.join(__dirname, '..', 'scripts', 'AvaSocPortalV7.ps1');
const v7ScriptContents = fs.readFileSync(v7ScriptPath, 'utf8');

test('AVA SOC Portal V7 script should exist', () => {
	assert.ok(fs.existsSync(v7ScriptPath));
});

test('AVA SOC Portal V7 script should parse without PowerShell syntax errors', () => {
	const escapedPath = v7ScriptPath.replace(/'/g, "''");
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

test('AVA SOC Portal V7 script should not contain pasted template artifacts', () => {
	assert.ok(!v7ScriptContents.includes('<__filter_complete__>'));
	assert.ok(!v7ScriptContents.includes('2&gt;&amp;1'));
});

test('AVA SOC Portal V7 script should define Memory Layer and Correlation Engine features', () => {
	assert.ok(v7ScriptContents.includes('function Get-AutoTags'));
	assert.ok(v7ScriptContents.includes('function Get-CorrelationGroups'));
	assert.ok(v7ScriptContents.includes('function Add-MemoryEntry'));
	assert.ok(v7ScriptContents.includes('function Load-Memory'));
	assert.ok(v7ScriptContents.includes('function Save-Memory'));
	assert.ok(v7ScriptContents.includes('ava_soc_portal_v7.html'));
	assert.ok(v7ScriptContents.includes('AVA SOC PORTAL V7'));
});

// ---------------------------------------------------------------------------
// AVA Baseline Drift Detection
// ---------------------------------------------------------------------------

const driftScriptPath = path.join(__dirname, '..', 'scripts', 'AvaBaselineDrift.ps1');
const driftScriptContents = fs.readFileSync(driftScriptPath, 'utf8');

test('AVA Baseline Drift script should exist', () => {
	assert.ok(fs.existsSync(driftScriptPath));
});

test('AVA Baseline Drift script should parse without PowerShell syntax errors', () => {
	const escapedPath = driftScriptPath.replace(/'/g, "''");
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

test('AVA Baseline Drift script should not contain pasted template artifacts', () => {
	assert.ok(!driftScriptContents.includes('<__filter_complete__>'));
	assert.ok(!driftScriptContents.includes('2&gt;&amp;1'));
});

test('AVA Baseline Drift script should define core drift detection functions', () => {
	assert.ok(driftScriptContents.includes('function New-BaselineSnapshot'));
	assert.ok(driftScriptContents.includes('function Save-Baseline'));
	assert.ok(driftScriptContents.includes('function Load-Baseline'));
	assert.ok(driftScriptContents.includes('function Compare-Snapshots'));
	assert.ok(driftScriptContents.includes('function New-DriftReport'));
	assert.ok(driftScriptContents.includes('ava_baseline_drift.html'));
	assert.ok(driftScriptContents.includes('AVA BASELINE DRIFT'));
});

// ---------------------------------------------------------------------------
// AVA SPYWARE RISK AUDIT
// ---------------------------------------------------------------------------

test('AVA SPYWARE RISK AUDIT script should exist', () => {
	assert.ok(fs.existsSync(spywareRiskAuditScriptPath));
});

test('AVA SPYWARE RISK AUDIT script should parse without PowerShell syntax errors', () => {
	const escapedPath = spywareRiskAuditScriptPath.replace(/'/g, "''");
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

test('AVA SPYWARE RISK AUDIT script should not contain pasted template artifacts', () => {
	assert.ok(!spywareRiskAuditScriptContents.includes('<__filter_complete__>'));
	assert.ok(!spywareRiskAuditScriptContents.includes('2&gt;&amp;1'));
});

test('AVA SPYWARE RISK AUDIT script should define read-only audit/tangle/report outputs', () => {
	assert.ok(spywareRiskAuditScriptContents.includes('AVA SPYWARE RISK AUDIT'));
	assert.ok(spywareRiskAuditScriptContents.includes("Read-Only / Lokal / Keine Änderungen"));
	assert.ok(spywareRiskAuditScriptContents.includes("Write-Tangle -Type 'AVA_SPYWARE_RISK_AUDIT'"));
	assert.ok(spywareRiskAuditScriptContents.includes('ava_spyware_risk_audit.html'));
	assert.ok(spywareRiskAuditScriptContents.includes('ava_spyware_risk_audit.json'));
	assert.ok(spywareRiskAuditScriptContents.includes('ava_spyware_risk_audit.txt'));
	assert.ok(spywareRiskAuditScriptContents.includes('Get-MpComputerStatus'));
	assert.ok(spywareRiskAuditScriptContents.includes('Get-NetTCPConnection -State Established'));
});

// ---------------------------------------------------------------------------
// AVA AUTO START + 5 MIN REPEAT
// ---------------------------------------------------------------------------

const autoStartScriptPath = path.join(__dirname, '..', 'scripts', 'AvaAutoStart.ps1');
const autoStartScriptContents = fs.readFileSync(autoStartScriptPath, 'utf8');

test('AVA Auto Start script should exist', () => {
	assert.ok(fs.existsSync(autoStartScriptPath));
});

test('AVA Auto Start script should parse without PowerShell syntax errors', () => {
	const escapedPath = autoStartScriptPath.replace(/'/g, "''");
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

test('AVA Auto Start script should not contain pasted template artifacts', () => {
	assert.ok(!autoStartScriptContents.includes('<__filter_complete__>'));
	assert.ok(!autoStartScriptContents.includes('2&gt;&amp;1'));
});

test('AVA Auto Start script should define scheduled task with correct settings', () => {
	assert.ok(autoStartScriptContents.includes('AVA_SOC_V7_SAFE'));
	assert.ok(autoStartScriptContents.includes('Register-ScheduledTask'));
	assert.ok(autoStartScriptContents.includes('PT5M'));
	assert.ok(autoStartScriptContents.includes('P36500D'));
	assert.ok(autoStartScriptContents.includes('RunLevel Highest'));
	assert.ok(autoStartScriptContents.includes('New-ScheduledTaskAction'));
	assert.ok(autoStartScriptContents.includes('New-ScheduledTaskTrigger'));
	assert.ok(autoStartScriptContents.includes('New-ScheduledTaskSettingsSet'));
});

// ---------------------------------------------------------------------------
// SecurityGuardian + Memory scripts — local defensive/private scope checks
// ---------------------------------------------------------------------------

test('SecurityGuardian script should exist', () => {
	assert.ok(fs.existsSync(securityGuardianScriptPath));
});

test('SecurityGuardian script should parse without PowerShell syntax errors', () => {
	const escapedPath = securityGuardianScriptPath.replace(/'/g, "''");
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

test('SecurityGuardian script should declare local defensive non-offensive intent', () => {
	assert.ok(securityGuardianScriptContents.includes('Lokal / Defensiv / Administrative Hardening'));
	assert.ok(securityGuardianScriptContents.includes('Keine Angriffe'));
	assert.ok(securityGuardianScriptContents.includes('Keine Exploits'));
	assert.ok(securityGuardianScriptContents.includes('Keine Fremdscans'));
});

test('AVA Symbolic Memory Portal script should exist', () => {
	assert.ok(fs.existsSync(symbolicMemoryPortalScriptPath));
});

test('AVA Symbolic Memory Portal script should parse without PowerShell syntax errors', () => {
	const escapedPath = symbolicMemoryPortalScriptPath.replace(/'/g, "''");
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

test('AVA Symbolic Memory Portal script should declare local private read-only scope', () => {
	assert.ok(symbolicMemoryPortalScriptContents.includes('Lokal / Privat / Read-Only / Kein Upload / Keine Überwachung'));
});

test('Wandersmann Memory Core script should exist', () => {
	assert.ok(fs.existsSync(wandersmannMemoryCoreScriptPath));
});

test('Wandersmann Memory Core script should parse without PowerShell syntax errors', () => {
	const escapedPath = wandersmannMemoryCoreScriptPath.replace(/'/g, "''");
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

test('Wandersmann Memory Core script should declare local private no-upload scope', () => {
	assert.ok(wandersmannMemoryCoreScriptContents.includes('Lokal / Privat / Erinnerungsportal'));
	assert.ok(wandersmannMemoryCoreScriptContents.includes('Keine Cloud. Kein Upload. Keine Überwachung.'));
});

// ---------------------------------------------------------------------------
// AVA SOC Portal V6 — Safe Edition (snapshot + analysis JSON output)
// ---------------------------------------------------------------------------

const v6SafeScriptPath = path.join(__dirname, '..', 'scripts', 'AvaSocPortalV6Safe.ps1');
const v6SafeScriptContents = fs.readFileSync(v6SafeScriptPath, 'utf8');

test('AVA SOC Portal V6 Safe script should exist', () => {
	assert.ok(fs.existsSync(v6SafeScriptPath));
});

test('AVA SOC Portal V6 Safe script should parse without PowerShell syntax errors', () => {
	const escapedPath = v6SafeScriptPath.replace(/'/g, "''");
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

test('AVA SOC Portal V6 Safe script should not contain pasted template artifacts', () => {
	assert.ok(!v6SafeScriptContents.includes('<__filter_complete__>'));
	assert.ok(!v6SafeScriptContents.includes('2&gt;&amp;1'));
});

test('AVA SOC Portal V6 Safe script should define portal, snapshot and analysis JSON outputs', () => {
	assert.ok(v6SafeScriptContents.includes('AVA SOC PORTAL V6 SAFE'));
	assert.ok(v6SafeScriptContents.includes('ava_soc_portal_v6_safe.html'));
	assert.ok(v6SafeScriptContents.includes('snapshot_latest.json'));
	assert.ok(v6SafeScriptContents.includes('analysis_latest.json'));
	assert.ok(v6SafeScriptContents.includes('function Build-Portal'));
	assert.ok(v6SafeScriptContents.includes('function New-Snapshot'));
	assert.ok(v6SafeScriptContents.includes('function Analyze-Snapshot'));
	assert.ok(v6SafeScriptContents.includes('function Write-Tangle'));
});

// ---------------------------------------------------------------------------
// AVA SAFE AUDIT CHAT MODE v1
// ---------------------------------------------------------------------------

test('AVA SAFE AUDIT CHAT MODE v1 script should exist', () => {
	assert.ok(fs.existsSync(safeAuditScriptPath));
});

test('AVA SAFE AUDIT CHAT MODE v1 script should parse without PowerShell syntax errors', () => {
	const escapedPath = safeAuditScriptPath.replace(/'/g, "''");
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

test('AVA SAFE AUDIT CHAT MODE v1 script should define read-only audit outputs', () => {
	assert.ok(safeAuditScriptContents.includes('SAFE_AUDIT_CHAT_MODE_v1'));
	assert.ok(safeAuditScriptContents.includes('Read-only audit. No firewall, Defender, Registry, user, service, or scheduled-task changes.'));
	assert.ok(safeAuditScriptContents.includes('Run-Safe'));
	assert.ok(safeAuditScriptContents.includes('20_findings'));
	assert.ok(safeAuditScriptContents.includes('AVA_SAFE_AUDIT_REPORT.html'));
	assert.ok(safeAuditScriptContents.includes('Compress-Archive'));
});

test('AVA SAFE AUDIT admin starter should exist and call the script', () => {
	assert.ok(fs.existsSync(safeAuditStarterPath));
	assert.ok(safeAuditStarterContents.includes('AVA_SAFE_AUDIT_CHAT_MODE_v1.ps1'));
	assert.ok(safeAuditStarterContents.includes('-ExecutionPolicy Bypass'));
	assert.ok(safeAuditStarterContents.includes('-OpenReport'));
});

console.log(`\n${passed} passing, ${failed} failing`);
process.exit(failed > 0 ? 1 : 0);
