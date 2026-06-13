'use strict';

/**
 * AVA State Scale: maps integer scores (-3..+3) to named system states.
 *
 * -3 = COLLAPSE  – severe compromise / total failure
 * -2 = CRITICAL  – critical danger
 * -1 = UNSTABLE  – notable deviation
 *  0 = NEUTRAL   – unclear / no data
 * +1 = STABLE    – controlled / stable
 * +2 = STRONG    – robustly stable
 * +3 = OPTIMAL   – fully secure / optimal
 */
const STATE_LABELS = {
	'-3': 'COLLAPSE',
	'-2': 'CRITICAL',
	'-1': 'UNSTABLE',
	'0': 'NEUTRAL',
	'1': 'STABLE',
	'2': 'STRONG',
	'3': 'OPTIMAL',
};

/**
 * Clamp an integer to the valid state-scale range [-3, +3].
 * @param {number} value - The raw score to clamp.
 * @returns {number} The clamped integer score.
 */
function clampScore(value) {
	return Math.max(-3, Math.min(3, Math.round(value)));
}

/**
 * Return the state label for a given integer score.
 * Values outside [-3, +3] are clamped before lookup.
 * @param {number} score - Integer score in the range [-3, +3].
 * @returns {string} The state label (e.g. 'STABLE').
 */
function classifyState(score) {
	const clamped = clampScore(score);
	return STATE_LABELS[String(clamped)];
}

/**
 * Calculate a weighted score from an array of signals and clamp the result.
 *
 * Each signal is an object with:
 *   - value  {number}  Raw signal value (positive = good, negative = bad).
 *   - weight {number}  Relative importance (default: 1).
 *
 * The function computes the weighted sum, divides by the total weight, and
 * maps the result to the nearest integer in [-3, +3].
 *
 * @param {{value: number, weight?: number}[]} signals - Array of signal objects.
 * @returns {number} The clamped integer score.
 * @throws {Error} If signals is not a non-empty array.
 */
function calculateScore(signals) {
	if (!Array.isArray(signals) || signals.length === 0) {
		throw new Error('signals must be a non-empty array');
	}

	let weightedSum = 0;
	let totalWeight = 0;

	for (const signal of signals) {
		const weight = signal.weight !== undefined ? signal.weight : 1;
		weightedSum += signal.value * weight;
		totalWeight += weight;
	}

	const average = weightedSum / totalWeight;
	return clampScore(average);
}

module.exports = {STATE_LABELS, clampScore, classifyState, calculateScore};
