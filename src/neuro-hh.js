'use strict';

const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const MODEL_ID = 'ava-neuro-hh-l5-prototype/v1';
const MODEL_SCOPE = [
	'Lumped seven-compartment conductance-based teaching and regression model.',
	'Inspired by active Layer-5 pyramidal-cell physiology; not a reproduction of Hay et al.',
	'No reconstructed morphology, fitted Hay parameter set, explicit spines, NMDA receptors, plasticity, metabolism or glia.',
].join(' ');

const DEFAULT_DT_MS = 0.01;
const DEFAULT_SAMPLE_MS = 0.1;
const DEFAULT_DURATION_MS = 120;
const CALCIUM_REST_MM = 0.0001;

const COMPARTMENTS = Object.freeze([
	Object.freeze({
		id: 'ais',
		label: 'Axon initial segment (simplified)',
		cm: 1,
		gNa: 220,
		gK: 70,
		gLeak: 0.3,
		gCa: 0,
		gKCa: 0,
		gH: 0,
	}),
	Object.freeze({
		id: 'soma',
		label: 'Soma',
		cm: 1,
		gNa: 120,
		gK: 36,
		gLeak: 0.3,
		gCa: 0.05,
		gKCa: 0.4,
		gH: 0.01,
	}),
	Object.freeze({
		id: 'basal',
		label: 'Basal dendrite (lumped)',
		cm: 1,
		gNa: 18,
		gK: 8,
		gLeak: 0.25,
		gCa: 0.12,
		gKCa: 0.8,
		gH: 0.025,
	}),
	Object.freeze({
		id: 'apical_proximal',
		label: 'Proximal apical dendrite (lumped)',
		cm: 1,
		gNa: 28,
		gK: 10,
		gLeak: 0.25,
		gCa: 0.18,
		gKCa: 1,
		gH: 0.04,
	}),
	Object.freeze({
		id: 'apical_trunk',
		label: 'Apical trunk (lumped)',
		cm: 1,
		gNa: 34,
		gK: 12,
		gLeak: 0.22,
		gCa: 0.45,
		gKCa: 1.2,
		gH: 0.075,
	}),
	Object.freeze({
		id: 'apical_distal',
		label: 'Distal apical calcium zone (lumped)',
		cm: 1,
		gNa: 20,
		gK: 8,
		gLeak: 0.2,
		gCa: 1.8,
		gKCa: 2.2,
		gH: 0.12,
	}),
	Object.freeze({
		id: 'tuft',
		label: 'Apical tuft (lumped)',
		cm: 1,
		gNa: 12,
		gK: 6,
		gLeak: 0.2,
		gCa: 2.2,
		gKCa: 2.5,
		gH: 0.16,
	}),
]);

const COUPLINGS = Object.freeze([
	Object.freeze({from: 'ais', to: 'soma', conductance: 2.4}),
	Object.freeze({from: 'soma', to: 'basal', conductance: 0.3}),
	Object.freeze({from: 'soma', to: 'apical_proximal', conductance: 0.9}),
	Object.freeze({from: 'apical_proximal', to: 'apical_trunk', conductance: 0.55}),
	Object.freeze({from: 'apical_trunk', to: 'apical_distal', conductance: 0.3}),
	Object.freeze({from: 'apical_distal', to: 'tuft', conductance: 0.18}),
]);

const REVERSAL_MV = Object.freeze({
	na: 50,
	k: -77,
	leak: -54.387,
	ca: 120,
	h: -35,
});

const PROTOCOLS = Object.freeze({
	rest: Object.freeze({
		durationMs: 80,
		stimuli: Object.freeze([]),
	}),
	'somatic-step': Object.freeze({
		durationMs: 120,
		stimuli: Object.freeze([
			Object.freeze({compartment: 'soma', startMs: 20, endMs: 90, amplitude: 11}),
		]),
	}),
	'distal-pulse': Object.freeze({
		durationMs: 120,
		stimuli: Object.freeze([
			Object.freeze({compartment: 'apical_distal', startMs: 35, endMs: 47, amplitude: 18}),
		]),
	}),
	'bac-coincidence': Object.freeze({
		durationMs: 120,
		stimuli: Object.freeze([
			Object.freeze({compartment: 'soma', startMs: 30, endMs: 32, amplitude: 28}),
			Object.freeze({compartment: 'apical_distal', startMs: 34, endMs: 46, amplitude: 16}),
		]),
	}),
});

