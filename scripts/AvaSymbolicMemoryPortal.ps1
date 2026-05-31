#requires -Version 5.1
<#
AVA SYMBOLIC MEMORY PORTAL
Lokal / Privat / Read-Only / Kein Upload / Keine Überwachung

Erstellt:
- Ordnerstruktur
- JSON Memory-Datei
- CSV Export
- HTML Portal
- Symbolische Mindmap
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root = Join-Path $env:USERPROFILE 'Desktop\AVA_SYMBOLIC_MEMORY_PORTAL'
$DataDir = Join-Path $Root 'Daten'
$PortalDir = Join-Path $Root 'Portal'

$JsonPath = Join-Path $DataDir 'symbolic_memory.json'
$CsvPath = Join-Path $DataDir 'symbolic_memory.csv'
$HtmlPath = Join-Path $PortalDir 'index.html'

function Ensure-Dir {
param([string]$Path)
if (-not (Test-Path -LiteralPath $Path)) {
New-Item -ItemType Directory -Force -Path $Path | Out-Null
}
}

function H {
param([AllowNull()][object]$Value)
if ($null -eq $Value) { return '' }
return [System.Net.WebUtility]::HtmlEncode([string]$Value)
}

Ensure-Dir $Root
Ensure-Dir $DataDir
Ensure-Dir $PortalDir

$Memories = @(
[pscustomobject]@{
id = 'sym_001'
title = 'AI Tools'
category = 'Technik'
meaning = 'Werkzeuge, Automatisierung, Assistenz, Kreativität'
tags = 'AI;Tools;Automation;Coding;Writing;Design'
note = 'KI-Werkzeuge als praktische Helfer: nicht Magie, sondern strukturierte Unterstützung.'
},
[pscustomobject]@{
id = 'sym_002'
title = 'Was nicht mein ist'
category = 'Affirmation'
meaning = 'Loslassen, Schutz, innere Ordnung'
tags = 'Schutz;Fokus;Loslassen;Energie;Klarheit'
note = 'Was nicht mein ist, soll nicht bleiben. Ich löse mich. Energie kehrt zu mir zurück.'
},
[pscustomobject]@{
id = 'sym_003'
title = 'Alte Kulturen und Pyramiden'
category = 'Geschichte / Symbolik'
meaning = 'Architektur, Zivilisation, Erinnerung, Menschheitsgeschichte'
tags = 'Pyramiden;Kulturen;Zeit;Architektur;Geschichte'
note = 'Bilder alter Bauwerke als Erinnerung daran, dass Menschen schon immer Muster, Ordnung und Bedeutung gesucht haben.'
},
[pscustomobject]@{
id = 'sym_004'
title = 'Geometrie und Goldener Schnitt'
category = 'Mathematik / Symbolik'
meaning = 'Muster, Verhältnis, Struktur, Form'
tags = 'Geometrie;Phi;Goldener Schnitt;Muster;Form'
note = 'Mathematik als echte Sprache von Struktur. Symbolische Bedeutung getrennt von wissenschaftlicher Behauptung betrachten.'
},
[pscustomobject]@{
id = 'sym_005'
title = 'Klang und Frequenz'
category = 'Physik / Wahrnehmung'
meaning = 'Schall, Resonanz, Stimme, Atmosphäre'
tags = 'Frequenz;Klang;Schall;Resonanz;Stimme'
note = 'Reale Physik: Schall ist Druckwelle. Symbolisch: Klang kann Erinnerung und Stimmung stark beeinflussen.'
},
[pscustomobject]@{
id = 'sym_006'
title = 'AVA Memory Core'
category = 'Systemdenken'
meaning = 'Daten zu Ereignissen, Ereignisse zu Mustern, Muster zu Verständnis'
tags = 'AVA;Memory;Graph;Timeline;Baseline;Delta'
note = 'Fakten vor Angst. Baseline vor Chaos. Sichtbarkeit vor Kontrolle.'
},
[pscustomobject]@{
id = 'sym_007'
title = 'LaFamilia bleibt LaFamilia'
category = 'Familie / Erinnerung'
meaning = 'Verbundenheit, Erinnerung, Schutz, Liebe'
tags = 'Familie;Erinnerung;Mama;Bruder;Danny;LaFamilia'
note = 'Erinnerungen vor Vergessen. Familie vor Entfernung. Liebe vor Stolz.'
}
)

$Memories | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $JsonPath -Encoding UTF8
$Memories | Export-Csv -LiteralPath $CsvPath -NoTypeInformation -Delimiter ';' -Encoding UTF8

