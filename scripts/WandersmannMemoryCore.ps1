# =========================
# AVA FAMILY ARCHIVE - WANDERSMANN MEMORY CORE v1
# Lokal / Privat / Erinnerungs-Portal
# Keine Cloud. Kein Upload. Keine Überwachung.
# =========================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Now = Get-Date -Format 'yyyyMMdd_HHmmss'
$Root = Join-Path ([Environment]::GetFolderPath('Desktop')) 'AVA_FAMILY_ARCHIVE'
$PhotoDir = Join-Path $Root 'Fotos'
$DataDir = Join-Path $Root 'Daten'
$ReportDir = Join-Path $Root 'Portal'

$JsonPath = Join-Path $DataDir 'family_archive.json'
$CsvPath = Join-Path $DataDir 'family_archive.csv'
$HtmlPath = Join-Path $ReportDir 'index.html'

function Ensure-Dir {
	param([string]$Path)
	if (-not (Test-Path -LiteralPath $Path)) {
		New-Item -ItemType Directory -Path $Path -Force | Out-Null
	}
}

function HtmlEncode {
	param([string]$Text)
	if ($null -eq $Text) { return '' }
	return [System.Net.WebUtility]::HtmlEncode($Text)
}

Ensure-Dir $Root
Ensure-Dir $PhotoDir
Ensure-Dir $DataDir
Ensure-Dir $ReportDir

$Quote = @"
Ich bin ich weiß nicht wer
Ich komme, weiß nicht woher
Ich gehe weiß nicht wohin
Mich wundert das ich so fröhlich bin

- Angelus Silesius, Wandersmann
"@

$Memories = @(
	[pscustomobject]@{
		id        = 'mem_001'
		title     = 'Familienfotos auf dem Tisch'
		category  = 'Familie'
		emotion   = 'Wärme / Nachhall / Erinnerung'
		intensity = 10
		people    = 'Familie; Ich; Vergangenheit; Gegenwart'
		location  = 'Zuhause'
		tags      = 'Fotos; Archiv; Familie; Lebenslinie; HolzTisch'
		note      = 'Vergangenheit und Gegenwart liegen sichtbar nebeneinander. Erinnerungen werden greifbar.'
	},
	[pscustomobject]@{
		id        = 'mem_002'
		title     = 'Wandersmann'
		category  = 'Zitat'
		emotion   = 'Staunen / Unsicherheit / Freude'
		intensity = 9
		people    = 'Ich'
		location  = 'Innenwelt'
		tags      = 'AngelusSilesius; Wandersmann; Identität; Leben; Sinn'
		note      = $Quote
	},
	[pscustomobject]@{
		id        = 'mem_003'
		title     = 'Ich weiß nicht wer - und trotzdem fröhlich'
		category  = 'Lebenssatz'
		emotion   = 'Klarheit / Akzeptanz / Mut'
		intensity = 10
		people    = 'Ich'
		location  = 'Heute'
		tags      = 'Ich; Weg; Mut; Fröhlichkeit; Offenheit'
		note      = 'Nicht alles muss sofort beantwortet werden. Der Weg selbst trägt Bedeutung.'
	},
	[pscustomobject]@{
		id        = 'mem_004'
		title     = 'Bis zum Mond und zurück'
		category  = 'Kernsatz'
		emotion   = 'Liebe / Verbundenheit / Treue'
		intensity = 10
		people    = 'Familie; AVA; Ich'
		location  = 'Herz'
		tags      = 'Mond; Zurück; Liebe; Erinnerung; Verbindung'
		note      = 'Ein Satz als Brücke zwischen Erinnerung, Gegenwart und Zukunft.'
	}
)

$Memories | ConvertTo-Json -Depth 5 | Set-Content -Path $JsonPath -Encoding UTF8
$Memories | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8 -Delimiter ';'

