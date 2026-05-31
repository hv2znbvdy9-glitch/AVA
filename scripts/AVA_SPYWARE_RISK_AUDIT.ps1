#requires -Version 5.1
<#
AVA SPYWARE RISK AUDIT
Lokal / Defensiv / Read-Only

Keine Angriffe
Keine Änderungen
Keine Fremdscans
Keine Bereinigung
Nur Sichtbarkeit + Report
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

$Now = Get-Date -Format 'yyyyMMdd_HHmmss'
$Root = Join-Path $env:USERPROFILE "Desktop\AVA_SPYWARE_RISK_AUDIT_$Now"
$LogDir = Join-Path $Root 'Logs'
$ReportDir = Join-Path $Root 'Reports'
$StateDir = Join-Path $Root 'State'

$HtmlReport = Join-Path $ReportDir 'ava_spyware_risk_audit.html'
$JsonReport = Join-Path $ReportDir 'ava_spyware_risk_audit.json'
$TxtReport = Join-Path $ReportDir 'ava_spyware_risk_audit.txt'
$TangleLog = Join-Path $LogDir 'ava_tangle.jsonl'
$TangleState = Join-Path $StateDir 'tangle_state.json'

foreach ($d in @($Root, $LogDir, $ReportDir, $StateDir)) {
	New-Item -ItemType Directory -Force -Path $d | Out-Null
}

$Findings = New-Object System.Collections.Generic.List[object]

function H {
	param([AllowNull()][object]$Value)
	if ($null -eq $Value) { return '' }
	return [System.Net.WebUtility]::HtmlEncode([string]$Value)
}

