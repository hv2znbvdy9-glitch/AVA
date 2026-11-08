'use strict';

function finiteNumber(value, name) {
	if (!Number.isFinite(value)) {
		throw new TypeError(`${name} must be finite`);
	}
	return value;
}

function nonNegative(value, name) {
	finiteNumber(value, name);
	if (value < 0) {
		throw new RangeError(`${name} must be non-negative`);
	}
	return value;
}

function conductanceCurrent(conductance, voltage, reversalPotential) {
	nonNegative(conductance, 'conductance');
	finiteNumber(voltage, 'voltage');
	finiteNumber(reversalPotential, 'reversalPotential');
	return finiteNumber(conductance * (voltage - reversalPotential), 'conductance current');
}

function axialCouplingCurrent(localVoltage, neighborVoltage, conductance) {
	nonNegative(conductance, 'conductance');
	finiteNumber(localVoltage, 'localVoltage');
	finiteNumber(neighborVoltage, 'neighborVoltage');
	return finiteNumber(conductance * (neighborVoltage - localVoltage), 'axial current');
}

function cableEquationDerivative(compartments, axialConnections = [], inputCurrents = []) {
	if (!Array.isArray(compartments) || compartments.length === 0) {
		throw new TypeError('compartments must be a non-empty array');
	}
	if (!Array.isArray(axialConnections)) {
		throw new TypeError('axialConnections must be an array');
	}
	if (!Array.isArray(inputCurrents) || (inputCurrents.length !== 0 && inputCurrents.length !== compartments.length)) {
		throw new TypeError('inputCurrents must be empty or match compartments');
	}

	const netCurrents = compartments.map((compartment, index) => {
		if (!compartment || typeof compartment !== 'object') {
			throw new TypeError(`compartments[${index}] must be an object`);
		}
		const {voltage, capacitance, conductances = []} = compartment;
		finiteNumber(voltage, `compartments[${index}].voltage`);
		finiteNumber(capacitance, `compartments[${index}].capacitance`);
		if (capacitance <= 0) {
			throw new RangeError(`compartments[${index}].capacitance must be positive`);
		}
		if (!Array.isArray(conductances)) {
			throw new TypeError(`compartments[${index}].conductances must be an array`);
		}
		const inputCurrent = inputCurrents.length === 0 ? 0 : finiteNumber(inputCurrents[index], `inputCurrents[${index}]`);
		const membraneCurrent = conductances.reduce((total, channel, channelIndex) => {
			if (!channel || typeof channel !== 'object') {
				throw new TypeError(`conductances[${channelIndex}] must be an object`);
			}
			return total + conductanceCurrent(channel.conductance, voltage, channel.reversalPotential);
		}, 0);
		return inputCurrent - membraneCurrent;
	});

	axialConnections.forEach((connection, index) => {
		if (!connection || typeof connection !== 'object') {
			throw new TypeError(`axialConnections[${index}] must be an object`);
		}
		const {from, to, conductance} = connection;
		if (!Number.isInteger(from) || from < 0 || from >= compartments.length
			|| !Number.isInteger(to) || to < 0 || to >= compartments.length || from === to) {
			throw new RangeError(`axialConnections[${index}] must connect two distinct valid compartment indices`);
		}
		const fromVoltage = compartments[from].voltage;
		const toVoltage = compartments[to].voltage;
		netCurrents[from] += axialCouplingCurrent(fromVoltage, toVoltage, conductance);
		netCurrents[to] += axialCouplingCurrent(toVoltage, fromVoltage, conductance);
	});

	return netCurrents.map((current, index) => finiteNumber(
		current / compartments[index].capacitance,
		`derivative[${index}]`,
	));
}

function eulerStep(values, derivatives, dt) {
	finiteNumber(dt, 'dt');
	if (dt <= 0) {
		throw new RangeError('dt must be positive');
	}
	if (!Array.isArray(values) || !Array.isArray(derivatives) || values.length !== derivatives.length) {
		throw new TypeError('values and derivatives must be arrays of equal length');
	}
	return values.map((value, index) => finiteNumber(
		finiteNumber(value, `values[${index}]`) + dt * finiteNumber(derivatives[index], `derivatives[${index}]`),
		`nextValues[${index}]`,
	));
}

module.exports = {
	axialCouplingCurrent,
	cableEquationDerivative,
	conductanceCurrent,
	eulerStep,
};