const COMPARTMENT_INDEX = Object.freeze(Object.fromEntries(
	COMPARTMENTS.map((compartment, index) => [compartment.id, index]),
));

function assertFiniteNumber(value, name) {
	if (!Number.isFinite(value)) {
		throw new TypeError(`${name} must be a finite number`);
	}
}

function clamp(value, minimum, maximum) {
	return Math.min(maximum, Math.max(minimum, value));
}

function vTrap(numerator, denominatorScale) {
	const ratio = numerator / denominatorScale;
	if (Math.abs(ratio) < 1e-7) {
		return denominatorScale * (1 + ratio / 2);
	}

	return numerator / (1 - Math.exp(-ratio));
}

function classicHHRates(voltageMv) {
	return {
		alphaM: 0.1 * vTrap(voltageMv + 40, 10),
		betaM: 4 * Math.exp(-(voltageMv + 65) / 18),
		alphaH: 0.07 * Math.exp(-(voltageMv + 65) / 20),
		betaH: 1 / (1 + Math.exp(-(voltageMv + 35) / 10)),
		alphaN: 0.01 * vTrap(voltageMv + 55, 10),
		betaN: 0.125 * Math.exp(-(voltageMv + 65) / 80),
	};
}

function steadyState(alpha, beta) {
	return alpha / (alpha + beta);
}

function calciumActivationInfinity(voltageMv) {
	return 1 / (1 + Math.exp(-(voltageMv + 22) / 6.5));
}

function calciumInactivationInfinity(voltageMv) {
	return 1 / (1 + Math.exp((voltageMv + 28) / 12));
}

function hcnInfinity(voltageMv) {
	return 1 / (1 + Math.exp((voltageMv + 80) / 8));
}

function initialCompartmentState(voltageMv = -65) {
	const rates = classicHHRates(voltageMv);
	return {
		v: voltageMv,
		m: steadyState(rates.alphaM, rates.betaM),
		h: steadyState(rates.alphaH, rates.betaH),
		n: steadyState(rates.alphaN, rates.betaN),
		p: calciumActivationInfinity(voltageMv),
		q: calciumInactivationInfinity(voltageMv),
		r: hcnInfinity(voltageMv),
		ca: CALCIUM_REST_MM,
	};
}

function cloneState(state) {
	return state.map((item) => ({...item}));
}

function validateStimuli(stimuli) {
	if (!Array.isArray(stimuli)) {
		throw new TypeError('stimuli must be an array');
	}

	return stimuli.map((stimulus, index) => {
		if (!stimulus || typeof stimulus !== 'object') {
			throw new TypeError(`stimuli[${index}] must be an object`);
		}

		if (!Object.hasOwn(COMPARTMENT_INDEX, stimulus.compartment)) {
			throw new RangeError(`Unknown stimulus compartment: ${stimulus.compartment}`);
		}

		for (const key of ['startMs', 'endMs', 'amplitude']) {
			assertFiniteNumber(stimulus[key], `stimuli[${index}].${key}`);
		}

		if (stimulus.startMs < 0 || stimulus.endMs <= stimulus.startMs) {
			throw new RangeError(`Invalid stimulus interval at stimuli[${index}]`);
		}

		return {
			compartment: stimulus.compartment,
			startMs: stimulus.startMs,
			endMs: stimulus.endMs,
			amplitude: stimulus.amplitude,
		};
	});
}

function appliedCurrents(timeMs, stimuli) {
	const currents = new Array(COMPARTMENTS.length).fill(0);
	for (const stimulus of stimuli) {
		if (timeMs >= stimulus.startMs && timeMs < stimulus.endMs) {
			currents[COMPARTMENT_INDEX[stimulus.compartment]] += stimulus.amplitude;
		}
	}

	return currents;
}

