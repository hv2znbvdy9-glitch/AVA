#requires -RunAsAdministrator
<#
AVA WLAN TANGLE SENSOR v1
Defensiv / Lokal / Read-Only

- Sichtbare WLANs via netsh
- Eigene Adapterdaten
- Eigene LAN-Nachbarn via ARP / NetNeighbor
- JSONL Logs
- Tangle Hash Chain
- HTML Portal
- Keine Angriffe
- Kein Monitor Mode
- Kein Deauth
- Kein Cracken
#>

[CmdletBinding()]
param(
	[switch]$RunOnce,
	[switch]$Loop,
	[switch]$InstallTask,
	[switch]$RemoveTask,
	[int]$IntervalSeconds = 60
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root = 'C:\Windows\SecurityGuardian'
$LogDir = Join-Path $Root 'Logs'
$StateDir = Join-Path $Root 'State'
$ReportDir = Join-Path $Root 'Reports'

$TaskName = 'AVA_WLAN_GUARDIAN_V1'
$ScriptPath = $PSCommandPath

$EventLog = Join-Path $LogDir 'wlan_events.jsonl'
$TangleLog = Join-Path $LogDir 'wlan_tangle.jsonl'
$TangleState = Join-Path $StateDir 'wlan_tangle_state.json'
$BaselinePath = Join-Path $StateDir 'wlan_baseline.json'
$PortalHtml = Join-Path $ReportDir 'ava_wlan_guardian_v1.html'
$SnapshotJson = Join-Path $ReportDir 'ava_wlan_snapshot_latest.json'
$AnalysisJson = Join-Path $ReportDir 'ava_wlan_analysis_latest.json'

function Ensure-Dirs {
	foreach ($d in @($Root, $LogDir, $StateDir, $ReportDir)) {
		if (-not (Test-Path -LiteralPath $d)) {
			New-Item -ItemType Directory -Path $d -Force | Out-Null
		}
	}
}

function HtmlEncode {
	param([AllowNull()][object]$Value)

	if ($null -eq $Value) {
		return ''
	}

	return [System.Net.WebUtility]::HtmlEncode([string]$Value)
}

function Sha256Text {
	param([Parameter(Mandatory)][string]$Text)

	$sha = [System.Security.Cryptography.SHA256]::Create()
	$bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
	return (($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString('x2') }) -join '')
}

function Write-JsonLine {
	param(
		[Parameter(Mandatory)][string]$Path,
		[Parameter(Mandatory)][object]$Object
	)

	$Object | ConvertTo-Json -Depth 30 -Compress | Add-Content -LiteralPath $Path -Encoding UTF8
}

function Write-Tangle {
	param(
		[Parameter(Mandatory)][string]$Type,
		[Parameter(Mandatory)][string]$Summary,
		[Parameter(Mandatory)][object]$Data
	)

	$prev = $null
	if (Test-Path -LiteralPath $TangleState) {
		try {
			$prev = (Get-Content -LiteralPath $TangleState -Raw | ConvertFrom-Json).last_hash
		} catch {
			$prev = $null
		}
	}

	$event = [ordered]@{
		time          = (Get-Date).ToString('o')
		host          = $env:COMPUTERNAME
		user          = $env:USERNAME
		type          = $Type
		summary       = $Summary
		previous_hash = $prev
		data          = $Data
	}

	$raw = $event | ConvertTo-Json -Depth 30 -Compress
	$hash = Sha256Text -Text $raw
	$event['hash'] = $hash

	Write-JsonLine -Path $TangleLog -Object $event

	[ordered]@{
		updated   = (Get-Date).ToString('o')
		last_hash = $hash
	} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $TangleState -Encoding UTF8
}

