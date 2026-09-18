'use strict';

const GITHUB_PROFILE_REPOSITORIES = Object.freeze([
	Object.freeze({
		name: 'AVA',
		icon: '🔷',
		url: 'https://github.com/hv2znbvdy9-glitch/AVA',
		description: 'AVA',
		language: 'PowerShell',
		createdAt: '2026-03-01T00:00:00Z',
		updatedAt: '2026-09-18T01:14:57Z',
		openIssues: 95,
		sizeKb: 787,
		stars: 1,
		defaultBranch: 'main',
		permissions: Object.freeze(['Admin', 'Maintain', 'Pull', 'Push', 'Triage']),
	}),
	Object.freeze({
		name: 'AVA-007',
		icon: '📘',
		url: 'https://github.com/hv2znbvdy9-glitch/AVA-007',
		description: 'Node.js test runner that lets you develop with confidence 🚀',
		language: 'JavaScript',
		license: 'MIT License',
		createdAt: '2026-04-03T00:00:00Z',
		updatedAt: '2026-09-18T01:15:01Z',
		openIssues: 6,
		sizeKb: 14096,
		stars: 1,
		defaultBranch: 'main',
		fork: true,
		permissions: Object.freeze(['Admin', 'Maintain', 'Pull', 'Push', 'Triage']),
	}),
	Object.freeze({
		name: 'DEVITO',
		icon: '🔧',
		url: 'https://github.com/hv2znbvdy9-glitch/DEVITO',
		description: '(keine Beschreibung)',
		language: 'PowerShell',
		createdAt: '2026-03-01T00:00:00Z',
		updatedAt: '2026-09-17T10:23:15Z',
		openIssues: 74,
		sizeKb: 1104,
		stars: 1,
		defaultBranch: 'main',
		permissions: Object.freeze(['Admin', 'Maintain', 'Pull', 'Push', 'Triage']),
	}),
]);

const GITHUB_PROFILE_REPORT_DATA = Object.freeze({
	referenceUrl: 'https://github.com/hv2znbvdy9-glitch',
	reportId: 'AVA 016101',
	title: 'Hörfassung: GitHub-Profilbericht',
	username: 'hv2znbvdy9-glitch',
	userId: 256433077,
	profileType: 'Einzelbenutzer',
	snapshotAt: '2026-09-18T01:30:34.786Z',
	repositories: GITHUB_PROFILE_REPOSITORIES,
});

function formatDate(dateString) {
	return new Intl.DateTimeFormat('de-DE', {
		day: '2-digit',
		month: 'long',
		year: 'numeric',
		timeZone: 'UTC',
	}).format(new Date(dateString));
}

function formatDateTime(dateString) {
	return new Intl.DateTimeFormat('de-DE', {
		day: '2-digit',
		month: 'long',
		year: 'numeric',
		hour: '2-digit',
		minute: '2-digit',
		second: '2-digit',
		timeZone: 'UTC',
		timeZoneName: 'short',
	}).format(new Date(dateString));
}

function formatInteger(value) {
	return new Intl.NumberFormat('de-DE').format(value);
}

function githubProfileReportData() {
	return {
		...GITHUB_PROFILE_REPORT_DATA,
		repositories: GITHUB_PROFILE_REPORT_DATA.repositories.map((repository) => ({
			...repository,
			permissions: [...repository.permissions],
		})),
	};
}

function githubProfileReport() {
	const data = githubProfileReportData();
	const totalOpenIssues = data.repositories.reduce((sum, repository) => sum + repository.openIssues, 0);
	const powerShellProjects = data.repositories.filter((repository) => repository.language === 'PowerShell');
	const javaScriptProjects = data.repositories.filter((repository) => repository.language === 'JavaScript');
	const repositorySections = data.repositories.map((repository, index) => {
		const details = [
			`- **URL:** ${repository.url}`,
			`- **Beschreibung:** ${repository.description}`,
			`- **Sprache:** ${repository.language}`,
		];

		if (repository.license) {
			details.push(`- **Lizenz:** ${repository.license}`);
		}

		details.push(
			`- **Erstellt:** ${formatDate(repository.createdAt)}`,
			`- **Zuletzt aktualisiert:** ${formatDateTime(repository.updatedAt)}`,
			`- **Status:** ${formatInteger(repository.openIssues)} offene Issues`,
			`- **Größe:** ${formatInteger(repository.sizeKb)} KB`,
			`- **Sterne:** ${formatInteger(repository.stars)}`,
			`- **Standard-Branch:** ${repository.defaultBranch}`,
		);

		if (repository.fork) {
			details.push('- **Typ:** Fork');
		}

		details.push(`- **Berechtigungen:** ${repository.permissions.join(', ')}`);

		return [
			`### ${index + 1}. **${repository.name}** ${repository.icon}`,
			...details,
		].join('\n');
	});

	return [
		`Referenz: ${data.referenceUrl}`,
		`# ${data.reportId} – ${data.title}`,
		'',
		'## Benutzerübersicht',
		'',
		`**Benutzername:** ${data.username}  `,
		`**Benutzer-ID:** ${formatInteger(data.userId)}  `,
		`**Profiltyp:** ${data.profileType}  `,
		`**Snapshot:** ${formatDateTime(data.snapshotAt)}`,
		'',
		'---',
		'',
		'## Repositories',
		'',
		`Du hast aktuell **${formatInteger(data.repositories.length)} öffentliche Repositories**:`,
		'',
		...repositorySections.flatMap((section) => [section, '', '---', '']),
		'## Zusammenfassung',
		'',
		`Du hast insgesamt **${formatInteger(totalOpenIssues)} offene Issues** in deinen Repositories verteilt.`,
		`Der Schwerpunkt liegt aktuell auf **${formatInteger(powerShellProjects.length)} PowerShell-Projekten** und **${formatInteger(javaScriptProjects.length)} JavaScript-Projekt**.`,
		'Alle drei Repositories sind öffentlich zugänglich und wurden in diesem Bericht als aktiver Profil-Snapshot zusammengefasst.',
		'',
		'## Kernaussage',
		'',
		'Das Profil zeigt eine kleine, aber klar erkennbare Sammlung aktiv gepflegter Projekte mit Schwerpunkt auf AVA-bezogenen Experimenten, Sicherheits- und Automatisierungsskripten sowie einem JavaScript-Test-Runner-Fork.',
		'',
		`**Ende der ${data.reportId} Hörfassung.**`,
	].join('\n');
}

module.exports = {
	githubProfileReport,
	githubProfileReportData,
	GITHUB_PROFILE_REPORT_DATA,
	GITHUB_PROFILE_REPOSITORIES,
};
