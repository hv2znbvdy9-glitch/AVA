'use strict';

const STATUS = {
	CALM: 'ruhig',
	OBSERVE: 'beobachten',
	MEDICAL_SOON: 'ärztlich zeitnah',
	EMERGENCY: 'Notfall',
};

const REQUIRED_FIELDS = [
	'timestamp',
	'durationMinutes',
	'sleepHours',
	'stressLevel',
	'earPressure',
	'headache',
	'medicationsSubstances',
	'pulse',
	'immediateContext',
	'changes',
	'notes',
];

function hasValue(value) {
	if (typeof value === 'string') {
		return value.trim().length > 0;
	}

	return value !== undefined && value !== null;
}

function cloneChanges(changes) {
	return {
		speech: Boolean(changes.speech),
		strength: Boolean(changes.strength),
		vision: Boolean(changes.vision),
		orientation: Boolean(changes.orientation),
	};
}

function createEpisode(input = {}) {
	if (!input || typeof input !== 'object' || Array.isArray(input)) {
		throw new Error('episode input must be an object');
	}

	const changes = input.changes && typeof input.changes === 'object' && !Array.isArray(input.changes)
		? cloneChanges(input.changes)
		: null;

	const episode = {
		timestamp: input.timestamp || new Date().toISOString(),
		durationMinutes: input.durationMinutes,
		sleepHours: input.sleepHours,
		stressLevel: input.stressLevel,
		earPressure: input.earPressure,
		headache: input.headache,
		medicationsSubstances: input.medicationsSubstances,
		pulse: input.pulse,
		immediateContext: input.immediateContext,
		changes,
		notes: input.notes,
		foreignControlFeeling: Boolean(input.foreignControlFeeling),
		severeConfusion: Boolean(input.severeConfusion),
		suddenSevereHeadache: Boolean(input.suddenSevereHeadache),
		facialDroop: Boolean(input.facialDroop),
		unilateralNumbness: Boolean(input.unilateralNumbness),
	};

	const missing = missingRequiredFields(episode);
	if (missing.length > 0) {
		throw new Error(`missing required episode fields: ${missing.join(', ')}`);
	}

	return episode;
}

function missingRequiredFields(episode) {
	const missing = [];

	REQUIRED_FIELDS.forEach((field) => {
		if (!hasValue(episode[field])) {
			missing.push(field);
		}
	});

	if (episode.changes) {
		['speech', 'strength', 'vision', 'orientation'].forEach((key) => {
			if (!Object.prototype.hasOwnProperty.call(episode.changes, key)) {
				missing.push(`changes.${key}`);
			}
		});
	}

	return missing;
}

function enterProtectionMode(trigger = 'Gefühl von Fremdsteuerung') {
	return {
		enabled: true,
		trigger,
		rule: 'Keine Aktion gegen andere, erst objektive Prüfung.',
	};
}

function hasEmergencySigns(episode) {
	const changes = episode.changes || {};
	return Boolean(
		changes.speech ||
		changes.strength ||
		changes.vision ||
		changes.orientation ||
		episode.suddenSevereHeadache ||
		episode.severeConfusion ||
		episode.facialDroop ||
		episode.unilateralNumbness
	);
}

function normalizeHistory(history) {
	if (!history) {
		return [];
	}

	if (!Array.isArray(history)) {
		throw new Error('history must be an array');
	}

	return history;
}

function evaluateEpisode(episodeInput, historyInput = []) {
	const episode = createEpisode(episodeInput);
	const history = normalizeHistory(historyInput);
	const emergency = hasEmergencySigns(episode);
	const protectionMode = episode.foreignControlFeeling ? enterProtectionMode() : {enabled: false};
	const repeatedEpisodes = history.length + 1 >= 2;
	let status = STATUS.CALM;
	let nextAction = 'Weiter beobachten und Datenqualität verbessern.';

	if (emergency) {
		status = STATUS.EMERGENCY;
		nextAction = 'Sofortige Notfallabklärung veranlassen.';
	} else if (repeatedEpisodes) {
		status = STATUS.MEDICAL_SOON;
		nextAction = 'Zeitnahe HNO/Neurologie/Psychiatrie-Abklärung organisieren.';
	} else if (episode.foreignControlFeeling) {
		status = STATUS.OBSERVE;
		nextAction = 'Schutzmodus aktivieren und objektive Zeichen dokumentieren.';
	}

	return {
		status,
		emergency,
		protectionMode,
		nextAction,
		evidenceOnly: true,
	};
}

function summarizeEpisode(episodeInput, evaluationInput) {
	const episode = createEpisode(episodeInput);
	const evaluation = evaluationInput || evaluateEpisode(episode);

	return {
		what: episode.notes,
		when: episode.timestamp,
		howLongMinutes: episode.durationMinutes,
		howStrong: episode.stressLevel,
		warningSigns: {
			speech: episode.changes.speech,
			strength: episode.changes.strength,
			vision: episode.changes.vision,
			orientation: episode.changes.orientation,
			suddenSevereHeadache: episode.suddenSevereHeadache,
			severeConfusion: episode.severeConfusion,
			facialDroop: episode.facialDroop,
			unilateralNumbness: episode.unilateralNumbness,
		},
		status: evaluation.status,
		nextAction: evaluation.nextAction,
	};
}

function buildTrend(episodesInput = []) {
	if (!Array.isArray(episodesInput)) {
		throw new Error('episodes must be an array');
	}

	const episodes = episodesInput.map((episode) => createEpisode(episode));
	const statusCounts = {
		[STATUS.CALM]: 0,
		[STATUS.OBSERVE]: 0,
		[STATUS.MEDICAL_SOON]: 0,
		[STATUS.EMERGENCY]: 0,
	};
	const triggerPatterns = {};
	const symptomCombinations = {};

	episodes.forEach((episode, index) => {
		const evaluation = evaluateEpisode(episode, episodes.slice(0, index));
		statusCounts[evaluation.status]++;

		const trigger = episode.immediateContext;
		triggerPatterns[trigger] = (triggerPatterns[trigger] || 0) + 1;

		const activeSymptoms = Object.entries(episode.changes)
			.filter((entry) => entry[1])
			.map((entry) => entry[0])
			.sort();
		const comboKey = activeSymptoms.length > 0 ? activeSymptoms.join('+') : 'none';
		symptomCombinations[comboKey] = (symptomCombinations[comboKey] || 0) + 1;
	});

	return {
		totalEpisodes: episodes.length,
		frequency: episodes.length,
		statusCounts,
		triggerPatterns,
		symptomCombinations,
	};
}

module.exports = {
	STATUS,
	REQUIRED_FIELDS,
	createEpisode,
	missingRequiredFields,
	enterProtectionMode,
	hasEmergencySigns,
	evaluateEpisode,
	summarizeEpisode,
	buildTrend,
};
