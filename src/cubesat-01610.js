'use strict';

const crypto = require('crypto');

const CUBESAT_01610_PHASES = Object.freeze([
	Object.freeze({
		phase: 'Phase A',
		name: 'Bodensimulation (Software & Virtuelles Labor)',
		objective: 'Vollständige Prüfung der Satellitenlogik, Telemetrie und Sicherheitsüberwachung ohne Hardware- und Startkosten.',
		budgetRange: '< 1.000 €',
		focus: [
			'Modellierung des 1U-CubeSat-Systems (OBC, EPS, Batterie, Solarzyklen)',
			'Orbit-Simulation (LEO, 90–95 min Umlaufzeit, Licht-/Schattenphasen, Temperaturzyklen)',
			'Telemetrie- und Evidenzkette mit kryptografischer SHA-256-Verkettung',
			'HMAC-SHA256-Befehlsauthentifizierung und Anti-Replay-Schutz',
			'Automatisierte Unit- und Integrationstests mit reproduzierbaren Prüfberichten',
		],
		deliverables: [
			'Virtueller Satellitensimulator (EPS, Sensorik, Orbit)',
			'Integritätsgesicherte Telemetriekette (Hash-Chain)',
			'Befehlsverifikation mit Nonce-Tracking',
			'Prüfprotokolle und Testsuite',
		],
	}),
	Object.freeze({
		phase: 'Phase B',
		name: 'Engineering-Modell (Hardware-in-the-Loop)',
		objective: 'Validierung der Flugsoftware, Stromversorgung, Sensorik und Funkstrecke auf physischer Labor-Hardware.',
		budgetRange: '1.000–10.000 €',
		focus: [
			'Komponentenauswahl für 1U-Formfaktor (Mikrocontroller, Sensoren, EPS-Platine, LiFePO4-Zellen)',
			'Flugsoftware-Portierung mit Watchdog-Timer und autonomer Ausfallsicherung',
			'Aufbau einer lokalen Test-Bodenstation (SDR, Transceiver, Test-Antenne)',
			'Bidirektionale HF-Übertragungstests unter Laborbedingungen',
		],
		deliverables: [
			'1U-Flachbett- oder Prototypen-Chassis mit Funktionsmodulen',
			'Portierte Firmware mit Watchdog-Überwachung',
			'Lokale SDR-Bodenstation für Telemetrieempfang',
			'Labor-Prüfbericht zur Kommunikations- und Energiezuverlässigkeit',
		],
	}),
	Object.freeze({
		phase: 'Phase C',
		name: 'Flugmodell (Qualifikation, Regulatorik & Start)',
		objective: 'Herstellung des flugfähigen Modells, Erfüllung aller regulatorischen Auflagen und Startintegration im Rideshare.',
		budgetRange: '> 10.000 € (typisch 25.000–60.000 € inkl. Startplatz)',
		focus: [
			'Vollständige Gesamtkostenaufstellung (Struktur, Raumfahrt-Komponenten, Tests, Rideshare-Slot)',
			'Regulatorischer Rahmen (Frequenzzuteilung BNetzA, IARU-Koordination, Weltraumregistrierung, Haftung)',
			'Umwelttests zur Flugqualifikation (Thermisches Vakuum / TVAC, Vibration, Schock, EMV)',
			'Startintegration mit Rideshare-Anbieter (Deployer-Spezifikation, Sicherheitsfreigabe)',
		],
		deliverables: [
			'Flugmodell (Flight Model, FM) gemäß 1U-CubeSat-Standard',
			'Frequenzgenehmigungen und behördliche Nachweise',
			'Qualifikations- und Abnahmeprotokolle (TVAC, Vibration)',
			'Startbereitschaftserklärung (Flight Readiness Certificate)',
		],
	}),
]);

