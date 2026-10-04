'use strict';

const AVATAR_01610_LAYERS = Object.freeze([
	'physisch',
	'mental',
	'digital',
	'sozial',
	'symbolisch',
]);

const AVATAR_01610_CYCLE = Object.freeze([
	'Beobachtung',
	'Evidenz',
	'Interpretation',
	'Entscheidung',
	'Handlung',
	'Erfahrung',
	'Anpassung',
]);

const AVATAR_01610_PRINCIPLES = Object.freeze([
	'Nicht jede Wahrnehmung ist ein Fakt.',
	'Nicht jede Möglichkeit ist ein Ereignis.',
	'Nicht jedes Ereignis ist ein Ergebnis.',
	'Erst Evidenz macht eine Aussage belastbar.',
]);

const AVATAR_01610_REPORT = `AVA 01610 – AVATAR–01610 DEVITO

Leitgedanke:
Realität ist nicht flach. Eine Situation kann auf mehreren Beschreibungsebenen
betrachtet werden, ohne diese Ebenen gleichzusetzen.

Ebenen:
- Physisch: Körper und beobachtbare Umwelt.
- Mental: Wahrnehmung, Denken und innere Modelle.
- Digital: Daten, Aufzeichnungen und technische Systeme.
- Sozial: andere Menschen, Perspektiven und Netzwerke.
- Symbolisch: Metaphern und Deutungsrahmen.

Arbeitszyklus:
Beobachtung → Evidenz → Interpretation → Entscheidung → Handlung →
Erfahrung → Anpassung → erneute Beobachtung.

Epistemische Leitlinien:
- Nicht jede Wahrnehmung ist ein Fakt.
- Nicht jede Möglichkeit ist ein Ereignis.
- Nicht jedes Ereignis ist ein Ergebnis.
- Erst Evidenz macht eine Aussage belastbar.

Quantum-Identität ist hier ausdrücklich eine Metapher:
- Superposition steht für mehrere mögliche Wege.
- Entscheidung steht für die Wahl eines Weges.
- Handlung macht eine Möglichkeit zu beobachtbarem Verhalten.
- Wiederholung kann Verhalten zu einem Muster formen.
- Muster können zur Veränderung der Identität beitragen.

Wissenschaftliche Grenze:
Diese Metapher ist keine Behauptung, dass Bewusstsein einen quantenmechanischen
Kollaps der äußeren Realität verursacht. Quantenphysik belegt keine beliebige
Kontrolle äußerer Ereignisse durch Gedanken. Der Avatar ist nicht allwissend;
Aussagen über andere Menschen, Systeme und Informationen benötigen überprüfbare
Evidenz.

Dokumentation: docs/avatar-01610-devito.md`;

function avatar01610Report() {
	return AVATAR_01610_REPORT;
}

function avatar01610Data() {
	return {
		name: 'AVATAR–01610 DEVITO',
		guidingPrinciple: 'Realität ist nicht flach.',
		layers: [...AVATAR_01610_LAYERS],
		cycle: [...AVATAR_01610_CYCLE],
		principles: [...AVATAR_01610_PRINCIPLES],
		quantumIdentity: {
			type: 'Metapher',
			sequence: ['Möglichkeiten', 'Entscheidung', 'Handlung', 'Muster', 'Identitätsanpassung'],
			claimAboutPhysicalCollapse: false,
		},
		omniscient: false,
	};
}

module.exports = {
	avatar01610Report,
	avatar01610Data,
	AVATAR_01610_REPORT,
	AVATAR_01610_LAYERS,
	AVATAR_01610_CYCLE,
	AVATAR_01610_PRINCIPLES,
};
