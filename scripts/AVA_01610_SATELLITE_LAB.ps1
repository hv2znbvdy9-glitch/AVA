#requires -Version 5.1
<#
AVA 01610 SATELLITENLABOR
Lokal / Defensiv / Simulation

Ein sicheres Simulationsmodell fuer das lokale AVA-01610-Satellitenlabor.
Keine echten Angriffe, Exploits, Netzwerkzugriffe oder Aenderungen an der
Windows-Sicherheitskonfiguration. Optional werden lokale Berichte geschrieben.
#>

[CmdletBinding()]
param(
	[string]$OutputDirectory,
	[switch]$NoReportFiles
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Pfade fuer Protokolle und Berichte festlegen
if ([string]::IsNullOrWhiteSpace($OutputDirectory)) {
	$DesktopPath = [Environment]::GetFolderPath('Desktop')
	if ([string]::IsNullOrWhiteSpace($DesktopPath)) {
		$DesktopPath = $PWD.Path
	}
	$OutputDirectory = Join-Path $DesktopPath 'AVA_01610_SATELLITE_LAB'
}
$OutputRoot = [System.IO.Path]::GetFullPath($OutputDirectory)
$LogDir = Join-Path $OutputRoot 'Logs'
$ReportDir = Join-Path $OutputRoot 'Reports'

function Ensure-Dir {
	param([string]$Path)
	if (-not (Test-Path -LiteralPath $Path)) {
		New-Item -ItemType Directory -Force -Path $Path | Out-Null
	}
}

function Ensure-AllDirs {
	foreach ($d in @($OutputRoot, $LogDir, $ReportDir)) {
		Ensure-Dir $d
	}
}

# Kryptografische Hilfsfunktionen
function Get-SignedPayloadJson {
	param(
		[string]$Source,
		[string]$Target,
		[hashtable]$Command
	)
	# Source und Target gehoeren zum authentifizierten Datenbereich.
	[ordered]@{
		Version = 1
		Source  = $Source
		Target  = $Target
		Command = $Command
	} | ConvertTo-Json -Depth 10 -Compress
}

function Get-HmacSha256 {
	param(
		[string]$Text,
		[byte[]]$Key
	)
	$textBytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
	$hmac = [System.Security.Cryptography.HMACSHA256]::new($Key)
	try {
		return $hmac.ComputeHash($textBytes)
	} finally {
		$hmac.Dispose()
	}
}

function ConvertTo-Hex {
	param([byte[]]$Bytes)
	(($Bytes | ForEach-Object { $_.ToString('x2') }) -join '')
}

function Test-ByteArrayEquality {
	param(
		[byte[]]$Left,
		[byte[]]$Right
	)
	if ($Left.Length -ne $Right.Length) { return $false }
	[int]$Difference = 0
	for ($Index = 0; $Index -lt $Left.Length; $Index++) {
		$Difference = $Difference -bor ($Left[$Index] -bxor $Right[$Index])
	}
	return ($Difference -eq 0)
}

function ConvertFrom-Hex {
	param([string]$Hex)
	if ([string]::IsNullOrWhiteSpace($Hex) -or ($Hex.Length % 2) -ne 0) {
		return $null
	}
	try {
		$Bytes = [byte[]]::new($Hex.Length / 2)
		for ($Index = 0; $Index -lt $Bytes.Length; $Index++) {
			$Bytes[$Index] = [Convert]::ToByte($Hex.Substring($Index * 2, 2), 16)
		}
		return ,$Bytes
	} catch {
		return $null
	}
}

function New-RandomKey {
	[byte[]]$Key = [byte[]]::new(32)
	$Random = [System.Security.Cryptography.RandomNumberGenerator]::Create()
	try {
		$Random.GetBytes($Key)
	} finally {
		$Random.Dispose()
	}
	return ,$Key
}

function Sign-Command {
	param(
		[string]$Source,
		[string]$Target,
		[hashtable]$Command,
		[byte[]]$Key
	)
	$json = Get-SignedPayloadJson -Source $Source -Target $Target -Command $Command
	ConvertTo-Hex -Bytes (Get-HmacSha256 -Text $json -Key $Key)
}

function Verify-Command {
	param(
		[string]$Source,
		[string]$Target,
		[hashtable]$Command,
		[string]$Signature,
		[byte[]]$Key
	)
	$json = Get-SignedPayloadJson -Source $Source -Target $Target -Command $Command
	$expected = Get-HmacSha256 -Text $json -Key $Key
	$actual = ConvertFrom-Hex -Hex $Signature
	if ($null -eq $actual) { return $false }
	Test-ByteArrayEquality -Left $expected -Right $actual
}

# Zustand und Logging
$Events = [System.Collections.Generic.List[PSCustomObject]]::new()
$SeenNonces = @{}

function Log-Event {
	param(
		[string]$Component,
		[string]$Type,
		[string]$Severity,
		[string]$Message,
		[object]$Data
	)
	$evt = [pscustomobject]@{
		Timestamp = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
		Component = $Component
		Type      = $Type
		Severity  = $Severity
		Message   = $Message
		Data      = $Data
	}
	$Events.Add($evt)
	
	$color = 'White'
	if ($Severity -eq 'CRITICAL') { $color = 'Red' }
	elseif ($Severity -eq 'WARNING') { $color = 'Yellow' }
	elseif ($Severity -eq 'SUCCESS') { $color = 'Green' }
	elseif ($Severity -eq 'INFO') { $color = 'Cyan' }
	
	Write-Host "[$Component] [$Severity] $Message" -ForegroundColor $color
}

# Ephemere Demo-Schluessel: nur im Speicher und fuer jeden Lauf neu.
$SatKeyA = New-RandomKey
$SatKeyB = New-RandomKey
$SatKeyC = New-RandomKey

# Definition der Satelliten
$Satellites = @{
	'Satellit A' = @{
		Id = 'Sat-A'
		Orbit = 'LEO (Low Earth Orbit)'
		Altitude = 450
		Power = 100
		Status = 'Active'
		Key = $SatKeyA
		TelemetryHistory = [System.Collections.Generic.List[string]]::new()
	}
	'Satellit B' = @{
		Id = 'Sat-B'
		Orbit = 'MEO (Medium Earth Orbit)'
		Altitude = 20200
		Power = 100
		Status = 'Active'
		Key = $SatKeyB
		TelemetryHistory = [System.Collections.Generic.List[string]]::new()
	}
	'Satellit C' = @{
		Id = 'Sat-C'
		Orbit = 'GEO (Geostationary Orbit)'
		Altitude = 35786
		Power = 100
		Status = 'Active'
		Key = $SatKeyC
		TelemetryHistory = [System.Collections.Generic.List[string]]::new()
	}
}

# Definition der Bodenstation und Schluessel
$Bodenstation = @{
	Name = 'Mock-Bodenstation (01610)'
	Keys = @{
		'Satellit A' = $SatKeyA
		'Satellit B' = $SatKeyB
		'Satellit C' = $SatKeyC
	}
}

$AllowedActions = @('AdjustAltitude', 'ResetPower')

function Transmit-Message {
	param(
		[string]$Source,
		[string]$TargetSatellite,
		[hashtable]$Command,
		[string]$Signature
	)
	
	$Packet = @{
		Source = $Source
		Target = $TargetSatellite
		Command = $Command
		Signature = $Signature
	}
	
	Log-Event -Component 'Relais' -Type 'PACKET_FORWARD' -Severity 'INFO' -Message "Leite Paket von $Source fuer $TargetSatellite weiter." -Data $Packet
	Receive-Packet -SatelliteName $TargetSatellite -Packet $Packet
}

function Receive-Packet {
	param(
		[string]$SatelliteName,
		[hashtable]$Packet
	)
	
	$sat = $Satellites[$SatelliteName]
	if ($null -eq $sat) {
		Log-Event -Component 'System' -Type 'UNKNOWN_TARGET' -Severity 'WARNING' -Message "Paket fuer unbekannten Satelliten '$SatelliteName' verworfen." -Data $Packet
		return
	}
	
	$cmd = $Packet.Command
	$sig = $Packet.Signature
	$source = $Packet.Source
	
	$isValid = Verify-Command -Source $source -Target $SatelliteName -Command $cmd -Signature $sig -Key $sat.Key
	
	if ($isValid) {
		$nonceKey = [string]$cmd.Nonce
		if (-not $SeenNonces.ContainsKey($SatelliteName)) {
			$SeenNonces[$SatelliteName] = [System.Collections.Generic.HashSet[string]]::new()
		}
		if (-not $SeenNonces[$SatelliteName].Add($nonceKey)) {
			Log-Event -Component $SatelliteName -Type 'REPLAY_REJECTED' -Severity 'CRITICAL' -Message "Replay erkannt: Nonce '$nonceKey' wurde bereits verwendet. Befehl VERWORFEN." -Data $Packet
			$sat.TelemetryHistory.Add("VERWORFEN: Replay mit Nonce '$nonceKey'.")
			return
		}
		$action = $cmd.Action
		$params = $cmd.Params
		
		Log-Event -Component $SatelliteName -Type 'AUTH_SUCCESS' -Severity 'SUCCESS' -Message "Authentifizierung ERFOLGREICH fuer '$action' von '$source'." -Data $Packet
		if ($AllowedActions -notcontains $action) {
			Log-Event -Component $SatelliteName -Type 'COMMAND_REJECTED' -Severity 'WARNING' -Message "Nicht freigegebene Aktion '$action' wurde trotz gueltiger Signatur verworfen." -Data $Packet
			$sat.TelemetryHistory.Add("VERWORFEN: Nicht freigegebene Aktion '$action'.")
			return
		}
		
		if ($action -eq 'AdjustAltitude') {
			$sat.Altitude = $params.Altitude
			$sat.TelemetryHistory.Add("Hoehe auf $($params.Altitude) km angepasst.")
		} elseif ($action -eq 'ResetPower') {
			$sat.Power = 100
			$sat.TelemetryHistory.Add('Energieversorgung zurueckgesetzt.')
		}
	} else {
		Log-Event -Component $SatelliteName -Type 'AUTH_FAILURE' -Severity 'CRITICAL' -Message "CRITICAL AUTH FAILURE: Ungueltige Signatur fuer '$($cmd.Action)' von '$source'! Befehl VERWORFEN." -Data $Packet
		$sat.TelemetryHistory.Add("VERWORFEN: Unautorisierter Befehl '$($cmd.Action)' von '$source'!")
	}
}

function Build-HtmlReport {
	$rows = foreach ($e in $Events) {
		$sevClass = "sev-$($e.Severity)"
		"<tr>
			<td>$($e.Timestamp)</td>
			<td><strong>$($e.Component)</strong></td>
			<td><span class='badge $sevClass'>$($e.Severity)</span></td>
			<td><code>$($e.Type)</code></td>
			<td>$($e.Message)</td>
		</tr>"
	}
	
	$rowsHtml = $rows -join "`n"
	
	$satCards = foreach ($name in $Satellites.Keys | Sort-Object) {
		$sat = $Satellites[$name]
		$hist = ($sat.TelemetryHistory | ForEach-Object { "<li>$_</li>" }) -join ""
		if (-not $hist) { $hist = "<li>Keine Ereignisse</li>" }
		"
		<div class='card sat-card'>
			<h3>$name ($($sat.Id))</h3>
			<p><strong>Orbit:</strong> $($sat.Orbit)</p>
			<p><strong>Hoehe:</strong> $($sat.Altitude) km</p>
			<p><strong>Energie:</strong> $($sat.Power)%</p>
			<p><strong>Status:</strong> <span class='status-$($sat.Status)'>$($sat.Status)</span></p>
			<p><strong>Schluessel:</strong> <code>GESCHUETZT - nicht im Bericht gespeichert</code></p>
			<h4>Ereignis-Historie:</h4>
			<ul>$hist</ul>
		</div>
		"
	}
	$satCardsHtml = $satCards -join "`n"

	$html = @"
<!doctype html>
<html lang="de">
<head>
<meta charset="utf-8">
<title>AVA 01610 SATELLITENLABOR REPORT</title>
<style>
body {
	font-family: Consolas, "Segoe UI", monospace;
	background: #05080c;
	color: #eaf6ff;
	padding: 30px;
}
.header {
	background: #0c1520dd;
	border: 1px solid #17384f;
	padding: 20px;
	margin-bottom: 20px;
	border-radius: 4px;
}
.big-title {
	font-size: 24px;
	color: #22a7ff;
	margin: 0 0 10px 0;
	text-transform: uppercase;
}
.sub-title {
	font-size: 14px;
	color: #8fa3ad;
}
.grid {
	display: grid;
	grid-template-columns: repeat(auto-fit, minmax(300px, 1fr));
	gap: 20px;
	margin-bottom: 20px;
}
.card {
	background: #0c1520dd;
	border: 1px solid #17384f;
	padding: 16px;
	border-radius: 4px;
}
.sat-card h3 {
	color: #22a7ff;
	margin-top: 0;
}
.status-Active { color: #19ff8f; font-weight: bold; }
.status-Deorbited { color: #ff5d6c; font-weight: bold; }
table {
	width: 100%;
	border-collapse: collapse;
	margin-top: 10px;
}
th, td {
	padding: 10px;
	border-bottom: 1px solid rgba(255, 255, 255, .08);
	text-align: left;
	vertical-align: top;
	font-size: 12px;
}
th {
	color: #22a7ff;
	background: rgba(34, 167, 255, 0.05);
}
.badge {
	padding: 2px 6px;
	border-radius: 3px;
	font-size: 10px;
	font-weight: bold;
	text-transform: uppercase;
}
.sev-INFO { background: #17384f; color: #22a7ff; }
.sev-SUCCESS { background: #0c3e21; color: #19ff8f; }
.sev-WARNING { background: #4d3a00; color: #ffcc66; }
.sev-CRITICAL { background: #4d1017; color: #ff5d6c; }
code {
	background: rgba(255,255,255,0.05);
	padding: 2px 4px;
	border-radius: 3px;
}
</style>
</head>
<body>
<div class="header">
	<div class="big-title">LOKALES AVA-01610-SATELLITENLABOR</div>
	<div class="sub-title">Wissenschaftliche Simulation: Manipulationsversuch ueber kompromittiertes Relais</div>
</div>

<div class="card" style="margin-bottom: 20px;">
	<h2>Architektur-Uebersicht</h2>
	<p>Dieses Labor simuliert eine Mock-Bodenstation, die kryptografisch signierte Steuerbefehle an drei Satelliten ueber ein Relais sendet.</p>
	<ul>
		<li><strong>Satellit A:</strong> Schuetzt sich mit seinem eigenen geheimen Schluessel.</li>
		<li><strong>Satellit B:</strong> Schuetzt sich mit einem anderen geheimen Schluessel.</li>
		<li><strong>Satellit C:</strong> Schuetzt sich mit einem anderen geheimen Schluessel.</li>
		<li><strong>Relais:</strong> Besitzt keine Schluessel, darf Befehle nur weiterleiten. Bei einer Kompromittierung des Relais werden gefaelschte Befehle gesendet, die von den Satelliten abgewiesen werden muessen.</li>
	</ul>
</div>

<div class="grid">
	$satCardsHtml
</div>

<div class="card">
	<h2>Ereignis-Protokoll (vollstaendig protokolliert)</h2>
	<table>
		<thead>
			<tr>
				<th>Zeitstempel</th>
				<th>Komponente</th>
				<th>Schweregrad</th>
				<th>Ereignistyp</th>
				<th>Meldung</th>
			</tr>
		</thead>
		<tbody>
			$rowsHtml
		</tbody>
	</table>
</div>
</body>
</html>
"@
	return $html
}

# Ausfuehrung der Simulation
function Start-Simulation {
	if (-not $NoReportFiles) {
		Ensure-AllDirs
	}
	
	Write-Host '==================================================' -ForegroundColor Green
	Write-Host '   AVA-01610 LOKALES SATELLITENLABOR SIMULATION   ' -ForegroundColor Green
	Write-Host '==================================================' -ForegroundColor Green
	Write-Host ''
	
	Log-Event -Component 'System' -Type 'SIM_START' -Severity 'INFO' -Message 'Simulationsumgebung fuer Satellitenlabor gestartet.' -Data @{}
	
	# 1. Legitime Befehle der Bodenstation
	Write-Host '--- Phase 1: Legitime Befehle der Bodenstation ---' -ForegroundColor Yellow
	
	$cmdA = @{ Action = 'AdjustAltitude'; Params = @{ Altitude = 455 }; Nonce = 10001 }
	$sigA = Sign-Command -Source $Bodenstation.Name -Target 'Satellit A' -Command $cmdA -Key $Bodenstation['Keys']['Satellit A']
	Transmit-Message -Source $Bodenstation.Name -TargetSatellite 'Satellit A' -Command $cmdA -Signature $sigA
	
	$cmdB = @{ Action = 'AdjustAltitude'; Params = @{ Altitude = 20210 }; Nonce = 10002 }
	$sigB = Sign-Command -Source $Bodenstation.Name -Target 'Satellit B' -Command $cmdB -Key $Bodenstation['Keys']['Satellit B']
	Transmit-Message -Source $Bodenstation.Name -TargetSatellite 'Satellit B' -Command $cmdB -Signature $sigB

	# Derselbe gueltig signierte Befehl muss beim zweiten Empfang abgewiesen werden.
	Transmit-Message -Source $Bodenstation.Name -TargetSatellite 'Satellit A' -Command $cmdA -Signature $sigA
	
	Write-Host ''
	
	# 2. Kompromittierung des Relais
	Write-Host '--- Phase 2: Relais kompromittiert, Manipulationsversuche ---' -ForegroundColor Yellow
	Log-Event -Component 'Relais' -Type 'RELAIS_COMPROMISED' -Severity 'WARNING' -Message 'Ereignis: Relais kompromittiert! Angreifer sendet gefaelschte Befehle.' -Data @{}
	
	# Das kompromittierte Relais versucht, gefaelschte Kommandos einzuschleusen
	$fakeCmdA = @{ Action = 'Deorbit'; Params = @{ Altitude = 0 }; Nonce = 99999 }
	$fakeSigA = 'INVALID_SIGNATURE_FAKE_KEY_A_99999'
	Transmit-Message -Source 'Relais (Kompromittiert)' -TargetSatellite 'Satellit A' -Command $fakeCmdA -Signature $fakeSigA
	
	$fakeCmdC = @{ Action = 'ResetPower'; Params = @{}; Nonce = 99998 }
	$fakeSigC = 'INVALID_SIGNATURE_FAKE_KEY_C_99998'
	Transmit-Message -Source 'Relais (Kompromittiert)' -TargetSatellite 'Satellit C' -Command $fakeCmdC -Signature $fakeSigC
	
	Write-Host ''
	
	# 3. Berichterstellung und Protokollierung
	Write-Host '--- Phase 3: Protokollierung & Berichterstellung ---' -ForegroundColor Yellow
	
	$JsonPath = Join-Path $ReportDir 'ava_satellite_lab_log.json'
	$TxtPath = Join-Path $ReportDir 'ava_satellite_lab_log.txt'
	$HtmlPath = Join-Path $ReportDir 'ava_satellite_lab_report.html'
	
	# Abschlussereignis vor dem Export erfassen, damit alle Ausgaben vollstaendig sind.
	Log-Event -Component 'System' -Type 'SIM_COMPLETE' -Severity 'INFO' -Message "Simulation beendet." -Data @{
		Json = $JsonPath
		Txt = $TxtPath
		Html = $HtmlPath
	}
	if ($NoReportFiles) {
		return
	}

	# JSON Protokoll speichern
	$Events | ConvertTo-Json -Depth 10 | Out-File -FilePath $JsonPath -Encoding UTF8
	
	# Text Protokoll speichern
	$txtSummary = New-Object System.Text.StringBuilder
	$txtSummary.AppendLine('==================================================') | Out-Null
	$txtSummary.AppendLine('   AVA-01610 LOKALES SATELLITENLABOR PROTOKOLL   ') | Out-Null
	$txtSummary.AppendLine('==================================================') | Out-Null
	$txtSummary.AppendLine("Generiert am: $(Get-Date)") | Out-Null
	$txtSummary.AppendLine("Pfad: $OutputRoot") | Out-Null
	$txtSummary.AppendLine() | Out-Null
	foreach ($e in $Events) {
		$txtSummary.AppendLine("[$($e.Timestamp)] [$($e.Component)] [$($e.Severity)] [$($e.Type)] $($e.Message)") | Out-Null
	}
	$txtSummary.ToString() | Out-File -FilePath $TxtPath -Encoding UTF8
	
	# HTML-Bericht speichern
	$html = Build-HtmlReport
	$html | Out-File -FilePath $HtmlPath -Encoding UTF8

}

Start-Simulation