function calculateDerivatives(state, timeMs, stimuli) {
	const external = appliedCurrents(timeMs, stimuli);
	const axial = new Array(COMPARTMENTS.length).fill(0);

	for (const coupling of COUPLINGS) {
		const fromIndex = COMPARTMENT_INDEX[coupling.from];
		const toIndex = COMPARTMENT_INDEX[coupling.to];
		const current = coupling.conductance * (state[toIndex].v - state[fromIndex].v);
		axial[fromIndex] += current;
		axial[toIndex] -= current;
	}

	return state.map((item, index) => {
		const parameters = COMPARTMENTS[index];
		const rates = classicHHRates(item.v);
		const iNa = parameters.gNa * (item.m ** 3) * item.h * (item.v - REVERSAL_MV.na);
		const iK = parameters.gK * (item.n ** 4) * (item.v - REVERSAL_MV.k);
		const iLeak = parameters.gLeak * (item.v - REVERSAL_MV.leak);
		const iCa = parameters.gCa * (item.p ** 2) * item.q * (item.v - REVERSAL_MV.ca);
		const calciumGate = item.ca / (item.ca + 0.001);
		const iKCa = parameters.gKCa * calciumGate * (item.v - REVERSAL_MV.k);
		const iH = parameters.gH * item.r * (item.v - REVERSAL_MV.h);
		const ionicCurrent = iNa + iK + iLeak + iCa + iKCa + iH;

		return {
			v: (external[index] + axial[index] - ionicCurrent) / parameters.cm,
			m: rates.alphaM * (1 - item.m) - rates.betaM * item.m,
			h: rates.alphaH * (1 - item.h) - rates.betaH * item.h,
			n: rates.alphaN * (1 - item.n) - rates.betaN * item.n,
			p: (calciumActivationInfinity(item.v) - item.p) / 3,
			q: (calciumInactivationInfinity(item.v) - item.q) / 45,
			r: (hcnInfinity(item.v) - item.r) / 80,
			ca: (-0.00002 * iCa) - ((item.ca - CALCIUM_REST_MM) / 80),
		};
	});
}

function statePlus(state, derivative, scale) {
	return state.map((item, index) => ({
		v: item.v + derivative[index].v * scale,
		m: item.m + derivative[index].m * scale,
		h: item.h + derivative[index].h * scale,
		n: item.n + derivative[index].n * scale,
		p: item.p + derivative[index].p * scale,
		q: item.q + derivative[index].q * scale,
		r: item.r + derivative[index].r * scale,
		ca: item.ca + derivative[index].ca * scale,
	}));
}

function rk4Step(state, timeMs, dtMs, stimuli) {
	const k1 = calculateDerivatives(state, timeMs, stimuli);
	const k2 = calculateDerivatives(statePlus(state, k1, dtMs / 2), timeMs + dtMs / 2, stimuli);
	const k3 = calculateDerivatives(statePlus(state, k2, dtMs / 2), timeMs + dtMs / 2, stimuli);
	const k4 = calculateDerivatives(statePlus(state, k3, dtMs), timeMs + dtMs, stimuli);

	return state.map((item, index) => ({
		v: item.v + (dtMs / 6) * (k1[index].v + 2 * k2[index].v + 2 * k3[index].v + k4[index].v),
		m: clamp(item.m + (dtMs / 6) * (k1[index].m + 2 * k2[index].m + 2 * k3[index].m + k4[index].m), 0, 1),
		h: clamp(item.h + (dtMs / 6) * (k1[index].h + 2 * k2[index].h + 2 * k3[index].h + k4[index].h), 0, 1),
		n: clamp(item.n + (dtMs / 6) * (k1[index].n + 2 * k2[index].n + 2 * k3[index].n + k4[index].n), 0, 1),
		p: clamp(item.p + (dtMs / 6) * (k1[index].p + 2 * k2[index].p + 2 * k3[index].p + k4[index].p), 0, 1),
		q: clamp(item.q + (dtMs / 6) * (k1[index].q + 2 * k2[index].q + 2 * k3[index].q + k4[index].q), 0, 1),
		r: clamp(item.r + (dtMs / 6) * (k1[index].r + 2 * k2[index].r + 2 * k3[index].r + k4[index].r), 0, 1),
		ca: Math.max(0, item.ca + (dtMs / 6) * (k1[index].ca + 2 * k2[index].ca + 2 * k3[index].ca + k4[index].ca)),
	}));
}