function Get-WlanNetworksSafe {
	try {
		$raw = netsh wlan show networks mode=bssid 2>&1 | Out-String
	} catch {
		return @([pscustomobject]@{ Error = $_.Exception.Message })
	}

	$items = New-Object System.Collections.Generic.List[object]
	$currentSsid = $null
	$currentAuth = $null
	$currentEncrypt = $null

	foreach ($line in ($raw -split "`r?`n")) {
		$l = $line.Trim()

		if ($l -match '^SSID\s+\d+\s+:\s+(.*)$') {
			$currentSsid = $Matches[1]
			$currentAuth = $null
			$currentEncrypt = $null
		}
		elseif ($l -match '^Authentication\s+:\s+(.*)$') {
			$currentAuth = $Matches[1]
		}
		elseif ($l -match '^Encryption\s+:\s+(.*)$') {
			$currentEncrypt = $Matches[1]
		}
		elseif ($l -match '^BSSID\s+\d+\s+:\s+(.*)$') {
			$items.Add([pscustomobject]@{
				SSID           = $currentSsid
				BSSID          = $Matches[1]
				Authentication = $currentAuth
				Encryption     = $currentEncrypt
				Signal         = $null
				RadioType      = $null
				Channel        = $null
			}) | Out-Null
		}
		elseif ($l -match '^Signal\s+:\s+(.*)$') {
			if ($items.Count -gt 0) {
				$items[$items.Count - 1].Signal = $Matches[1]
			}
		}
		elseif ($l -match '^Radio type\s+:\s+(.*)$') {
			if ($items.Count -gt 0) {
				$items[$items.Count - 1].RadioType = $Matches[1]
			}
		}
		elseif ($l -match '^Channel\s+:\s+(.*)$') {
			if ($items.Count -gt 0) {
				$items[$items.Count - 1].Channel = $Matches[1]
			}
		}
	}

	return $items
}

function Get-LocalNetworkSnapshot {
	$adapters = try {
		Get-NetAdapter |
			Select-Object Name, InterfaceDescription, Status, MacAddress, LinkSpeed
	} catch {
		@([pscustomobject]@{ Error = $_.Exception.Message })
	}

	$ipconfig = try {
		Get-NetIPConfiguration |
			Select-Object InterfaceAlias, IPv4Address, IPv6Address, IPv4DefaultGateway, DNSServer
	} catch {
		@([pscustomobject]@{ Error = $_.Exception.Message })
	}

	$neighbors = try {
		Get-NetNeighbor -AddressFamily IPv4 |
			Where-Object { $_.State -ne 'Unreachable' } |
			Select-Object InterfaceAlias, IPAddress, LinkLayerAddress, State
	} catch {
		@([pscustomobject]@{ Error = $_.Exception.Message })
	}

	return [ordered]@{
		adapters  = $adapters
		ipconfig  = $ipconfig
		neighbors = $neighbors
	}
}

function New-Snapshot {
	$network = Get-LocalNetworkSnapshot

	return [ordered]@{
		time     = (Get-Date).ToString('o')
		computer = $env:COMPUTERNAME
		user     = $env:USERNAME
		mode     = 'LOCAL_DEFENSIVE_READ_ONLY'
		network  = $network
		wlan     = Get-WlanNetworksSafe
	}
}

function Load-Baseline {
	if (Test-Path -LiteralPath $BaselinePath) {
		try {
			return Get-Content -LiteralPath $BaselinePath -Raw | ConvertFrom-Json
		} catch {
			return $null
		}
	}

	return $null
}

function Save-Baseline {
	param([Parameter(Mandatory)][object]$Snapshot)

	$Snapshot | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $BaselinePath -Encoding UTF8
}

function Add-Event {
	param(
		[Parameter(Mandatory)][string]$Severity,
		[Parameter(Mandatory)][string]$Title,
		[Parameter(Mandatory)][string]$Message,
		[int]$Score = 0,
		[AllowNull()][object]$Data
	)

	return [ordered]@{
		time     = (Get-Date).ToString('o')
		severity = $Severity
		title    = $Title
		message  = $Message
		score    = $Score
		data     = $Data
	}
}

