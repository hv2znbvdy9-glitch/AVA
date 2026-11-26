'use strict';

const {HodgkinHuxleyCompartment, MAX_STEPS} = require('./hodgkin-huxley');

const MAX_COMPARTMENTS = 10_000;

function finiteNumber(value, name) {
	if (!Number.isFinite(value)) {
		throw new TypeError(`${name} must be finite`);
	}
	return value;
}

function validateStep(dt) {
	finiteNumber(dt, 'dt');
	if (dt <= 0 || dt > 0.1) {
		throw new RangeError('dt must be in (0, 0.1] ms');
	}
	return dt;
}

function normalizeConnection(connection, index, count) {
	if (!connection || typeof connection !== 'object') {
		throw new TypeError(`connections[${index}] must be an object`);
	}
	const {from, to, conductance} = connection;
	if (!Number.isInteger(from) || from < 0 || from >= count
		|| !Number.isInteger(to) || to < 0 || to >= count || from === to) {
		throw new RangeError(`connections[${index}] must connect two distinct valid compartment indices`);
	}
	finiteNumber(conductance, `connections[${index}].conductance`);
	if (conductance < 0) {
		throw new RangeError(`connections[${index}].conductance must be non-negative`);
	}
	return {from, to, conductance};
}

function axialCurrentFor(compartment, neighbor, conductance) {
	return conductance * (neighbor.voltage - compartment.voltage);
}

function stepAll(compartments, connections, dt, inputCurrents) {
	const axialCurrents = compartments.map(() => 0);
	connections.forEach((connection) => {
		axialCurrents[connection.from] += axialCurrentFor(
			compartments[connection.from],
			compartments[connection.to],
			connection.conductance,
		);
		axialCurrents[connection.to] += axialCurrentFor(
			compartments[connection.to],
			compartments[connection.from],
			connection.conductance,
		);
	});

	// Derivatives are sampled for the whole network before any state is
	// updated, so stepping order does not affect the result.
	const derivatives = compartments.map((compartment, index) => compartment.derivatives(
		inputCurrents[index] + axialCurrents[index],
	));
	compartments.forEach((compartment, index) => {
		const derivative = derivatives[index];
		compartment.voltage += dt * derivative.voltage;
		compartment.m = Math.min(1, Math.max(0, compartment.m + dt * derivative.m));
		compartment.h = Math.min(1, Math.max(0, compartment.h + dt * derivative.h));
		compartment.n = Math.min(1, Math.max(0, compartment.n + dt * derivative.n));
		if (![compartment.voltage, compartment.m, compartment.h, compartment.n].every(Number.isFinite)) {
			throw new Error('simulation became non-finite');
		}
	});
}

/**
 * Deterministic, bounded multi-compartment Hodgkin-Huxley simulation.
 * Compartments are classic single-compartment Hodgkin-Huxley models coupled
 * by ohmic axial conductances. This is a teaching prototype: it is not the
 * published Hay L5b morphology, has no active dendritic channel gradients,
 * and is not a NEURON simulation.
 *
 * @param {object} options
 * @param {number} options.durationMs Simulation duration in ms (positive).
 * @param {number} options.dt Integration step in ms, in (0, 0.1].
 * @param {Array<object>} [options.compartments] One options object per
 *   compartment, forwarded to HodgkinHuxleyCompartment. Defaults to a soma
 *   plus two active HH chain segments with the same default channels.
 * @param {Array<{from: number, to: number, conductance: number}>} [options.connections]
 *   Ohmic axial couplings between compartment indices.
 * @param {(timeMs: number, index: number) => number} [options.current]
 *   Per-compartment input current density in μA/cm².
 * @returns {Array<{timeMs: number, compartments: Array<{voltage: number, m: number, h: number, n: number}>}>}
 */
function simulateMultiCompartment({
	durationMs = 50,
	dt = 0.01,
	compartments: compartmentOptions,
	connections: connectionOptions,
	current = () => 0,
} = {}) {
	finiteNumber(durationMs, 'durationMs');
	if (durationMs <= 0) {
		throw new RangeError('durationMs must be positive');
	}
	validateStep(dt);
	if (typeof current !== 'function') {
		throw new TypeError('current must be a function');
	}

	const options = compartmentOptions === undefined
		? [{}, {}, {}]
		: compartmentOptions;
	if (!Array.isArray(options) || options.length === 0) {
		throw new TypeError('compartments must be a non-empty array');
	}
	if (options.length > MAX_COMPARTMENTS) {
		throw new RangeError(`compartments must not exceed ${MAX_COMPARTMENTS}`);
	}
	const compartments = options.map((option, index) => {
		if (!option || typeof option !== 'object' || Array.isArray(option)) {
			throw new TypeError(`compartments[${index}] must be an options object`);
		}
		return new HodgkinHuxleyCompartment(option);
	});

	const connectionList = connectionOptions === undefined
		? compartments.slice(1).map((unused, index) => ({from: index, to: index + 1, conductance: 1}))
		: connectionOptions;
	if (!Array.isArray(connectionList)) {
		throw new TypeError('connections must be an array');
	}
	const connections = connectionList.map(
		(connection, index) => normalizeConnection(connection, index, compartments.length),
	);

	const steps = Math.ceil(durationMs / dt);
	if (steps > MAX_STEPS) {
		throw new RangeError(`simulation exceeds ${MAX_STEPS} steps`);
	}

	const samples = [];
	for (let step = 0; step <= steps; step += 1) {
		const timeMs = Math.min(durationMs, step * dt);
		samples.push({
			timeMs,
			compartments: compartments.map((compartment) => compartment.snapshot()),
		});
		// Do not emit the endpoint twice or evaluate a stimulus at a zero-length step.
		if (timeMs === durationMs) {
			break;
		}
		if (step < steps) {
			const stepSize = Math.min(dt, durationMs - timeMs);
			const inputCurrents = compartments.map(
				(unused, index) => finiteNumber(current(timeMs, index), `current(${timeMs}, ${index})`),
			);
			stepAll(compartments, connections, stepSize, inputCurrents);
		}
	}
	return samples;
}

module.exports = {
	MAX_COMPARTMENTS,
	simulateMultiCompartment,
};