function rounded(value, digits = 6) {
	return Number(value.toFixed(digits));
}

function traceRow(timeMs, state) {
	const row = {time_ms: rounded(timeMs, 4)};
	for (let index = 0; index < COMPARTMENTS.length; index++) {
		row[`${COMPARTMENTS[index].id}_mv`] = rounded(state[index].v);
	}

	row.apical_distal_ca_mm = rounded(state[COMPARTMENT_INDEX.apical_distal].ca, 9);
	row.tuft_ca_mm = rounded(state[COMPARTMENT_INDEX.tuft].ca, 9);
	return row;
}

function createPeakMap(initialState) {
	return Object.fromEntries(COMPARTMENTS.map((compartment, index) => [compartment.id, initialState[index].v]));
}

function resolveProtocol(options) {
	const protocolName = options.protocol || 'bac-coincidence';
	const protocol = PROTOCOLS[protocolName];
	if (!protocol) {
		throw new RangeError(`Unknown protocol: ${protocolName}. Expected one of: ${Object.keys(PROTOCOLS).join(', ')}`);
	}

	const durationMs = options.durationMs === undefined ? protocol.durationMs : Number(options.durationMs);
	const dtMs = options.dtMs === undefined ? DEFAULT_DT_MS : Number(options.dtMs);
	const sampleMs = options.sampleMs === undefined ? DEFAULT_SAMPLE_MS : Number(options.sampleMs);
	for (const [value, name] of [[durationMs, 'durationMs'], [dtMs, 'dtMs'], [sampleMs, 'sampleMs']]) {
		assertFiniteNumber(value, name);
	}

	if (durationMs <= 0 || durationMs > 5000) {
		throw new RangeError('durationMs must be > 0 and <= 5000');
	}

	if (dtMs <= 0 || dtMs > 0.05) {
		throw new RangeError('dtMs must be > 0 and <= 0.05');
	}

	if (sampleMs < dtMs || sampleMs > durationMs) {
		throw new RangeError('sampleMs must be >= dtMs and <= durationMs');
	}

	if (Math.abs((durationMs / dtMs) - Math.round(durationMs / dtMs)) > 1e-9) {
		throw new RangeError('durationMs must be an integer multiple of dtMs');
	}

	if (Math.abs((sampleMs / dtMs) - Math.round(sampleMs / dtMs)) > 1e-9) {
		throw new RangeError('sampleMs must be an integer multiple of dtMs');
	}

	const stimuli = validateStimuli(options.stimuli === undefined ? protocol.stimuli : options.stimuli);
	if (stimuli.some((stimulus) => stimulus.endMs > durationMs)) {
		throw new RangeError('Stimulus endMs cannot exceed durationMs');
	}

	return {protocolName, durationMs, dtMs, sampleMs, stimuli};
}

