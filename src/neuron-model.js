'use strict';

const NEURON_MODEL_REFERENCES = Object.freeze([
	Object.freeze({
		title: 'Hay et al. (2011) - L5b pyramidal cell models',
		url: 'https://journals.plos.org/ploscompbiol/article?id=10.1371/journal.pcbi.1002107',
	}),
	Object.freeze({
		title: 'DeepDendrite (2023) - GPU simulation with explicit spines',
		url: 'https://www.nature.com/articles/s41467-023-41553-7',
	}),
	Object.freeze({
		title: 'Blue Brain microcircuit reliability study (2019)',
		url: 'https://www.nature.com/articles/s41467-019-11633-8',
	}),
	Object.freeze({
		title: 'Toward reference-grade neuron models (2026)',
		url: 'https://www.nature.com/articles/s42003-026-10561-w',
	}),
]);

const NEURON_MODEL_REPORT = `AVA Neuronenmodell-Analyse

Tatsächlich in AVA implementiert:
- Deterministisches klassisches Einzelkompartiment-Hodgkin-Huxley-Modell.
- Na+, K+ und Leckströme mit m-, h- und n-Toren.
- Begrenzte, getestete CLI-Demonstration ohne Netzwerk- oder Systemaktion.

Wissenschaftlicher Ausbaupfad:
- Aktives Multi-Kompartiment-Hodgkin-Huxley-Modell einer Schicht-5-Pyramidenzelle.
- Räumliche Morphologie, axiale Kopplung und ortsabhängige Ionenkanäle.
- Validierung gegen veröffentlichte Messdaten sowie Konvergenz- und Unsicherheitsanalysen.

Einordnung:
- Hay et al.: detaillierte L5b-Modelle mit perisomatischen und dendritischen aktiven Eigenschaften.
- DeepDendrite: GPU-Framework; Demonstration mit 24.994 passiv modellierten expliziten Spines.
- „Intelligentestes Neuronenmodell“ ist kein wissenschaftliches Standardkriterium.
- Das Modul ist kein Lernsystem, kein Bewusstsein und kein autonomer AVA/JARVIS-Agent.

Details:
- docs/biologisch-plausible-neuronenmodelle.md

Ausführen:
- npm run neuron:model
- npm run neuron:sim`;

/**
 * Returns the analysis text for biologically plausible single-neuron models.
 * @returns {string}
 */
function neuronModelReport() {
	return NEURON_MODEL_REPORT;
}

/**
 * Returns structured data for the neuron-model analysis.
 * @returns {{candidate: string, category: string, references: {title: string, url: string}[]}}
 */
function neuronModelData() {
	return {
		candidate: 'Aktives Multi-Kompartiment-Hodgkin-Huxley-Modell einer Schicht-5-Pyramidenzelle',
		category: 'biologisch plausibles Einzelneuronenmodell',
		references: NEURON_MODEL_REFERENCES.map((reference) => ({...reference})),
	};
}

module.exports = {neuronModelReport, neuronModelData, NEURON_MODEL_REPORT, NEURON_MODEL_REFERENCES};
