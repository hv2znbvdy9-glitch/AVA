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

Klarer Kandidat auf Einzelneuronen-Ebene:
- Ein morphologisch rekonstruiertes, aktives Multi-Kompartiment-Hodgkin-Huxley-Modell einer Schicht-5-Pyramidenzelle.

Hay-L5b, wissenschaftlich präzisiert:
- Rekonstruierter Soma- und Dendritenbaum mit im Mittel etwa 200 Kompartimenten.
- Räumlich verteilte Na+-, K+-, Ca2+- und HCN-bezogene Mechanismen.
- Reproduktion perisomatischer Spikes, dendritischer Calciumspikes, Rückpropagation und BAC-Firing-Zielmerkmalen.
- Das Hauptmodell besitzt kein vollständig rekonstruiertes Axon: Nur das Anfangssegment blieb erhalten; die Spikezone wurde vereinfacht perisomatisch modelliert.
- NMDA-Spikes sind kein implementierter Kernmechanismus dieses Hay-Modells.

DeepDendrite:
- 24.994 explizite Spines in einem detaillierten menschlichen Pyramidenzellmodell.
- Explizite Spine-Geometrie bedeutet nicht automatisch vollständige aktive Spine-Biochemie.

Wichtig:
- "Intelligentestes Neuronenmodell" ist kein Standardkriterium.
- Bewertet wird eher nach biologischer Genauigkeit, Vorhersagekraft, Lernfähigkeit, Effizienz, Provenienz, Unsicherheit und Validierung.
- Ein vollständig integriertes digitales Neuron inklusive kompletter Biochemie, Plastizität, Metabolismus und Glia existiert derzeit nicht.

AVA-Implementierung:
- ava --neuron-sim startet den klassischen Ein-Kompartiment-Lehrprototyp.
- ava-neuro-hh-l5-prototype/v1 ist der ausführbare Sieben-Kompartiment-Prototyp (ava --neuro-hh).
- Er ist kein experimentell angepasstes Hay-Modell und macht keinen solchen Anspruch.

Details:
- docs/biologisch-plausible-neuronenmodelle.md
- docs/AVA_NEURO_HH_IMPLEMENTATION.md`;

/**
 * Returns the analysis text for biologically plausible single-neuron models.
 * @returns {string}
 */
function neuronModelReport() {
	return NEURON_MODEL_REPORT;
}

/**
 * Returns structured data for the neuron-model analysis.
 * @returns {{candidate: string, category: string, implementation: {id: string, status: string}, references: {title: string, url: string}[]}}
 */
function neuronModelData() {
	return {
		candidate: 'Aktives Multi-Kompartiment-Hodgkin-Huxley-Modell einer Schicht-5-Pyramidenzelle',
		category: 'biologisch plausibles Einzelneuronenmodell',
		implementation: {
			id: 'ava-neuro-hh-l5-prototype/v1',
			status: 'educational-prototype-not-experimentally-fitted',
		},
		references: NEURON_MODEL_REFERENCES.map((reference) => ({...reference})),
	};
}

module.exports = {neuronModelReport, neuronModelData, NEURON_MODEL_REPORT, NEURON_MODEL_REFERENCES};