function Sha256Text {
	param([string]$Text)

	$sha = [System.Security.Cryptography.SHA256]::Create()
	$bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
	return (($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join '')
}

function Add-Finding {
	param(
		[string]$Category,
		[string]$Severity,
		[string]$Title,
		[string]$Message,
		[string]$Recommendation
	)

	$Findings.Add([pscustomobject]@{
			Time           = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
			Category       = $Category
			Severity       = $Severity
			Title          = $Title
			Message        = $Message
			Recommendation = $Recommendation
		}) | Out-Null
}

function Write-Tangle {
	param([string]$Type, [string]$Summary, [object]$Data)

	$prev = $null
	if (Test-Path $TangleState) {
		try { $prev = (Get-Content $TangleState -Raw | ConvertFrom-Json).last_hash } catch {}
	}

	$event = [ordered]@{
		time          = (Get-Date).ToString('o')
		computer      = $env:COMPUTERNAME
		user          = $env:USERNAME
		type          = $Type
		summary       = $Summary
		previous_hash = $prev
		data          = $Data
	}

	$raw = $event | ConvertTo-Json -Depth 20 -Compress
	$hash = Sha256Text $raw
	$event['hash'] = $hash

	$event | ConvertTo-Json -Depth 20 -Compress | Add-Content -Path $TangleLog -Encoding UTF8

	[pscustomobject]@{
		updated   = (Get-Date).ToString('o')
		last_hash = $hash
	} | ConvertTo-Json | Set-Content -Path $TangleState -Encoding UTF8
}

Write-Host ''
Write-Host 'AVA SPYWARE RISK AUDIT startet...' -ForegroundColor Cyan
Write-Host 'Read-Only / Lokal / Keine Änderungen' -ForegroundColor Green
Write-Host ''

# SYSTEM
try {
	$os = Get-CimInstance Win32_OperatingSystem
	Add-Finding 'System' 'INFO' 'Betriebssystem' "$($os.Caption) | Build $($os.BuildNumber)" 'Windows aktuell halten.'
} catch {
	Add-Finding 'System' 'WARN' 'Betriebssystem' $_.Exception.Message 'Systeminformationen prüfen.'
}

# DEFENDER
try {
	$mp = Get-MpComputerStatus
	if ($mp.RealTimeProtectionEnabled) {
		Add-Finding 'Defender' 'OK' 'Echtzeitschutz' 'Aktiv' 'Sehr gut.'
	}
	else {
		Add-Finding 'Defender' 'CRITICAL' 'Echtzeitschutz' 'Nicht aktiv' 'Windows-Sicherheit sofort prüfen.'
	}

	Add-Finding 'Defender' 'INFO' 'Signaturen' "Letztes Update: $($mp.AntivirusSignatureLastUpdated)" 'Signaturen aktuell halten.'
} catch {
	Add-Finding 'Defender' 'WARN' 'Defender Status' $_.Exception.Message 'Manuell in Windows-Sicherheit prüfen.'
}

# FIREWALL
try {
	Get-NetFirewallProfile | ForEach-Object {
		if ($_.Enabled) {
			Add-Finding 'Firewall' 'OK' "Firewall $($_.Name)" 'Aktiv' 'Sehr gut.'
		}
		else {
			Add-Finding 'Firewall' 'CRITICAL' "Firewall $($_.Name)" 'Deaktiviert' 'Firewall aktivieren.'
		}
	}
} catch {
	Add-Finding 'Firewall' 'WARN' 'Firewall' $_.Exception.Message 'Firewall prüfen.'
}

# ADMINS
try {
	$admins = Get-LocalGroupMember Administrators
	foreach ($a in $admins) {
		Add-Finding 'Konten' 'INFO' 'Lokaler Administrator' "$($a.Name)" 'Nur notwendige Adminrechte behalten.'
	}

	if ($admins.Count -gt 3) {
		Add-Finding 'Konten' 'WARN' 'Viele Administratoren' "$($admins.Count) Admin-Konten gefunden" 'Adminrechte minimieren.'
	}
} catch {
	Add-Finding 'Konten' 'WARN' 'Administratoren' $_.Exception.Message 'Mit Adminrechten erneut prüfen.'
}

# PROCESSES
$SuspiciousProcessPatterns = @(
	'powershell -enc',
	'encodedcommand',
	'downloadstring',
	'invoke-expression',
	'iex ',
	'mshta',
	'rundll32',
	'regsvr32',
	'certutil',
	'bitsadmin',
	'anydesk',
	'teamviewer',
	'rustdesk',
	'remotedesktop',
	'vnc'
)

try {
	$processes = Get-CimInstance Win32_Process | Select-Object ProcessId, Name, ExecutablePath, CommandLine

	foreach ($p in $processes) {
		$cmd = "$($p.Name) $($p.CommandLine)".ToLowerInvariant()
		$hits = @()

		foreach ($pattern in $SuspiciousProcessPatterns) {
			if ($cmd.Contains($pattern)) { $hits += $pattern }
		}

		if ($hits.Count -gt 0) {
			Add-Finding 'Prozesse' 'WARN' 'Auffälliger Prozess-Hinweis' "PID $($p.ProcessId) | $($p.Name) | Treffer: $($hits -join ', ')" 'Nicht automatisch löschen. Erst prüfen, ob legitim.'
		}
	}
} catch {
	Add-Finding 'Prozesse' 'WARN' 'Prozessanalyse' $_.Exception.Message 'Prozesse manuell prüfen.'
}

# NETWORK CONNECTIONS
$RiskPorts = @(21, 23, 135, 139, 445, 3389, 5985, 5986)

try {
	$procMap = @{}
	Get-Process | ForEach-Object { $procMap[$_.Id] = $_.ProcessName }

	$connections = Get-NetTCPConnection -State Established
	Add-Finding 'Netzwerk' 'INFO' 'Aktive TCP-Verbindungen' "$($connections.Count) Verbindungen" 'Unbekannte Remote-Ziele prüfen.'

	foreach ($c in $connections) {
		if ($RiskPorts -contains $c.RemotePort) {
			$procName = $procMap[$c.OwningProcess]
			Add-Finding 'Netzwerk' 'WARN' 'Risiko-Port Verbindung' "$($c.RemoteAddress):$($c.RemotePort) durch $procName / PID $($c.OwningProcess)" 'Prüfen, ob diese Verbindung erwartet ist.'
		}
	}
} catch {
	Add-Finding 'Netzwerk' 'WARN' 'TCP-Verbindungen' $_.Exception.Message 'Netzwerk manuell prüfen.'
}

# WLAN / LAN NEIGHBORS
try {
	$neighbors = Get-NetNeighbor -AddressFamily IPv4 | Where-Object { $_.State -ne 'Unreachable' }
	Add-Finding 'Netzwerk' 'INFO' 'LAN-Nachbarn / ARP' "$($neighbors.Count) lokale Nachbarn gefunden" 'Unbekannte MAC/IP-Adressen im Router gegenprüfen.'
} catch {}

try {
	$adapters = Get-NetAdapter
	foreach ($a in $adapters) {
		Add-Finding 'Adapter' 'INFO' 'Netzwerkadapter' "$($a.Name) | $($a.Status) | $($a.MacAddress) | $($a.LinkSpeed)" 'Unbekannte Adapter prüfen.'
	}
} catch {}

# MOBILE / SPYWARE RELATED FILE CHECKS
$ScanDirs = @(
	(Join-Path $env:USERPROFILE 'Downloads'),
	(Join-Path $env:USERPROFILE 'Desktop'),
	(Join-Path $env:USERPROFILE 'Documents')
)

$SuspiciousExtensions = @('*.apk', '*.ipa', '*.mobileconfig', '*.cer', '*.p12', '*.pfx')
$SuspiciousNames = @('spy', 'tracker', 'monitor', 'mdm', 'pegasus', 'stalker', 'stealth', 'keylog', 'remote', 'rat')

foreach ($dir in $ScanDirs) {
	if (Test-Path $dir) {
		foreach ($ext in $SuspiciousExtensions) {
			try {
				Get-ChildItem -Path $dir -Filter $ext -File -Recurse -ErrorAction SilentlyContinue |
					Select-Object -First 50 |
					ForEach-Object {
						Add-Finding 'Dateien' 'WARN' 'Mobile/Profil-Datei gefunden' "$($_.FullName)" 'Nur installieren/importieren, wenn Herkunft absolut vertrauenswürdig ist.'
					}
			} catch {}
		}

		try {
			Get-ChildItem -Path $dir -File -Recurse -ErrorAction SilentlyContinue |
				Where-Object {
					$n = $_.Name.ToLowerInvariant()
					foreach ($s in $SuspiciousNames) {
						if ($n.Contains($s)) { return $true }
					}
					return $false
				} |
				Select-Object -First 50 |
				ForEach-Object {
					Add-Finding 'Dateien' 'INFO' 'Dateiname mit Sicherheitsbezug' "$($_.FullName)" 'Kontext prüfen. Treffer ist nicht automatisch gefährlich.'
				}
		} catch {}
	}
}

# IPHONE BACKUP PATHS
$iPhoneBackupPaths = @(
	(Join-Path $env:APPDATA 'Apple Computer\MobileSync\Backup'),
	(Join-Path $env:USERPROFILE 'Apple\MobileSync\Backup')
)

foreach ($p in $iPhoneBackupPaths) {
	if (Test-Path $p) {
		Add-Finding 'Mobile' 'INFO' 'iPhone Backup Ordner gefunden' "$p" 'Backups verschlüsseln und sicher aufbewahren.'
	}
}

# HOSTS FILE
try {
	$hosts = "$env:SystemRoot\System32\drivers\etc\hosts"
	if (Test-Path $hosts) {
		$content = Get-Content $hosts -ErrorAction SilentlyContinue | Where-Object { $_ -and $_ -notmatch '^\s*#' }
		if ($content.Count -gt 0) {
			Add-Finding 'System' 'WARN' 'Hosts-Datei enthält aktive Einträge' "$($content.Count) aktive Zeilen" 'Prüfen, ob Umleitungen legitim sind.'
		}
		else {
			Add-Finding 'System' 'OK' 'Hosts-Datei' 'Keine aktiven Umleitungen gefunden' 'Gut.'
		}
	}
} catch {}

# SCORE
$critical = ($Findings | Where-Object Severity -eq 'CRITICAL').Count
$warn = ($Findings | Where-Object Severity -eq 'WARN').Count
$ok = ($Findings | Where-Object Severity -eq 'OK').Count
$info = ($Findings | Where-Object Severity -eq 'INFO').Count

$score = 100 - ($critical * 30) - ($warn * 7)
if ($score -lt 0) { $score = 0 }

$rating = switch ($score) {
	{ $_ -ge 90 } { 'Sehr stabil'; break }
	{ $_ -ge 70 } { 'Solide'; break }
	{ $_ -ge 50 } { 'Verbesserbar'; break }
	default { 'Prüfung empfohlen' }
}

Write-Tangle -Type 'AVA_SPYWARE_RISK_AUDIT' -Summary 'Read-Only Audit abgeschlossen' -Data @{
	score    = $score
	critical = $critical
	warn     = $warn
	info     = $info
	ok       = $ok
}

# EXPORT JSON
[pscustomobject]@{
	Tool     = 'AVA SPYWARE RISK AUDIT'
	Mode     = 'LOCAL / DEFENSIVE / READ-ONLY'
	Time     = (Get-Date).ToString('o')
	Computer = $env:COMPUTERNAME
	User     = $env:USERNAME
	Score    = $score
	Rating   = $rating
	Counts   = @{
		OK       = $ok
		INFO     = $info
		WARN     = $warn
		CRITICAL = $critical
	}
	Findings = $Findings
} | ConvertTo-Json -Depth 10 | Set-Content -Path $JsonReport -Encoding UTF8

# EXPORT TXT
$txt = @()
$txt += 'AVA SPYWARE RISK AUDIT'
$txt += "Zeit: $(Get-Date)"
$txt += "Computer: $env:COMPUTERNAME"
$txt += "User: $env:USERNAME"
$txt += ''
$txt += "Score: $score / 100"
$txt += "Bewertung: $rating"
$txt += ''
$txt += 'Kernsatz: Fakten vor Angst. Baseline vor Chaos. Sichtbarkeit vor Kontrolle.'
$txt += ''

foreach ($f in $Findings) {
	$txt += "[$($f.Severity)] $($f.Category) - $($f.Title)"
	$txt += "$($f.Message)"
	$txt += "Empfehlung: $($f.Recommendation)"
	$txt += ''
}

$txt -join "`r`n" | Set-Content -Path $TxtReport -Encoding UTF8

# HTML
$rows = foreach ($f in $Findings) {
	$color = switch ($f.Severity) {
		'OK' { '#15803d' }
		'INFO' { '#2563eb' }
		'WARN' { '#d97706' }
		'CRITICAL' { '#dc2626' }
		default { '#6b7280' }
	}

	@"
<tr>
<td><span style='color:$color;font-weight:700;'>$(H $f.Severity)</span></td>
<td>$(H $f.Category)</td>
<td>$(H $f.Title)</td>
<td>$(H $f.Message)</td>
<td>$(H $f.Recommendation)</td>
<td>$(H $f.Time)</td>
</tr>
"@
}

$summaryColor = if ($score -ge 90) { '#15803d' } elseif ($score -ge 70) { '#2563eb' } elseif ($score -ge 50) { '#d97706' } else { '#dc2626' }
$rowsHtml = if ($rows) { $rows -join "`n" } else { "<tr><td colspan='6'>Keine Findings vorhanden.</td></tr>" }

$html = @"
<!doctype html>
<html lang="de">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>AVA SPYWARE RISK AUDIT</title>
<style>
body{font-family:Segoe UI,Arial,sans-serif;background:#f8fafc;color:#0f172a;margin:0;padding:24px}
.card{background:#fff;border:1px solid #e2e8f0;border-radius:12px;padding:16px;margin-bottom:16px;box-shadow:0 1px 2px rgba(15,23,42,.06)}
.score{font-size:32px;font-weight:800;color:$summaryColor}
table{width:100%;border-collapse:collapse}
th,td{padding:10px;border-bottom:1px solid #e2e8f0;text-align:left;vertical-align:top;font-size:13px}
th{background:#f1f5f9}
.muted{color:#475569}
</style>
</head>
<body>
<div class="card">
  <h1 style="margin:0 0 8px 0;">AVA SPYWARE RISK AUDIT</h1>
  <div class="muted">LOCAL / DEFENSIVE / READ-ONLY</div>
  <div style="margin-top:12px;">Zeit: $(H ((Get-Date).ToString('yyyy-MM-dd HH:mm:ss')))</div>
  <div>Computer: $(H $env:COMPUTERNAME) · User: $(H $env:USERNAME)</div>
</div>

<div class="card">
  <div class="score">$score / 100</div>
  <div><b>Bewertung:</b> $(H $rating)</div>
  <div><b>Counts:</b> OK=$ok · INFO=$info · WARN=$warn · CRITICAL=$critical</div>
  <div class="muted" style="margin-top:8px;">Kernsatz: Fakten vor Angst. Baseline vor Chaos. Sichtbarkeit vor Kontrolle.</div>
</div>

<div class="card">
  <h2 style="margin-top:0;">Findings</h2>
  <table>
    <thead>
      <tr>
        <th>Severity</th>
        <th>Kategorie</th>
        <th>Titel</th>
        <th>Nachricht</th>
        <th>Empfehlung</th>
        <th>Zeit</th>
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

$html | Set-Content -Path $HtmlReport -Encoding UTF8

Write-Host ''
Write-Host 'AVA SPYWARE RISK AUDIT abgeschlossen.' -ForegroundColor Green
Write-Host "Score: $score / 100 - $rating" -ForegroundColor Yellow
Write-Host "HTML: $HtmlReport" -ForegroundColor Cyan
Write-Host "JSON: $JsonReport" -ForegroundColor Cyan
Write-Host "TXT:  $TxtReport" -ForegroundColor Cyan
Write-Host ''

Start-Process $HtmlReport
