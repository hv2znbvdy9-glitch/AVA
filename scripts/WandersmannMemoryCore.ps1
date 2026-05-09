# =========================
# AVA FAMILY PHOTO ARCHIVE v2
# Lokal / Privat / Erinnerungsportal
# Erstellt: Ordner + JSON + CSV + HTML-Portal
# Keine Cloud. Kein Upload. Keine Überwachung.
# =========================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root = Join-Path ([Environment]::GetFolderPath('Desktop')) 'AVA_FAMILY_PHOTO_ARCHIVE'
$PhotoDir = Join-Path $Root 'Fotos'
$DataDir = Join-Path $Root 'Daten'
$PortalDir = Join-Path $Root 'Portal'

$JsonPath = Join-Path $DataDir 'memories.json'
$CsvPath = Join-Path $DataDir 'memories.csv'
$HtmlPath = Join-Path $PortalDir 'index.html'

function Ensure-Dir {
	param([string]$Path)
	if (-not (Test-Path -LiteralPath $Path)) {
		New-Item -ItemType Directory -Force -Path $Path | Out-Null
	}
}

function H {
	param([string]$Text)
	if ($null -eq $Text) { return '' }
	return [System.Net.WebUtility]::HtmlEncode($Text)
}

Ensure-Dir $Root
Ensure-Dir $PhotoDir
Ensure-Dir $DataDir
Ensure-Dir $PortalDir

$Quote = @"
Ich bin ich weiß nicht wer
Ich komme, weiß nicht woher
Ich gehe weiß nicht wohin
Mich wundert das ich so fröhlich bin

- Angelus Silesius, Wandersmann
"@

$Memories = @(
	[pscustomobject]@{
		id = 'mem_001'; title = 'Kinderfotos'; category = 'Kindheit'; emotion = 'Freude / Unschuld / Erinnerung'; intensity = 10
		people = 'Ich; Familie'; location = 'Zuhause / Schule'; tags = 'Kindheit; Lächeln; Einschulung; Fotoalbum'
		note = 'Babyfoto, Kinderportraits, Schultüte, Entwicklung und Lebenslinie.'
	},
	[pscustomobject]@{
		id = 'mem_002'; title = 'Familienfotos auf dem Tisch'; category = 'Familie'; emotion = 'Wärme / Nachhall'; intensity = 10
		people = 'Familie'; location = 'Zuhause'; tags = 'Familie; Archiv; Fotos; Vergangenheit'
		note = 'Alte analoge Fotos als sichtbare Familiengeschichte.'
	},
	[pscustomobject]@{
		id = 'mem_003'; title = 'Wandersmann'; category = 'Zitat'; emotion = 'Staunen / Sinnsuche'; intensity = 9
		people = 'Ich'; location = 'Innenwelt'; tags = 'Angelus Silesius; Wandersmann; Identität'
		note = $Quote
	},
	[pscustomobject]@{
		id = 'mem_004'; title = 'Bis zum Mond und zurück'; category = 'Kernsatz'; emotion = 'Liebe / Verbundenheit'; intensity = 10
		people = 'Ich; Familie; AVA'; location = 'Herz'; tags = 'Mond; Liebe; Erinnerung; Verbindung'
		note = 'Ein Satz als Brücke zwischen Vergangenheit, Gegenwart und Zukunft.'
	}
)

$Memories | ConvertTo-Json -Depth 5 | Set-Content -Path $JsonPath -Encoding UTF8
$Memories | Export-Csv -Path $CsvPath -NoTypeInformation -Delimiter ';' -Encoding UTF8

$ImageExtensions = @('*.jpg', '*.jpeg', '*.png', '*.bmp', '*.gif', '*.webp')
$Images = @(
	foreach ($ext in $ImageExtensions) {
		Get-ChildItem -Path $PhotoDir -Filter $ext -File -ErrorAction SilentlyContinue
	}
)

