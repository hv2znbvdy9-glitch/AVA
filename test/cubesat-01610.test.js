'use strict';

const assert = require('assert');
const path = require('path');
const {execFileSync} = require('child_process');
const {
	cubeSat01610Report,
	cubeSat01610Data,
	CUBESAT_01610_REPORT,
	CUBESAT_01610_PHASES,
	CUBESAT_01610_BUDGET_TIERS,
	CUBESAT_01610_SPECIFICATION,
	ALLOWED_CUBESAT_ACTIONS,
	computeSha256,
	signCubeSatCommand,
	verifyCubeSatCommand,
	simulateCubeSat,
} = require('../src/cubesat-01610');
const library = require('../src');

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

console.log('cubesat 01610 tests\n');

test('cubeSat01610Report includes mission profile, phases, and evidence principles', () => {
	const report = cubeSat01610Report();
	assert.ok(report.includes('AVA 01610-1 — CubeSat-Eigenbau: Evidenz vor Aktion'));
	assert.ok(report.includes('1U-CubeSat'));
	assert.ok(report.includes('Phase A (Bodensimulation)'));
	assert.ok(report.includes('Phase B (Engineering-Modell)'));
	assert.ok(report.includes('Phase C (Flugmodell'));
	assert.ok(report.includes('SHA-256'));
	assert.ok(report.includes('HMAC-SHA256'));
	assert.ok(report.includes('Unter 1.000 €'));
	assert.ok(report.includes('docs/ava-01610-cubesat-eigenbau.md'));
});

test('cubeSat01610Data exposes structured phases, budget tiers, and specifications', () => {
	const data = cubeSat01610Data();
	assert.strictEqual(data.title, 'AVA 01610-1 CubeSat-Eigenbau');
	assert.strictEqual(data.principle, 'Evidenz vor Aktion');
	assert.strictEqual(data.phases.length, 3);
	assert.strictEqual(data.phases[0].phase, 'Phase A');
	assert.strictEqual(data.phases[1].phase, 'Phase B');
	assert.strictEqual(data.phases[2].phase, 'Phase C');
	assert.strictEqual(data.budgetTiers.length, 3);
	assert.strictEqual(data.specification.standard, '1U CubeSat');
	assert.strictEqual(data.specification.dimensionsMm.width, 100);
	assert.strictEqual(data.specification.maxMassKg, 1.33);
});

test('framework constants are frozen and data results are isolated', () => {
	assert.ok(Object.isFrozen(CUBESAT_01610_PHASES));
	assert.ok(Object.isFrozen(CUBESAT_01610_BUDGET_TIERS));
	assert.ok(Object.isFrozen(CUBESAT_01610_SPECIFICATION));
	assert.ok(Object.isFrozen(ALLOWED_CUBESAT_ACTIONS));

	const data1 = cubeSat01610Data();
	data1.phases.push({ phase: 'Phase D' });
	data1.budgetTiers.pop();
	const data2 = cubeSat01610Data();
	assert.strictEqual(data2.phases.length, 3);
	assert.strictEqual(data2.budgetTiers.length, 3);
});

test('computeSha256 produces valid 64-char hex string', () => {
	const hash = computeSha256('AVA-01610');
	assert.strictEqual(typeof hash, 'string');
	assert.strictEqual(hash.length, 64);
	assert.strictEqual(computeSha256('AVA-01610'), hash);
});

test('signCubeSatCommand and verifyCubeSatCommand authenticate valid signatures', () => {
	const secret = 'SECRET_TEST_KEY_42';
	const cmd = {
		source: 'Bodenstation',
		target: 'AVA-01610-1',
		action: 'AdjustAltitude',
		params: { altitudeKm: 480 },
		nonce: 1001,
	};
	const signature = signCubeSatCommand(cmd, secret);
	assert.strictEqual(typeof signature, 'string');
	assert.strictEqual(signature.length, 64);

	assert.strictEqual(verifyCubeSatCommand(cmd, signature, secret), true);
	// Wrong signature
	assert.strictEqual(verifyCubeSatCommand(cmd, 'a'.repeat(64), secret), false);
	// Tampered param
	const tamperedCmd = { ...cmd, params: { altitudeKm: 200 } };
	assert.strictEqual(verifyCubeSatCommand(tamperedCmd, signature, secret), false);
	// Invalid signature format
	assert.strictEqual(verifyCubeSatCommand(cmd, '', secret), false);
	assert.strictEqual(verifyCubeSatCommand(cmd, null, secret), false);
});

test('simulateCubeSat runs nominal ground simulation with verified hash chain', () => {
	const sim = simulateCubeSat({
		durationMinutes: 190,
		stepMinutes: 10,
	});

	assert.strictEqual(sim.chainVerified, true);
	assert.strictEqual(typeof sim.evidenceRoot, 'string');
	assert.strictEqual(sim.evidenceRoot.length, 64);
	assert.strictEqual(sim.summary.totalDurationMinutes, 190);
	assert.strictEqual(sim.summary.totalSteps, 20); // 0, 10, ..., 190 = 20 steps
	assert.ok(sim.summary.totalOrbits >= 2);
	assert.ok(sim.summary.minBatteryPercent > 0);
	assert.ok(sim.summary.maxBatteryPercent <= 100);

	// Verify each packet links to previous
	for (let i = 1; i < sim.telemetryChain.length; i++) {
		assert.strictEqual(sim.telemetryChain[i].prevHash, sim.telemetryChain[i - 1].hash);
	}
});