function simulateMultiCompartmentHH(options = {}) {
	const configuration = resolveProtocol(options);
	let state = COMPARTMENTS.map(() => initialCompartmentState());
	let previousState = cloneState(state);
	const trace = [traceRow(0, state)];
	const peaks = createPeakMap(state);
	const maximaCa = {apical_distal: CALCIUM_REST_MM, tuft: CALCIUM_REST_MM};
	const spikeTimesMs = [];
	const calciumEventTimesMs = [];
	let lastSpikeMs = -Infinity;
	let lastCalciumEventMs = -Infinity;
	const steps = Math.round(configuration.durationMs / configuration.dtMs);
	const sampleEvery = Math.max(1, Math.round(configuration.sampleMs / configuration.dtMs));

	for (let step = 1; step <= steps; step++) {
		const timeMs = step * configuration.dtMs;
		previousState = state;
		state = rk4Step(state, timeMs - configuration.dtMs, configuration.dtMs, configuration.stimuli);

		for (let index = 0; index < COMPARTMENTS.length; index++) {
			if (!Number.isFinite(state[index].v) || !Number.isFinite(state[index].ca)) {
				throw new Error(`Numerical instability at ${rounded(timeMs, 4)} ms in ${COMPARTMENTS[index].id}`);
			}

			if (state[index].v < -250 || state[index].v > 200) {
				throw new Error(`Voltage escaped safety bounds at ${rounded(timeMs, 4)} ms in ${COMPARTMENTS[index].id}`);
			}

			peaks[COMPARTMENTS[index].id] = Math.max(peaks[COMPARTMENTS[index].id], state[index].v);
		}

		const distal = state[COMPARTMENT_INDEX.apical_distal];
		const previousDistal = previousState[COMPARTMENT_INDEX.apical_distal];
		maximaCa.apical_distal = Math.max(maximaCa.apical_distal, distal.ca);
		maximaCa.tuft = Math.max(maximaCa.tuft, state[COMPARTMENT_INDEX.tuft].ca);

		const somaVoltage = state[COMPARTMENT_INDEX.soma].v;
		const previousSomaVoltage = previousState[COMPARTMENT_INDEX.soma].v;
		if (previousSomaVoltage < 0 && somaVoltage >= 0 && timeMs - lastSpikeMs >= 1) {
			spikeTimesMs.push(rounded(timeMs, 4));
			lastSpikeMs = timeMs;
		}

		if (previousDistal.v < -20 && distal.v >= -20 && distal.ca > CALCIUM_REST_MM && timeMs - lastCalciumEventMs >= 5) {
			calciumEventTimesMs.push(rounded(timeMs, 4));
			lastCalciumEventMs = timeMs;
		}

		if (step % sampleEvery === 0 || step === steps) {
			trace.push(traceRow(timeMs, state));
		}
	}

	const parameterDocument = {
		compartments: COMPARTMENTS,
		couplings: COUPLINGS,
		reversalPotentialsMv: REVERSAL_MV,
		calciumRestMm: CALCIUM_REST_MM,
	};

	const summary = {
		protocol: configuration.protocolName,
		duration_ms: configuration.durationMs,
		dt_ms: configuration.dtMs,
		sample_ms: configuration.sampleMs,
		compartment_count: COMPARTMENTS.length,
		spike_count: spikeTimesMs.length,
		spike_times_ms: spikeTimesMs,
		dendritic_calcium_event_count: calciumEventTimesMs.length,
		dendritic_calcium_event_times_ms: calciumEventTimesMs,
		peak_voltage_mv: Object.fromEntries(Object.entries(peaks).map(([key, value]) => [key, rounded(value)])),
		max_calcium_mm: Object.fromEntries(Object.entries(maximaCa).map(([key, value]) => [key, rounded(value, 9)])),
		finite: true,
	};

	return {
		model: {
			id: MODEL_ID,
			scope: MODEL_SCOPE,
			fidelity: 'educational-prototype-not-experimentally-fitted',
			inspiration: 'Active multi-compartment Layer-5 pyramidal-cell physiology',
			copied_hay_source_code: false,
			channels: ['fast Na', 'delayed-rectifier K', 'high-voltage-activated Ca (simplified)', 'Ca-dependent K (simplified)', 'HCN (simplified)', 'leak'],
			units: {
				time: 'ms',
				voltage: 'mV',
				conductance_density: 'mS/cm^2 (normalized compartment area)',
				current_density: 'uA/cm^2 (normalized compartment area)',
				calcium: 'mM (lumped proxy)',
			},
			parameter_sha256: crypto.createHash('sha256').update(JSON.stringify(parameterDocument)).digest('hex'),
		},
		configuration: {
			...configuration,
			stimuli: configuration.stimuli.map((stimulus) => ({...stimulus})),
		},
		summary,
		trace,
	};
}