$Cards = foreach ($m in $Memories) {
$tagItems = @([string]$m.tags -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$tagHtml = ($tagItems | ForEach-Object { "<span class='tag'>$(H $_)</span>" }) -join ''
$noteHtml = (H $m.note) -replace "(`r`n|`n|`r)", '<br>'
@"
<article class="card">
<h3>$(H $m.title)</h3>
<p class="meta"><strong>ID:</strong> $(H $m.id) · <strong>Kategorie:</strong> $(H $m.category)</p>
<p><strong>Bedeutung:</strong> $(H $m.meaning)</p>
<p><strong>Notiz:</strong> $noteHtml</p>
<div class="tags">$tagHtml</div>
</article>
"@
}

$centerX = 350
$centerY = 220
$radius = 170
$nodeCount = if ($Memories.Count -gt 0) { $Memories.Count } else { 1 }
$mindLines = @()
$mindNodes = @()

for ($i = 0; $i -lt $Memories.Count; $i++) {
$angle = (2 * [Math]::PI * $i) / $nodeCount
$x = [Math]::Round($centerX + ($radius * [Math]::Cos($angle)), 2)
$y = [Math]::Round($centerY + ($radius * [Math]::Sin($angle)), 2)
$mindLines += "<line x1='$centerX' y1='$centerY' x2='$x' y2='$y' stroke='rgba(34,197,94,.5)' stroke-width='1.8'/>"
$mindNodes += "<circle cx='$x' cy='$y' r='9' fill='#22c55e'/>"
$mindNodes += "<text x='$($x + 12)' y='$($y + 4)' class='map-label'>$(H $Memories[$i].title)</text>"
}

$MindmapSvg = @"
<svg viewBox="0 0 700 440" role="img" aria-label="Symbolische Mindmap">
$($mindLines -join "`n`t")
<circle cx="$centerX" cy="$centerY" r="42" fill="#0f172a" stroke="#22c55e" stroke-width="2"/>
<text x="$centerX" y="$($centerY + 5)" text-anchor="middle" class="map-center">AVA Core</text>
$($mindNodes -join "`n`t")
</svg>
"@

$Html = @"
<!doctype html>
<html lang="de">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>AVA SYMBOLIC MEMORY PORTAL</title>
<style>
:root {
color-scheme: dark;
--bg: #020617;
--card: #0f172a;
--line: #1e293b;
--text: #e2e8f0;
--muted: #94a3b8;
--accent: #22c55e;
}
* { box-sizing: border-box; }
body {
margin: 0;
padding: 26px;
font-family: Segoe UI, Roboto, Arial, sans-serif;
background: radial-gradient(circle at top, #0f172a, var(--bg) 68%);
color: var(--text);
line-height: 1.45;
}
h1 { margin: 0 0 6px; font-size: 30px; }
.subtitle { margin: 0 0 14px; color: var(--muted); }
.banner {
margin: 0 0 20px;
padding: 12px 14px;
border: 1px solid var(--line);
border-radius: 12px;
background: rgba(2, 6, 23, .7);
}
.stats {
display: grid;
grid-template-columns: repeat(auto-fit, minmax(180px, 1fr));
gap: 10px;
margin-bottom: 18px;
}
.stat {
background: var(--card);
border: 1px solid var(--line);
border-radius: 10px;
padding: 10px 12px;
}
.stat .k { color: var(--muted); font-size: 12px; }
.stat .v { color: var(--accent); font-size: 22px; font-weight: 700; }
.section-title { margin: 20px 0 10px; }
.grid {
display: grid;
grid-template-columns: repeat(auto-fit, minmax(320px, 1fr));
gap: 12px;
}
.card {
background: var(--card);
border: 1px solid var(--line);
border-radius: 12px;
padding: 12px;
}
.card h3 { margin: 0 0 8px; }
.meta { margin: 0 0 10px; color: var(--muted); font-size: 13px; }
.tags { display: flex; flex-wrap: wrap; gap: 6px; margin-top: 10px; }
.tag {
display: inline-block;
padding: 3px 8px;
border-radius: 999px;
font-size: 12px;
border: 1px solid rgba(34, 197, 94, .35);
background: rgba(34, 197, 94, .14);
color: #bbf7d0;
}
.mindmap {
background: var(--card);
border: 1px solid var(--line);
border-radius: 12px;
padding: 10px;
overflow: auto;
}
.map-center {
fill: #86efac;
font-size: 14px;
font-weight: 700;
}
.map-label {
fill: #cbd5e1;
font-size: 11px;
}
footer {
margin-top: 18px;
font-size: 12px;
color: var(--muted);
}
</style>
</head>
<body>
<h1>AVA SYMBOLIC MEMORY PORTAL</h1>
<p class="subtitle">Lokal / Privat / Read-Only / Kein Upload / Keine Überwachung</p>
<div class="banner">
<strong>Systemstatus:</strong> Lokal gespeichert, ohne Cloud und ohne Upload.<br>
<strong>Pfad:</strong> $(H $Root)
</div>
<section class="stats">
<div class="stat"><div class="k">Einträge</div><div class="v">$($Memories.Count)</div></div>
<div class="stat"><div class="k">JSON</div><div class="v">symbolic_memory.json</div></div>
<div class="stat"><div class="k">CSV</div><div class="v">symbolic_memory.csv</div></div>
<div class="stat"><div class="k">Portal</div><div class="v">index.html</div></div>
</section>
<h2 class="section-title">Symbolische Einträge</h2>
<section class="grid">
$($Cards -join "`n")
</section>
<h2 class="section-title">Symbolische Mindmap</h2>
<section class="mindmap">
$MindmapSvg
</section>
<footer>
JSON: $(H $JsonPath)<br>
CSV: $(H $CsvPath)<br>
Portal: $(H $HtmlPath)
</footer>
</body>
</html>
"@

$Html | Set-Content -LiteralPath $HtmlPath -Encoding UTF8

Write-Host ''
Write-Host 'AVA SYMBOLIC MEMORY PORTAL erstellt.' -ForegroundColor Green
Write-Host "Ordner: $Root" -ForegroundColor Cyan
Write-Host "JSON:   $JsonPath" -ForegroundColor Cyan
Write-Host "CSV:    $CsvPath" -ForegroundColor Cyan
Write-Host "Portal: $HtmlPath" -ForegroundColor Cyan
Write-Host ''

Start-Process $HtmlPath