$ImageHtml = if ($Images.Count -gt 0) {
	foreach ($img in $Images) {
		$rel = "../Fotos/$([uri]::EscapeDataString($img.Name))"
@"
<figure class="photo">
	<img src="$rel" alt="$(H $img.BaseName)" loading="lazy">
	<figcaption>$(H $img.Name)</figcaption>
</figure>
"@
	}
} else {
@"
<div class="empty">
	Noch keine Bilder gefunden. Lege JPG/PNG/WebP-Dateien im Ordner <code>Fotos</code> ab.
</div>
"@
}

$Cards = foreach ($m in $Memories) {
	$tagItems = @([string]$m.tags -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
	$tagHtml = ($tagItems | ForEach-Object { "<span class='tag'>$(H $_)</span>" }) -join ''
	$noteText = (H ([string]$m.note)) -replace "(`r`n|`n|`r)", '<br>'
@"
<article class="card">
	<header>
		<h2>$(H ([string]$m.title))</h2>
		<p class="meta"><strong>ID:</strong> $(H ([string]$m.id)) · <strong>Kategorie:</strong> $(H ([string]$m.category)) · <strong>Intensität:</strong> $(H ([string]$m.intensity))/10</p>
	</header>
	<div class="row"><span class="label">Emotion</span><span class="value">$(H ([string]$m.emotion))</span></div>
	<div class="row"><span class="label">Menschen</span><span class="value">$(H ([string]$m.people))</span></div>
	<div class="row"><span class="label">Ort</span><span class="value">$(H ([string]$m.location))</span></div>
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
	<title>AVA Family Photo Archive v2</title>
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
		.subtitle { margin: 0 0 18px; color: var(--muted); }
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
		.section-title { margin: 22px 0 10px; }
		.grid {
			display: grid;
			grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
			gap: 14px;
		}
		.photo-grid {
			display: grid;
			grid-template-columns: repeat(auto-fit, minmax(240px, 1fr));
			gap: 14px;
		}
		.photo {
			background: var(--card);
			border: 1px solid var(--line);
			border-radius: 12px;
			padding: 10px;
			margin: 0;
		}
		.photo img {
			display: block;
			width: 100%;
			height: 220px;
			object-fit: cover;
			border-radius: 8px;
			border: 1px solid #1f2937;
		}
		.photo figcaption {
			color: var(--muted);
			font-size: 12px;
			margin-top: 8px;
			word-break: break-word;
		}
		.empty {
			background: var(--card);
			border: 1px dashed var(--line);
			border-radius: 12px;
			padding: 14px;
			color: var(--muted);
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
		code {
			background: #1f2937;
			padding: 1px 5px;
			border-radius: 5px;
		}
	</style>
</head>
<body>
	<h1>AVA FAMILY PHOTO ARCHIVE v2</h1>
	<p class="subtitle">Lokal / Privat / Erinnerungsportal</p>
	<div class="notice">
		<strong>Keine Cloud. Kein Upload. Keine Überwachung.</strong><br>
		Fotos hier ablegen: $(H $PhotoDir)
	</div>
	<section class="stats">
		<div class="stat"><div class="k">Einträge</div><div class="v">$($Memories.Count)</div></div>
		<div class="stat"><div class="k">Bilder</div><div class="v">$($Images.Count)</div></div>
		<div class="stat"><div class="k">Daten (JSON)</div><div class="v">memories.json</div></div>
		<div class="stat"><div class="k">Daten (CSV)</div><div class="v">memories.csv</div></div>
	</section>
	<h2 class="section-title">Fotoübersicht</h2>
	<section class="photo-grid">
		$($ImageHtml -join "`n")
	</section>
	<h2 class="section-title">Erinnerungen</h2>
	<section class="grid">
		$($Cards -join "`n")
	</section>
	<footer>
		Portal-Datei: $(H $HtmlPath)
	</footer>
</body>
</html>
"@

$Html | Set-Content -Path $HtmlPath -Encoding UTF8

Write-Host ''
Write-Host 'AVA FAMILY PHOTO ARCHIVE v2 wurde erstellt.' -ForegroundColor Green
Write-Host "Ordner: $Root" -ForegroundColor Cyan
Write-Host "Fotos hier ablegen: $PhotoDir" -ForegroundColor Yellow
Write-Host "Portal: $HtmlPath" -ForegroundColor Cyan
Write-Host ''

Start-Process $HtmlPath