function Analyze-Snapshot {
	param([Parameter(Mandatory)][object]$Snapshot)

	$events = New-Object System.Collections.Generic.List[object]
	$score = 0
	$baseline = Load-Baseline
	$delta = [ordered]@{
		baseline_exists = $null -ne $baseline
		new_wlan_bssid  = @()
		new_neighbors   = @()
		down_adapters   = @()
	}

	foreach ($adapter in @($Snapshot.network.adapters)) {
		if ($adapter.Status -and $adapter.Status -notin @('Up', 'Unknown')) {
			$score += 10
			$delta.down_adapters += $adapter
			$events.Add((Add-Event -Severity 'LOW' -Title 'Adapter nicht aktiv' -Message "Adapterstatus ist $($adapter.Status): $($adapter.Name)" -Score 10 -Data $adapter)) | Out-Null
		}
	}

	if ($null -eq $baseline) {
		Save-Baseline -Snapshot $Snapshot
	} else {
		$oldBssid = @($baseline.wlan | ForEach-Object { $_.BSSID })
		foreach ($w in @($Snapshot.wlan)) {
			if ($w.BSSID -and ($oldBssid -notcontains $w.BSSID)) {
				$delta.new_wlan_bssid += $w
				$score += 5
			}
		}

		$oldNeighbors = @($baseline.network.neighbors | ForEach-Object { "$($_.IPAddress)|$($_.LinkLayerAddress)" })
		foreach ($n in @($Snapshot.network.neighbors)) {
			$key = "$($n.IPAddress)|$($n.LinkLayerAddress)"
			if ($n.IPAddress -and ($oldNeighbors -notcontains $key)) {
				$delta.new_neighbors += $n
				$score += 5
			}
		}
	}

	if (@($delta.new_wlan_bssid).Count -gt 0) {
		$events.Add((Add-Event -Severity 'INFO' -Title 'Neue sichtbare BSSID' -Message 'Seit der Baseline wurden neue WLAN-BSSID sichtbar.' -Score (@($delta.new_wlan_bssid).Count * 5) -Data $delta.new_wlan_bssid)) | Out-Null
	}

	if (@($delta.new_neighbors).Count -gt 0) {
		$events.Add((Add-Event -Severity 'INFO' -Title 'Neue LAN-Nachbarn' -Message 'Seit der Baseline wurden neue LAN-Nachbarn erkannt.' -Score (@($delta.new_neighbors).Count * 5) -Data $delta.new_neighbors)) | Out-Null
	}

	return [ordered]@{
		time          = (Get-Date).ToString('o')
		score         = [Math]::Min($score, 999)
		event_count   = @($events).Count
		events        = $events
		delta         = $delta
		principles    = 'LOCAL / DEFENSIVE / READ-ONLY'
		core_sentence = 'Sichtbarkeit vor Aktion. Fakten vor Angst.'
	}
}

function Make-Rows {
	param(
		[AllowNull()][object[]]$Items,
		[Parameter(Mandatory)][string[]]$Props,
		[string]$EmptyText = 'Keine Daten gefunden.'
	)

	$rows = foreach ($item in @($Items)) {
		$tds = foreach ($p in $Props) {
			"<td>$(HtmlEncode $item.$p)</td>"
		}

		"<tr>$($tds -join '')</tr>"
	}

	if (-not $rows) {
		return "<tr><td colspan='$($Props.Count)' style='color:#8fa3ad;'>$(HtmlEncode $EmptyText)</td></tr>"
	}

	return $rows
}

