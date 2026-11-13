'use strict';

const assert = require('assert');
const fs = require('fs');
const path = require('path');

const scriptPath = path.join(__dirname, '..', 'scripts', 'AVA_01610_SAFE_STARTPLAN.ps1');
const script = fs.readFileSync(scriptPath, 'utf8');

const expectedLaunchers = [
  'START_AVA_DEVITO_01610_SAFE_AUDIT_READONLY.cmd',
  'START_AVA_SAFE_AUDIT_ADMIN.cmd',
  'START_01_RUNONCE_ADMIN.cmd',
  'START_02_LIVE_PREVIEW_ADMIN.cmd',
  'START_03_LIVE_AUTODEFENSE_MIT_BESTAETIGUNG_ADMIN.cmd',
  'START_04_ROLLBACK_BLOCKS_ADMIN.cmd',
];

for (const launcher of expectedLaunchers) {
  assert.ok(script.includes(launcher), 'safe-start inventory must include ' + launcher);
}

assert.ok(script.includes("mode = 'READ_ONLY'"));
assert.ok(script.includes('launchersExecuted = $false'));
assert.ok(script.includes('autoDefenseEnabled = $false'));
assert.ok(script.includes('firewallChanged = $false'));
assert.ok(script.includes('defenderChanged = $false'));
assert.ok(script.includes('registryChanged = $false'));
assert.ok(script.includes('networkCallsMade = 0'));
assert.ok(script.includes('absolutePackagePathIncluded = $false'));
assert.ok(script.includes("manualApprovalRequired = $true"));

const forbiddenActiveCommands = [
  'Start-Process',
  'Invoke-Expression',
  'Invoke-WebRequest',
  'Invoke-RestMethod',
  'Invoke-Command',
  'New-NetFirewallRule',
  'Set-NetFirewallProfile',
  'Set-MpPreference',
  'Register-ScheduledTask',
  'Set-ItemProperty',
];

for (const command of forbiddenActiveCommands) {
  assert.ok(!script.includes(command), 'read-only inventory must not contain ' + command);
}

// Preserve first snapshot: successive runs must never reuse a timestamp-only folder.
const winAuditPath = path.join(__dirname, '..', 'scripts', 'windows', 'AVA_DEVITO_01610_SAFE_AUDIT_READONLY.ps1');
const winAuditScript = fs.readFileSync(winAuditPath, 'utf8');
assert.ok(winAuditScript.includes("Get-Date -Format 'yyyyMMdd_HHmmss_fffffff'"), 'high-resolution timestamp required');
assert.ok(winAuditScript.includes("[guid]::NewGuid().ToString('N')"), 'unique run token required');
assert.ok(winAuditScript.includes("if (Test-Path -LiteralPath $outDir)"), 'existing output must trigger stop');
assert.ok(winAuditScript.includes("New-Item -ItemType Directory -Path $outDir -ErrorAction Stop"), 'directory creation must fail closed');
assert.ok(!winAuditScript.includes("New-Item -ItemType Directory -Path $outDir -Force"), 'audit must not force-reuse output directory');
for (const forbidden of ['Remove-NetFirewallRule', 'New-NetFirewallRule', 'Set-MpPreference', 'Register-ScheduledTask', 'Start-Process', 'Invoke-Expression']) {
  assert.ok(!winAuditScript.includes(forbidden), 'read-only audit must not contain command ' + forbidden);
}

console.log('AVA safe-start plan tests: ' + expectedLaunchers.length + ' launchers, boundaries and unique audit output checks passed.');
