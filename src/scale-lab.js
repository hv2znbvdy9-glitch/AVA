'use strict';

const MAX_TARGET_NODES = 690_000_000;
const MAX_SAMPLE_SIZE = 100_000;
const DEFAULTS = Object.freeze({
  nodeCount: 1_000,
  sampleSize: 10_000,
  seed: 1610,
  bytesPerNode: 512,
  messagesPerNodePerHour: 6,
  payloadBytes: 128,
  failureProbability: 0.001,
  energyWattsPerNode: null,
});

function requireInteger(name, value, min, max) {
  if (!Number.isSafeInteger(value) || value < min || value > max) {
    throw new RangeError(name + ' must be a safe integer between ' + min + ' and ' + max);
  }
}

function requireFiniteRange(name, value, min, max) {
  if (!Number.isFinite(value) || value < min || value > max) {
    throw new RangeError(name + ' must be finite and between ' + min + ' and ' + max);
  }
}

function makeRng(seed) {
  let state = seed >>> 0;
  return function next() {
    state = (state + 0x6D2B79F5) | 0;
    let value = state;
    value = Math.imul(value ^ (value >>> 15), value | 1);
    value ^= value + Math.imul(value ^ (value >>> 7), value | 61);
    return ((value ^ (value >>> 14)) >>> 0) / 4294967296;
  };
}

/*
 * Estimate a large logical-node topology without creating nodes, workers,
 * network connections, cloud resources, or files. Only sampleSize random
 * observations are generated; the full topology is calculated analytically.
 */
function simulateScale(options) {
  const config = Object.assign({}, DEFAULTS, options || {});
  requireInteger('nodeCount', config.nodeCount, 1, MAX_TARGET_NODES);
  requireInteger('sampleSize', config.sampleSize, 1, MAX_SAMPLE_SIZE);
  requireInteger('seed', config.seed, 0, Number.MAX_SAFE_INTEGER);
  requireInteger('bytesPerNode', config.bytesPerNode, 1, 1_000_000_000);
  requireInteger('payloadBytes', config.payloadBytes, 0, 1_000_000_000);
  requireFiniteRange('messagesPerNodePerHour', config.messagesPerNodePerHour, 0, 1_000_000_000);
  requireFiniteRange('failureProbability', config.failureProbability, 0, 1);
  if (config.energyWattsPerNode !== null) {
    requireFiniteRange('energyWattsPerNode', config.energyWattsPerNode, 0, 1_000_000);
  }

  const sampledNodes = Math.min(config.nodeCount, config.sampleSize);
  const random = makeRng(config.seed);
  let sampledFailures = 0;
  for (let index = 0; index < sampledNodes; index += 1) {
    if (random() < config.failureProbability) sampledFailures += 1;
  }

  const logicalStateBytes = config.nodeCount * config.bytesPerNode;
  const messagesPerSecond = config.nodeCount * config.messagesPerNodePerHour / 3600;
  const bandwidthMbps = messagesPerSecond * config.payloadBytes * 8 / 1_000_000;
  const bytesPerEventWithOverhead = config.payloadBytes + 96;
  const estimatedEventLogBytesPerDay = messagesPerSecond * 86_400 * bytesPerEventWithOverhead;
  const estimatedPowerKw = config.energyWattsPerNode === null
    ? null
    : config.nodeCount * config.energyWattsPerNode / 1000;

  return {
    schema: 'ava.01610.scale-lab.v1',
    createdAt: new Date().toISOString(),
    mode: 'analytical-estimate-plus-bounded-deterministic-sample',
    target: {
      logicalNodes: config.nodeCount,
      maximumConfiguredTarget: MAX_TARGET_NODES,
      sampledNodes: sampledNodes,
      seed: config.seed,
    },
    assumptions: {
      bytesPerNode: config.bytesPerNode,
      messagesPerNodePerHour: config.messagesPerNodePerHour,
      payloadBytes: config.payloadBytes,
      failureProbability: config.failureProbability,
      energyWattsPerNode: config.energyWattsPerNode,
    },
    results: {
      logicalStateBytes: logicalStateBytes,
      logicalStateGiB: logicalStateBytes / (1024 ** 3),
      estimatedMessagesPerSecond: messagesPerSecond,
      estimatedPayloadBandwidthMbps: bandwidthMbps,
      estimatedEventLogBytesPerDay: estimatedEventLogBytesPerDay,
      expectedFailedNodesFromAssumedRate: config.nodeCount * config.failureProbability,
      sampledFailedNodes: sampledFailures,
      sampledFailureFraction: sampledFailures / sampledNodes,
      estimatedPowerKwFromExplicitAssumption: estimatedPowerKw,
    },
    boundaries: {
      physicalServersCreated: 0,
      processesOrWorkersCreated: 0,
      networkCallsMade: 0,
      cloudResourcesProvisioned: false,
      energyMeasured: false,
      medicalAssessmentPerformed: false,
      interpretation: 'All capacity values are model estimates based on declared assumptions, not measured infrastructure results.',
    },
  };
}

function parseArgs(argv) {
  const options = {};
  const keys = new Map([
    ['--nodes', 'nodeCount'],
    ['--sample-size', 'sampleSize'],
    ['--seed', 'seed'],
    ['--bytes-per-node', 'bytesPerNode'],
    ['--messages-per-node-per-hour', 'messagesPerNodePerHour'],
    ['--payload-bytes', 'payloadBytes'],
    ['--failure-probability', 'failureProbability'],
    ['--energy-watts-per-node', 'energyWattsPerNode'],
  ]);
  for (let index = 0; index < argv.length; index += 1) {
    const key = argv[index];
    if (key === '--help' || key === '-h') return {help: true};
    if (!keys.has(key)) throw new Error('Unknown argument: ' + key);
    const raw = argv[index + 1];
    if (raw === undefined || raw.startsWith('--')) throw new Error('Missing value for ' + key);
    const option = keys.get(key);
    const numeric = Number(raw);
    if (!Number.isFinite(numeric)) throw new Error('Invalid numeric value for ' + key);
    options[option] = numeric;
    index += 1;
  }
  return options;
}

if (require.main === module) {
  try {
    const options = parseArgs(process.argv.slice(2));
    if (options.help) {
      process.stdout.write('AVA 01610 SCALE LAB: bounded model; no infrastructure is created.\n');
    } else {
      process.stdout.write(JSON.stringify(simulateScale(options), null, 2) + '\n');
    }
  } catch (error) {
    process.stderr.write('AVA SCALE LAB error: ' + error.message + '\n');
    process.exitCode = 2;
  }
}

module.exports = {MAX_TARGET_NODES, MAX_SAMPLE_SIZE, simulateScale};