const CUBESAT_01610_BUDGET_TIERS = Object.freeze([
	Object.freeze({
		tier: 'Unter 1.000 €',
		scope: 'Reine Bodensimulation & Software-Labor',
		feasibility: 'Sofort umsetzbar ohne finanzielles Risiko.',
		components: [
			'Virtuelle Telemetrie- und EPS-Simulation am Rechner',
			'Kryptografische Evidenzkette mit SHA-256 und HMAC',
			'Lokale Befehls- und Kontrollvalidierung (Mock-Bodenstation)',
			'Vollständige Testberichte vor jeder Investition',
		],
	}),
	Object.freeze({
		tier: '1.000–10.000 €',
		scope: 'Engineering-Modell (Hardware-in-the-Loop)',
		feasibility: 'Laborprototyp ohne Startplatz; ideale Vorbereitung auf Flugmodell.',
		components: [
			'Entwicklungsplatinen (STM32 / ESP32 / Raspberry Pi Pico Space Grade)',
			'Solarzellen-Muster, Akkumulatoren, EPS-Laderegler',
			'Sensor-Suite (IMU, Magnetometer, Temperatur, Strahlungsmonitor)',
			'SDR-Bodenstations-Setup (Software Defined Radio + Antennenadapter)',
		],
	}),
	Object.freeze({
		tier: '10.000–50.000 €+',
		scope: 'Vollständiges Flugmodell & Rideshare-Start',
		feasibility: 'Erfordert Frequenzzuteilung, TVAC-Vibrationstests und Startplatz-Buchung.',
		components: [
			'Qualifizierte 1U-Struktur mit Space-Deployer-Schnittstelle',
			'Weltraumtaugliche Solarpanels und Akkusysteme',
			'Zertifizierte Umwelt- und Schwingungstests im Fachlabor',
			'Rideshare-Startgebühr und Startkampagnen-Integration',
		],
	}),
]);

const CUBESAT_01610_SPECIFICATION = Object.freeze({
	standard: '1U CubeSat',
	dimensionsMm: Object.freeze({ width: 100, depth: 100, height: 100 }),
	maxMassKg: 1.33,
	nominalOrbit: Object.freeze({
		type: 'LEO (Low Earth Orbit)',
		altitudeKm: 500,
		inclinationDeg: 97.4,
		periodMinutes: 94.6,
		sunlightMinutes: 59.0,
		eclipseMinutes: 35.6,
	}),
	powerBudgetWatts: Object.freeze({
		solarGenerationSunlight: 2.5,
		consumptionIdle: 0.8,
		consumptionTransmitting: 2.2,
		consumptionEclipse: 0.7,
	}),
	securityArchitecture: Object.freeze({
		telemetryIntegrity: 'SHA-256 Hash Chain (Merkle-Verkettung)',
		commandAuthentication: 'HMAC-SHA256 mit ephemeren oder sicheren Schlüsseln',
		replayDefense: 'Monoton steigender Nonce-Speicher pro Satellit',
		authorizationPolicy: 'Strikte Whitelist erlaubter Aktionen',
	}),
});

const CUBESAT_01610_REPORT = `🛰️ AVA 01610-1 — CubeSat-Eigenbau: Evidenz vor Aktion

Leitprinzip:
Erst die bodengebundene Simulation und reproduzierbare Evidenz sichern, bevor
finanzielle Mittel für Bausätze, Hardware-Qualifikation oder einen Raketenstart
gebunden werden. Ein 1U-CubeSat (10 × 10 × 10 cm, max. 1,33 kg) ist physikalisch
machbar, die Gesamtkosten hängen jedoch entscheidend vom Zielstadium ab.

1. Budget- und Grenzwertanalyse
- Unter 1.000 €: Reine Bodensimulation am PC. Telemetrie, Sensorik, Energiehaushalt
  und Sicherheitsarchitektur werden deterministisch und ohne Risiko validiert.
- 1.000–10.000 €: Engineering-Modell (Hardware-in-the-Loop). Aufbau eines Labor-
  Prototyps mit Mikrocontrollern, Sensorplatinen, EPS-Ladereglern und SDR-Funk.
- Über 10.000 €: Flugmodell inkl. Rideshare. Startplatz-Gebühren, TVAC-Prüfung,
  Schwingungstests und Genehmigungen erfordern typischerweise 25.000–60.000 €.

2. Phasenplan
- Phase A (Bodensimulation):
  * Modellierung von On-Board-Computer (OBC), EPS und Batteriezyklen.
  * LEO-Orbit-Dynamik (Umlaufzeit ~95 min mit Licht- und Schattenphasen).
  * Strukturierte Telemetriepakete mit lückenloser SHA-256-Hash-Kette.
  * Authentifizierte Befehlskontrolle (HMAC-SHA256) und Replay-Abwehr.
- Phase B (Engineering-Modell):
  * Hardware-Auswahl für 1U-Chassis und Mikrocontroller.
  * Portierung der Simulationslogik auf eingebettete Flugsoftware.
  * Watchdog-Integration und Ausfallsicherung bei Stromschwankungen.
  * Labor-Bodenstation mit Software Defined Radio (SDR).
- Phase C (Flugmodell, Regulatorik & Qualifikation):
  * Frequenzkoordination mit IARU und Bundesnetzagentur (BNetzA).
  * Raumfahrt-Haftung und Eintragung in das UN-Weltraumregister.
  * Qualifikationstests: Thermisches Vakuum (TVAC), Vibration und EMV.
  * Startintegration in den Satelliten-Deployer des Rideshare-Anbieters.

3. Evidenz- und Sicherheitsarchitektur
- Telemetrie-Integrität: Jedes Paket verlinkt kryptografisch auf den Hash seines
  Vorgängers. Manipulationen an historischen Daten sind sofort erkennbar.
- Befehls-Authentifizierung: Jeder Steuerbefehl wird mit HMAC-SHA256 signiert.
- Replay-Schutz: Jeder Befehl enthält eine eindeutige Nonce; duplizierte Befehle
  werden abgewiesen.
- Whitelist-Richtlinie: Nicht registrierte Befehle werden trotz gültiger Signatur
  verworfen.

Dokumentation: docs/ava-01610-cubesat-eigenbau.md`;