function validateSimulation(result) {
	const issues = [];
	if (!result || result.model?.id !== MODEL_ID) {
		issues.push('model id mismatch');
	}

	if (!result?.summary?.finite) {
		issues.push('simulation did not report finite state');
	}

	if (!Array.isArray(result?.trace) || result.trace.length < 2) {
		issues.push('trace is missing or too short');
	}

	for (const row of result?.trace || []) {
		for (const compartment of COMPARTMENTS) {
			const voltage = row[`${compartment.id}_mv`];
			if (!Number.isFinite(voltage) || voltage < -200 || voltage > 150) {
				issues.push(`out-of-range voltage in ${compartment.id} at ${row.time_ms} ms`);
				break;
			}
		}
	}

	return {ok: issues.length === 0, issues};
}

function traceToCsv(trace) {
	const headers = Object.keys(trace[0]);
	const lines = [headers.join(',')];
	for (const row of trace) {
		lines.push(headers.map((header) => row[header]).join(','));
	}

	return `${lines.join('\n')}\n`;
}

function sha256Buffer(buffer) {
	return crypto.createHash('sha256').update(buffer).digest('hex');
}

function safeTimestamp(date) {
	return date.toISOString().replace(/[-:]/g, '').replace(/\.\d{3}Z$/, 'Z');
}

function writeExclusive(filePath, content) {
	fs.writeFileSync(filePath, content, {encoding: 'utf8', flag: 'wx'});
}

function writeNeuroEvidence(result, options = {}) {
	const validation = validateSimulation(result);
	if (!validation.ok) {
		throw new Error(`Refusing to write invalid simulation evidence: ${validation.issues.join('; ')}`);
	}

	const now = options.now instanceof Date ? options.now : new Date();
	if (Number.isNaN(now.getTime())) {
		throw new TypeError('now must be a valid Date');
	}

	const eventId = options.eventId || crypto.randomUUID();
	if (!/^[A-Za-z0-9._-]{8,128}$/.test(eventId)) {
		throw new RangeError('eventId must contain 8-128 safe filename characters');
	}

	const outputRoot = path.resolve(options.outputRoot || path.join(process.cwd(), 'AVA_EVENTS'));
	const eventDirectory = path.join(outputRoot, `${safeTimestamp(now)}_${eventId}`);
	fs.mkdirSync(outputRoot, {recursive: true});
	fs.mkdirSync(eventDirectory, {recursive: false});

	const summaryDocument = {
		schema: 'ava-neuro-hh-summary/v1',
		model: result.model,
		configuration: result.configuration,
		summary: result.summary,
	};
	const summaryText = `${JSON.stringify(summaryDocument, null, 2)}\n`;
	const traceText = traceToCsv(result.trace);
	const summaryPath = path.join(eventDirectory, 'summary.json');
	const tracePath = path.join(eventDirectory, 'trace.csv');
	writeExclusive(summaryPath, summaryText);
	writeExclusive(tracePath, traceText);

	const manifest = {
		schema: 'ava-evidence-event/v1',
		event_id: eventId,
		capture_group_id: options.captureGroupId || null,
		captured_at_utc: now.toISOString(),
		type: 'AVA_NEURO_HH_SIMULATION',
		model_id: MODEL_ID,
		protocol: result.summary.protocol,
		immutable_rule: 'Erster Blitz bleibt. Zweiter Blitz ergänzt. Kein Überschreiben.',
		files: [
			{name: 'summary.json', sha256: sha256Buffer(Buffer.from(summaryText, 'utf8'))},
			{name: 'trace.csv', sha256: sha256Buffer(Buffer.from(traceText, 'utf8'))},
		],
	};
	const manifestPath = path.join(eventDirectory, 'manifest.json');
	writeExclusive(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);

	return {
		eventDirectory,
		summaryPath,
		tracePath,
		manifestPath,
		manifest,
	};
}

module.exports = {
	MODEL_ID,
	MODEL_SCOPE,
	COMPARTMENTS,
	COUPLINGS,
	PROTOCOLS,
	simulateMultiCompartmentHH,
	validateSimulation,
	writeNeuroEvidence,
};