function New-Portal {
	param(
		[Parameter(Mandatory)][object]$Snapshot,
		[Parameter(Mandatory)][object]$Analysis
	)

	$score = [int]$Analysis.score
	$health = 'OK'
	if ($score -ge 30) { $health = 'WARN' }
	if ($score -ge 80) { $health = 'HIGH' }

	$lastHash = 'N/A'
	if (Test-Path -LiteralPath $TangleState) {
		try {
			$lastHash = (Get-Content -LiteralPath $TangleState -Raw | ConvertFrom-Json).last_hash
		} catch {
			$lastHash = 'N/A'
		}
	}

	$eventRows = foreach ($event in @($Analysis.events | Select-Object -First 50)) {
		"<tr><td>$(HtmlEncode $event.severity)</td><td>$(HtmlEncode $event.title)</td><td>$(HtmlEncode $event.message)</td><td>$(HtmlEncode $event.score)</td><td>$(HtmlEncode $event.time)</td></tr>"
	}
	if (-not $eventRows) {
		$eventRows = "<tr><td colspan='5' style='color:#8fa3ad;'>Keine Ereignisse gefunden.</td></tr>"
	}

	$wlanRows = Make-Rows -Items (@($Snapshot.wlan) | Select-Object -First 100) -Props @('SSID', 'BSSID', 'Authentication', 'Encryption', 'Signal', 'RadioType', 'Channel')
	$adapterRows = Make-Rows -Items (@($Snapshot.network.adapters) | Select-Object -First 100) -Props @('Name', 'InterfaceDescription', 'Status', 'MacAddress', 'LinkSpeed')
	$ipRows = Make-Rows -Items (@($Snapshot.network.ipconfig) | Select-Object -First 100) -Props @('InterfaceAlias', 'IPv4Address', 'IPv6Address', 'IPv4DefaultGateway', 'DNSServer')
	$neighborRows = Make-Rows -Items (@($Snapshot.network.neighbors) | Select-Object -First 100) -Props @('InterfaceAlias', 'IPAddress', 'LinkLayerAddress', 'State')

@"
<!doctype html>
<html lang="de">
<head>
<meta charset="utf-8">
<meta http-equiv="refresh" content="60">
<title>AVA WLAN TANGLE SENSOR v1</title>
<style>
body{font-family:Consolas,"Segoe UI",monospace;background:#05080c;color:#eaf6ff;padding:30px}
.card{background:#0c1520dd;border:1px solid #17384f;padding:16px;margin:12px 0}
.big{font-size:30px;color:#22a7ff}
table{width:100%;border-collapse:collapse}
th,td{padding:8px;border-bottom:1px solid rgba(255,255,255,.08);text-align:left;vertical-align:top;font-size:12px}
th{color:#22a7ff}
.status-OK{color:#19ff8f}.status-WARN{color:#ffcc66}.status-HIGH{color:#ff5d6c}
.hash{word-break:break-all;color:#8fa3ad}
</style>
</head>
<body>
<div class="card"><b>AVA WLAN TANGLE SENSOR v1</b> · LOCAL / DEFENSIVE / READ-ONLY</div>
<div class="card"><div class="big status-$health">$health</div><div>Score: $score · Events: $($Analysis.event_count)</div></div>
<div class="card"><b>Kernsatz:</b> $(HtmlEncode $Analysis.core_sentence)</div>
<div class="card"><b>Tangle Last Hash:</b><div class="hash">$(HtmlEncode $lastHash)</div></div>
<div class="card"><h2>Ereignisse</h2><table><tbody><tr><th>Severity</th><th>Title</th><th>Message</th><th>Score</th><th>Time</th></tr>
$($eventRows -join "`n")
</tbody></table></div>
<div class="card"><h2>WLAN View</h2><table><tbody><tr><th>SSID</th><th>BSSID</th><th>Auth</th><th>Encryption</th><th>Signal</th><th>Radio</th><th>Channel</th></tr>
$($wlanRows -join "`n")
</tbody></table></div>
<div class="card"><h2>Adapter View</h2><table><tbody><tr><th>Name</th><th>Description</th><th>Status</th><th>MAC</th><th>LinkSpeed</th></tr>
$($adapterRows -join "`n")
</tbody></table></div>
<div class="card"><h2>IP Configuration</h2><table><tbody><tr><th>Interface</th><th>IPv4</th><th>IPv6</th><th>Gateway</th><th>DNS</th></tr>
$($ipRows -join "`n")
</tbody></table></div>
<div class="card"><h2>LAN Neighbors</h2><table><tbody><tr><th>Interface</th><th>IP</th><th>MAC</th><th>State</th></tr>
$($neighborRows -join "`n")
</tbody></table></div>
</body>
</html>
"@ | Set-Content -LiteralPath $PortalHtml -Encoding UTF8
}

function Invoke-AvaWlanGuardian {
	Ensure-Dirs

	$snapshot = New-Snapshot
	$analysis = Analyze-Snapshot -Snapshot $snapshot

	Write-JsonLine -Path $EventLog -Object $snapshot
	$snapshot | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $SnapshotJson -Encoding UTF8
	$analysis | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $AnalysisJson -Encoding UTF8

	Write-Tangle -Type 'AVA_WLAN_GUARDIAN_V1' -Summary 'Lokaler WLAN Snapshot erstellt' -Data ([ordered]@{
		time        = $snapshot.time
		computer    = $snapshot.computer
		user        = $snapshot.user
		score       = $analysis.score
		event_count = $analysis.event_count
		mode        = $snapshot.mode
	})

	New-Portal -Snapshot $snapshot -Analysis $analysis

	Write-Host 'AVA WLAN TANGLE SENSOR abgeschlossen.' -ForegroundColor Green
	Write-Host "Score:  $($analysis.score)" -ForegroundColor Yellow
	Write-Host "Events: $($analysis.event_count)" -ForegroundColor Yellow
	Write-Host "Portal: $PortalHtml" -ForegroundColor Cyan
}

function Install-AvaTask {
	if (-not $ScriptPath) {
		throw 'PSCommandPath ist leer. Script als .ps1 speichern und mit -File ausführen.'
	}

	Ensure-Dirs
	$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`" -RunOnce"
	$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1)
	$trigger.Repetition = New-ScheduledTaskRepetitionSettings -Interval (New-TimeSpan -Seconds $IntervalSeconds)
	$principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -RunLevel Highest

	Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Force | Out-Null
	Write-Host "Task installiert: $TaskName" -ForegroundColor Green
}

function Remove-AvaTask {
	if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
		Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
		Write-Host "Task entfernt: $TaskName" -ForegroundColor Yellow
	}
}

if ($RemoveTask) {
	Remove-AvaTask
	exit
}

if ($InstallTask) {
	Install-AvaTask
	exit
}

if ($Loop) {
	while ($true) {
		Invoke-AvaWlanGuardian
		Start-Sleep -Seconds $IntervalSeconds
	}
}
else {
	Invoke-AvaWlanGuardian
}

if ($RunOnce -and (Test-Path -LiteralPath $PortalHtml)) {
	Start-Process $PortalHtml
}
