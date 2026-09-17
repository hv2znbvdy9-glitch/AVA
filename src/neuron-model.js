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
- Vollständig aktives Multi-Kompartiment-Hodgkin-Huxley-Modell einer Schicht-5-Pyramidenzelle.

Warum deutlich komplexer als Leaky-Integrate-and-Fire:
- Reale 3D-Morphologie mit Soma, Axon und verzweigtem Dendritenbaum.
- Räumlich verteilte Ionenkanäle (u.a. Na+, K+, Ca2+, HCN).
- Lokale dendritische Nichtlinearitäten (NMDA-/Calcium-Spikes, Plateaus).
- Kopplung mit rücklaufenden Aktionspotenzialen und Burst-Mustern.

Extrembeispiel:
- DeepDendrite mit ~25.000 explizit modellierten dendritischen Spines.

Wichtig:
- "Intelligentestes Neuronenmodell" ist kein Standardkriterium.
- Bewertet wird eher nach biologischer Genauigkeit, Vorhersagekraft, Lernfähigkeit, Effizienz und Validierung.
- Ein vollständig integriertes digitales Neuron (inkl. kompletter Biochemie, Plastizität, Metabolismus, Glia) existiert derzeit nicht.

Details:
- docs/biologisch-plausible-neuronenmodelle.md

Ausführbarer, begrenzter Einstieg:
- ava --neuron-sim`;

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
