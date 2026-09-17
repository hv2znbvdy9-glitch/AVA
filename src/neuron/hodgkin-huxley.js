'use strict';

const DEFAULTS = Object.freeze({
  capacitance: 1,
  gNa: 120,
  gK: 36,
  gLeak: 0.3,
  eNa: 50,
  eK: -77,
  eLeak: -54.387,
});

function finiteNumber(value, name) {
  if (!Number.isFinite(value)) throw new TypeError(`${name} must be finite`);
  return value;
}

function vtrap(x, y) {
  const ratio = x / y;
  return Math.abs(ratio) < 1e-6 ? y * (1 - ratio / 2) : x / Math.expm1(ratio);
}

function rates(voltage) {
  finiteNumber(voltage, 'voltage');
  return {
    alphaM: 0.1 * vtrap(-(voltage + 40), 10),
    betaM: 4 * Math.exp(-(voltage + 65) / 18),
    alphaH: 0.07 * Math.exp(-(voltage + 65) / 20),
    betaH: 1 / (1 + Math.exp(-(voltage + 35) / 10)),
    alphaN: 0.01 * vtrap(-(voltage + 55), 10),
    betaN: 0.125 * Math.exp(-(voltage + 65) / 80),
  };
}

function steadyState(voltage) {
  const r = rates(voltage);
  return {
    m: r.alphaM / (r.alphaM + r.betaM),
    h: r.alphaH / (r.alphaH + r.betaH),
    n: r.alphaN / (r.alphaN + r.betaN),
  };
}

class HodgkinHuxleyCompartment {
  constructor(options = {}) {
    this.parameters = { ...DEFAULTS, ...(options.parameters || {}) };
    Object.entries(this.parameters).forEach(([key, value]) => finiteNumber(value, key));
    if (this.parameters.capacitance <= 0) throw new RangeError('capacitance must be positive');
    this.voltage = finiteNumber(options.voltage ?? -65, 'voltage');
    const gates = steadyState(this.voltage);
    this.m = finiteNumber(options.m ?? gates.m, 'm');
    this.h = finiteNumber(options.h ?? gates.h, 'h');
    this.n = finiteNumber(options.n ?? gates.n, 'n');
    for (const gate of ['m', 'h', 'n']) {
      if (this[gate] < 0 || this[gate] > 1) throw new RangeError(`${gate} must be in [0, 1]`);
    }
  }

  derivatives(inputCurrent = 0) {
    finiteNumber(inputCurrent, 'inputCurrent');
    const p = this.parameters;
    const r = rates(this.voltage);
    const sodium = p.gNa * this.m ** 3 * this.h * (this.voltage - p.eNa);
    const potassium = p.gK * this.n ** 4 * (this.voltage - p.eK);
    const leak = p.gLeak * (this.voltage - p.eLeak);
    return {
      voltage: (inputCurrent - sodium - potassium - leak) / p.capacitance,
      m: r.alphaM * (1 - this.m) - r.betaM * this.m,
      h: r.alphaH * (1 - this.h) - r.betaH * this.h,
      n: r.alphaN * (1 - this.n) - r.betaN * this.n,
    };
  }

  step(dt, inputCurrent = 0) {
    finiteNumber(dt, 'dt');
    if (dt <= 0 || dt > 0.1) throw new RangeError('dt must be in (0, 0.1] ms');
    const d = this.derivatives(inputCurrent);
    this.voltage += dt * d.voltage;
    this.m = Math.min(1, Math.max(0, this.m + dt * d.m));
    this.h = Math.min(1, Math.max(0, this.h + dt * d.h));
    this.n = Math.min(1, Math.max(0, this.n + dt * d.n));
    if (![this.voltage, this.m, this.h, this.n].every(Number.isFinite)) {
      throw new Error('simulation became non-finite');
    }
    return this.snapshot();
  }

  snapshot() {
    return { voltage: this.voltage, m: this.m, h: this.h, n: this.n };
  }
}

function simulate({ durationMs = 50, dt = 0.01, current = () => 0, compartment } = {}) {
  finiteNumber(durationMs, 'durationMs');
  if (durationMs <= 0) throw new RangeError('durationMs must be positive');
  if (typeof current !== 'function') throw new TypeError('current must be a function');
  const neuron = compartment || new HodgkinHuxleyCompartment();
  const samples = [];
  const steps = Math.ceil(durationMs / dt);
  for (let index = 0; index <= steps; index += 1) {
    const timeMs = Math.min(durationMs, index * dt);
    samples.push({ timeMs, ...neuron.snapshot() });
    if (index < steps) neuron.step(Math.min(dt, durationMs - timeMs), current(timeMs));
  }
  return samples;
}

module.exports = { HodgkinHuxleyCompartment, rates, simulate, steadyState };