/**
 * Returns the human-readable text report for AVA 01610-1 CubeSat.
 * @returns {string}
 */
function cubeSat01610Report() {
	return CUBESAT_01610_REPORT;
}

/**
 * Returns a structured copy of the CubeSat project plan, budget tiers, and specifications.
 * @returns {object}
 */
function cubeSat01610Data() {
	return {
		title: 'AVA 01610-1 CubeSat-Eigenbau',
		principle: 'Evidenz vor Aktion',
		specification: JSON.parse(JSON.stringify(CUBESAT_01610_SPECIFICATION)),
		phases: JSON.parse(JSON.stringify(CUBESAT_01610_PHASES)),
		budgetTiers: JSON.parse(JSON.stringify(CUBESAT_01610_BUDGET_TIERS)),
	};
}

/**
 * Computes a SHA-256 hash string for given input text.
 * @param {string} text
 * @returns {string} Hex encoded SHA-256
 */
function computeSha256(text) {
	return crypto.createHash('sha256').update(text, 'utf8').digest('hex');
}

/**
 * Computes an HMAC-SHA256 signature for a command payload.
 * @param {object} payload
 * @param {string|Buffer} secretKey
 * @returns {string} Hex encoded signature
 */
function signCubeSatCommand(payload, secretKey) {
	const canonical = JSON.stringify({
		source: payload.source,
		target: payload.target,
		action: payload.action,
		params: payload.params || {},
		nonce: payload.nonce,
	});
	return crypto.createHmac('sha256', secretKey).update(canonical, 'utf8').digest('hex');
}

/**
 * Verifies an HMAC-SHA256 signature on a command payload.
 * @param {object} payload
 * @param {string} signature
 * @param {string|Buffer} secretKey
 * @returns {boolean}
 */
function verifyCubeSatCommand(payload, signature, secretKey) {
	if (!signature || typeof signature !== 'string') {
		return false;
	}
	const expected = signCubeSatCommand(payload, secretKey);
	const expectedBuf = Buffer.from(expected, 'hex');
	const actualBuf = Buffer.from(signature, 'hex');
	if (expectedBuf.length !== actualBuf.length) {
		return false;
	}
	return crypto.timingSafeEqual(expectedBuf, actualBuf);
}

/**
 * Allowed command actions for the 1U CubeSat command decoder.
 */
const ALLOWED_CUBESAT_ACTIONS = Object.freeze([
	'Ping',
	'AdjustAltitude',
	'ResetEPS',
	'SetPowerMode',
	'DeployAntenna',
	'CollectTelemetry',
]);

/**
 * Simulates the AVA 01610-1 Phase A ground simulation (Bodensimulation).
 * Models 1U CubeSat LEO orbit, EPS energy budget, thermal cycle, telemetry hash-chain,
 * and command verification with replay defense.
 *
 * @param {object} [options]
 * @param {number} [options.durationMinutes=190] Total simulation time in minutes
 * @param {number} [options.stepMinutes=10] Time step per telemetry packet
 * @param {number} [options.orbitPeriodMinutes=94.6] Orbit period in minutes
 * @param {number} [options.eclipseMinutes=35.6] Eclipse duration per orbit
 * @param {number} [options.batteryCapacityWh=10] Max battery capacity in Watt-hours
 * @param {number} [options.initialBatteryPercent=90] Starting battery charge percentage
 * @param {string|Buffer} [options.secretKey] Shared HMAC secret key
 * @param {Array<object>} [options.commands] Uplink commands to evaluate during simulation
 * @returns {object} Simulation results including telemetry chain, security log, and verification status
 */