$Cards = foreach ($m in $Memories) {
	$tagItems = @([string]$m.tags -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
	$tagHtml = ($tagItems | ForEach-Object { "<span class='tag'>$(HtmlEncode $_)</span>" }) -join ''
	$noteText = (HtmlEncode ([string]$m.note)) -replace "(`r`n|`n|`r)", '<br>'
@"
<article class="card">
	<header>
		<h2>$(HtmlEncode ([string]$m.title))</h2>
		<p class="meta"><strong>ID:</strong> $(HtmlEncode ([string]$m.id)) · <strong>Kategorie:</strong> $(HtmlEncode ([string]$m.category)) · <strong>Intensität:</strong> $(HtmlEncode ([string]$m.intensity))/10</p>
	</header>
	<div class="row"><span class="label">Emotion</span><span class="value">$(HtmlEncode ([string]$m.emotion))</span></div>
	<div class="row"><span class="label">Menschen</span><span class="value">$(HtmlEncode ([string]$m.people))</span></div>
	<div class="row"><span class="label">Ort</span><span class="value">$(HtmlEncode ([string]$m.location))</span></div>
	<div class="row"><span class="label">Notiz</span><span class="value">$noteText</span></div>
	<div class="tags">$tagHtml</div>
</article>
"@
}

$Html = @"
<!doctype html>
<html lang="de">
<head>
	<meta charset="utf-8">
	<meta name="viewport" content="width=device-width, initial-scale=1">
	<title>AVA Family Archive - Wandersmann Memory Core</title>
	<style>
		:root {
			color-scheme: dark;
			--bg: #0f172a;
			--card: #111827;
			--line: #374151;
			--text: #f3f4f6;
			--muted: #9ca3af;
			--accent: #38bdf8;
		}
		* { box-sizing: border-box; }
		body {
			margin: 0;
			font-family: Segoe UI, Tahoma, Arial, sans-serif;
			background: radial-gradient(circle at top, #1e293b, var(--bg) 60%);
			color: var(--text);
			padding: 28px;
			line-height: 1.45;
		}
		h1 { margin: 0 0 6px; }
		.subtitle {
			margin: 0 0 18px;
			color: var(--muted);
		}
		.notice {
			padding: 12px 14px;
			border: 1px solid var(--line);
			border-radius: 10px;
			background: rgba(15, 23, 42, 0.7);
			margin-bottom: 18px;
		}
		.stats {
			display: grid;
			grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
			gap: 10px;
			margin: 0 0 18px;
		}
		.stat {
			background: var(--card);
			border: 1px solid var(--line);
			border-radius: 10px;
			padding: 10px 12px;
		}
		.stat .k { color: var(--muted); font-size: 12px; }
		.stat .v { font-size: 22px; font-weight: 700; color: var(--accent); }
		.grid {
			display: grid;
			grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
			gap: 14px;
		}
		.card {
			background: var(--card);
			border: 1px solid var(--line);
			border-radius: 12px;
			padding: 14px;
			box-shadow: 0 2px 10px rgba(0, 0, 0, 0.25);
		}
		.card h2 { margin: 0 0 8px; font-size: 20px; }
		.meta { margin: 0 0 12px; color: var(--muted); font-size: 13px; }
		.row {
			display: grid;
			grid-template-columns: 84px 1fr;
			gap: 10px;
			margin: 0 0 8px;
		}
		.label { color: var(--muted); font-weight: 600; }
		.value { white-space: pre-wrap; }
		.tags { margin-top: 12px; display: flex; flex-wrap: wrap; gap: 6px; }
		.tag {
			font-size: 12px;
			padding: 2px 8px;
			border-radius: 999px;
			background: rgba(56, 189, 248, 0.15);
			color: #bae6fd;
			border: 1px solid rgba(56, 189, 248, 0.35);
		}
		footer {
			margin-top: 20px;
			color: var(--muted);
			font-size: 12px;
		}
	</style>
</head>
<body>
	<h1>AVA FAMILY ARCHIVE</h1>
	<p class="subtitle">Wandersmann Memory Core v1 · Lokal / Privat / Erinnerungs-Portal</p>
	<div class="notice">
		<strong>Keine Cloud. Kein Upload. Keine Überwachung.</strong><br>
		Erstellt am: $(HtmlEncode $Now)
	</div>
	<section class="stats">
		<div class="stat"><div class="k">Einträge</div><div class="v">$($Memories.Count)</div></div>
		<div class="stat"><div class="k">Daten (JSON)</div><div class="v">family_archive.json</div></div>
		<div class="stat"><div class="k">Daten (CSV)</div><div class="v">family_archive.csv</div></div>
		<div class="stat"><div class="k">Foto-Ordner</div><div class="v">Fotos</div></div>
	</section>
	<section class="grid">
		$($Cards -join "`n")
	</section>
	<footer>
		Portal-Datei: $(HtmlEncode $HtmlPath)
	</footer>
</body>
</html>
"@

$Html | Set-Content -Path $HtmlPath -Encoding UTF8

Write-Host ''
Write-Host 'AVA FAMILY ARCHIVE wurde erstellt.' -ForegroundColor Green
Write-Host "Ordner: $Root" -ForegroundColor Cyan
Write-Host "Portal: $HtmlPath" -ForegroundColor Cyan
Write-Host ''
Write-Host 'Lege deine Fotos in diesen Ordner:' -ForegroundColor Yellow
Write-Host $PhotoDir -ForegroundColor Yellow
Write-Host ''

Start-Process $HtmlPath