test('simulateCubeSat accepts valid commands and updates state', () => {
	const secretKey = 'TEST_KEY_SIM';
	const cmd1 = {
		source: 'Bodenstation',
		target: 'AVA-01610-1',
		action: 'AdjustAltitude',
		params: { altitudeKm: 520.0 },
		nonce: 2001,
	};
	cmd1.signature = signCubeSatCommand(cmd1, secretKey);

	const cmd2 = {
		source: 'Bodenstation',
		target: 'AVA-01610-1',
		action: 'DeployAntenna',
		params: {},
		nonce: 2002,
	};
	cmd2.signature = signCubeSatCommand(cmd2, secretKey);

	const cmd3 = {
		source: 'Bodenstation',
		target: 'AVA-01610-1',
		action: 'SetPowerMode',
		params: { mode: 'LOW_POWER' },
		nonce: 2003,
	};
	cmd3.signature = signCubeSatCommand(cmd3, secretKey);

	const sim = simulateCubeSat({
		durationMinutes: 95,
		stepMinutes: 10,
		secretKey,
		commands: [cmd1, cmd2, cmd3],
	});

	assert.strictEqual(sim.summary.commandsEvaluated, 3);
	assert.strictEqual(sim.summary.commandsAccepted, 3);
	assert.strictEqual(sim.summary.commandsRejected, 0);
	assert.strictEqual(sim.summary.finalAltitudeKm, 520.0);
	assert.strictEqual(sim.summary.antennaDeployed, true);
	assert.strictEqual(sim.summary.finalPowerMode, 'LOW_POWER');
});

test('simulateCubeSat rejects forged, replayed, and unwhitelisted commands', () => {
	const secretKey = 'TEST_KEY_SIM';

	// 1. Valid command
	const validCmd = {
		source: 'Bodenstation',
		target: 'AVA-01610-1',
		action: 'Ping',
		params: {},
		nonce: 3001,
	};
	validCmd.signature = signCubeSatCommand(validCmd, secretKey);

	// 2. Replay of valid command with identical nonce
	const replayCmd = { ...validCmd };

	// 3. Forged signature
	const forgedCmd = {
		source: 'Relais_Attacker',
		target: 'AVA-01610-1',
		action: 'AdjustAltitude',
		params: { altitudeKm: 0 },
		nonce: 3002,
		signature: 'f'.repeat(64),
	};

	// 4. Unauthorized action
	const unauthorizedCmd = {
		source: 'Bodenstation',
		target: 'AVA-01610-1',
		action: 'DeorbitNow',
		params: {},
		nonce: 3003,
	};
	unauthorizedCmd.signature = signCubeSatCommand(unauthorizedCmd, secretKey);

	const sim = simulateCubeSat({
		durationMinutes: 95,
		stepMinutes: 10,
		secretKey,
		commands: [validCmd, replayCmd, forgedCmd, unauthorizedCmd],
	});

	assert.strictEqual(sim.summary.commandsEvaluated, 4);
	assert.strictEqual(sim.summary.commandsAccepted, 1);
	assert.strictEqual(sim.summary.commandsRejected, 3);

	const statuses = sim.securityLog.map((log) => log.status);
	assert.deepStrictEqual(statuses, [
		'ACCEPTED_EXECUTED',
		'REJECTED_REPLAY',
		'REJECTED_INVALID_SIGNATURE',
		'REJECTED_UNAUTHORIZED_ACTION',
	]);
});

test('library exports CubeSat module and functions', () => {
	assert.strictEqual(library.cubeSat01610Report, cubeSat01610Report);
	assert.strictEqual(library.cubeSat01610Data, cubeSat01610Data);
	assert.strictEqual(library.CUBESAT_01610_REPORT, CUBESAT_01610_REPORT);
	assert.strictEqual(library.CUBESAT_01610_PHASES, CUBESAT_01610_PHASES);
	assert.strictEqual(library.CUBESAT_01610_BUDGET_TIERS, CUBESAT_01610_BUDGET_TIERS);
	assert.strictEqual(library.CUBESAT_01610_SPECIFICATION, CUBESAT_01610_SPECIFICATION);
	assert.strictEqual(library.ALLOWED_CUBESAT_ACTIONS, ALLOWED_CUBESAT_ACTIONS);
	assert.strictEqual(library.simulateCubeSat, simulateCubeSat);
	assert.strictEqual(library.signCubeSatCommand, signCubeSatCommand);
	assert.strictEqual(library.verifyCubeSatCommand, verifyCubeSatCommand);
});

test('CLI flag and command print the report and simulation output', () => {
	const cliPath = path.join(__dirname, '..', 'bin', 'cli.js');

	for (const cmd of ['--cubesat', 'cubesat']) {
		const stdout = execFileSync(process.execPath, [cliPath, cmd], { encoding: 'utf8' });
		assert.ok(stdout.includes('AVA 01610-1 — CubeSat-Eigenbau: Evidenz vor Aktion'));
		assert.ok(stdout.includes('Phase A (Bodensimulation)'));
	}

	for (const cmd of ['--cubesat-sim', 'cubesat-sim']) {
		const stdout = execFileSync(process.execPath, [cliPath, cmd], { encoding: 'utf8' });
		const parsed = JSON.parse(stdout);
		assert.ok(parsed.totalSteps > 0);
		assert.ok(parsed.totalOrbits > 0);
	}
});

console.log(`\n${passed} passing, ${failed} failing`);
process.exit(failed > 0 ? 1 : 0);