function simulateCubeSat(options = {}) {
	const durationMinutes = Number(options.durationMinutes) > 0 ? Number(options.durationMinutes) : 190;
	const stepMinutes = Number(options.stepMinutes) > 0 ? Number(options.stepMinutes) : 10;
	const orbitPeriod = Number(options.orbitPeriodMinutes) > 0 ? Number(options.orbitPeriodMinutes) : 94.6;
	const eclipseDuration = Number(options.eclipseMinutes) > 0 ? Number(options.eclipseMinutes) : 35.6;
	const batteryCapacityWh = Number(options.batteryCapacityWh) > 0 ? Number(options.batteryCapacityWh) : 10.0;
	const initialBatteryPercent = Math.max(10, Math.min(100, Number(options.initialBatteryPercent) || 90));

	const secretKey = options.secretKey || 'AVA_01610_CUBESAT_GROUND_KEY_DEFAULT';
	const inputCommands = Array.isArray(options.commands) ? options.commands : [];

	let currentBatteryWh = (initialBatteryPercent / 100) * batteryCapacityWh;
	let currentAltitudeKm = CUBESAT_01610_SPECIFICATION.nominalOrbit.altitudeKm;
	let powerMode = 'NOMINAL';
	let antennaDeployed = false;

	const seenNonces = new Set();
	const telemetryChain = [];
	const securityLog = [];
	let prevHash = '0000000000000000000000000000000000000000000000000000000000000000';

	let stepIndex = 0;
	for (let minute = 0; minute <= durationMinutes; minute += stepMinutes) {
		const orbitMinute = minute % orbitPeriod;
		const inSunlight = orbitMinute < (orbitPeriod - eclipseDuration);
		const orbitNumber = Math.floor(minute / orbitPeriod) + 1;

		// Solar generation
		const solarWatts = inSunlight ? CUBESAT_01610_SPECIFICATION.powerBudgetWatts.solarGenerationSunlight : 0.0;

		// Power consumption
		let loadWatts = CUBESAT_01610_SPECIFICATION.powerBudgetWatts.consumptionIdle;
		if (powerMode === 'LOW_POWER') {
			loadWatts = 0.4;
		} else if (minute % 30 === 0) {
			// Periodic beacon transmission
			loadWatts = CUBESAT_01610_SPECIFICATION.powerBudgetWatts.consumptionTransmitting;
		}

		// Battery update: net energy in Watt-hours for this step
		const netWatts = solarWatts - loadWatts;
		const netWh = netWatts * (stepMinutes / 60);
		currentBatteryWh = Math.max(0, Math.min(batteryCapacityWh, currentBatteryWh + netWh));
		const batteryPercent = Number(((currentBatteryWh / batteryCapacityWh) * 100).toFixed(1));

		// Thermal model: equilibrium around +28°C in sun, -12°C in eclipse
		const targetTemp = inSunlight ? 26.0 : -10.0;
		const tempVariation = Math.sin((orbitMinute / orbitPeriod) * Math.PI * 2) * 5.0;
		const temperatureCelsius = Number((targetTemp + tempVariation).toFixed(2));

		// Voltage estimation: 3.4V (empty) to 4.2V (full)
		const voltage = Number((3.4 + (batteryPercent / 100) * 0.8).toFixed(3));

		const packetPayload = {
			step: stepIndex,
			minute,
			orbitNumber,
			inSunlight,
			altitudeKm: Number(currentAltitudeKm.toFixed(1)),
			temperatureCelsius,
			solarWatts: Number(solarWatts.toFixed(2)),
			loadWatts: Number(loadWatts.toFixed(2)),
			batteryWh: Number(currentBatteryWh.toFixed(3)),
			batteryPercent,
			voltage,
			powerMode,
			antennaDeployed,
			prevHash,
		};

		const canonicalPayload = JSON.stringify(packetPayload);
		const packetHash = computeSha256(canonicalPayload);

		const telemetryPacket = {
			...packetPayload,
			hash: packetHash,
		};

		telemetryChain.push(telemetryPacket);
		prevHash = packetHash;
		stepIndex++;
	}

	// Process simulated commands
	for (const cmd of inputCommands) {
		const source = cmd.source || 'Bodenstation';
		const target = cmd.target || 'AVA-01610-1';
		const action = cmd.action;
		const params = cmd.params || {};
		const nonce = cmd.nonce;
		const signature = cmd.signature;

		const cmdRecord = {
			minute: cmd.minute !== undefined ? cmd.minute : 0,
			source,
			target,
			action,
			params,
			nonce,
		};

		const isValidSig = verifyCubeSatCommand(
			{ source, target, action, params, nonce },
			signature,
			secretKey
		);

		if (!isValidSig) {
			securityLog.push({
				status: 'REJECTED_INVALID_SIGNATURE',
				message: `Befehl '${action}' von '${source}' wegen ungültiger Signatur abgewiesen.`,
				command: cmdRecord,
			});
			continue;
		}

		const nonceKey = String(nonce);
		if (seenNonces.has(nonceKey)) {
			securityLog.push({
				status: 'REJECTED_REPLAY',
				message: `Replay-Angriff erkannt: Nonce '${nonceKey}' wurde bereits verwendet. Befehl abgewiesen.`,
				command: cmdRecord,
			});
			continue;
		}
		seenNonces.add(nonceKey);

		if (!ALLOWED_CUBESAT_ACTIONS.includes(action)) {
			securityLog.push({
				status: 'REJECTED_UNAUTHORIZED_ACTION',
				message: `Aktion '${action}' ist nicht in der Whitelist freigegebener Befehle enthalten.`,
				command: cmdRecord,
			});
			continue;
		}

		// Execute accepted action
		if (action === 'AdjustAltitude' && typeof params.altitudeKm === 'number') {
			currentAltitudeKm = params.altitudeKm;
		} else if (action === 'SetPowerMode' && typeof params.mode === 'string') {
			powerMode = params.mode;
		} else if (action === 'DeployAntenna') {
			antennaDeployed = true;
		} else if (action === 'ResetEPS') {
			currentBatteryWh = batteryCapacityWh;
		}

		securityLog.push({
			status: 'ACCEPTED_EXECUTED',
			message: `Befehl '${action}' erfolgreich authentifiziert und ausgeführt.`,
			command: cmdRecord,
		});
	}

	// Verify chain integrity
	let chainIntact = true;
	let expectedPrev = '0000000000000000000000000000000000000000000000000000000000000000';
	for (const packet of telemetryChain) {
		if (packet.prevHash !== expectedPrev) {
			chainIntact = false;
			break;
		}
		const { hash, ...unhashed } = packet;
		const computed = computeSha256(JSON.stringify(unhashed));
		if (computed !== hash) {
			chainIntact = false;
			break;
		}
		expectedPrev = hash;
	}

	const minBattery = Math.min(...telemetryChain.map((p) => p.batteryPercent));
	const maxBattery = Math.max(...telemetryChain.map((p) => p.batteryPercent));
	const minTemp = Math.min(...telemetryChain.map((p) => p.temperatureCelsius));
	const maxTemp = Math.max(...telemetryChain.map((p) => p.temperatureCelsius));

	return {
		summary: {
			totalDurationMinutes: durationMinutes,
			totalSteps: telemetryChain.length,
			totalOrbits: Math.ceil(durationMinutes / orbitPeriod),
			minBatteryPercent: minBattery,
			maxBatteryPercent: maxBattery,
			minTemperatureCelsius: minTemp,
			maxTemperatureCelsius: maxTemp,
			finalAltitudeKm: Number(currentAltitudeKm.toFixed(1)),
			finalPowerMode: powerMode,
			antennaDeployed,
			commandsEvaluated: inputCommands.length,
			commandsAccepted: securityLog.filter((l) => l.status === 'ACCEPTED_EXECUTED').length,
			commandsRejected: securityLog.filter((l) => l.status !== 'ACCEPTED_EXECUTED').length,
		},
		evidenceRoot: prevHash,
		chainVerified: chainIntact,
		telemetryChain,
		securityLog,
	};
}

module.exports = {
	CUBESAT_01610_PHASES,
	CUBESAT_01610_BUDGET_TIERS,
	CUBESAT_01610_SPECIFICATION,
	CUBESAT_01610_REPORT,
	ALLOWED_CUBESAT_ACTIONS,
	cubeSat01610Report,
	cubeSat01610Data,
	computeSha256,
	signCubeSatCommand,
	verifyCubeSatCommand,
	simulateCubeSat,
};
