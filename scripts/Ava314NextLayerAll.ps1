#requires -RunAsAdministrator
<#
AVA 3.14 NEXT LAYER — ALL
UNIFIED LOCAL DEFENSIVE VISIBILITY SYSTEM

Defensiv / Lokal / Read-Only
- Kein Angriff
- Kein Exploit
- Kein Fremdscan
- Kein Deauth
- Kein Cracken
- Kein Payload
- Keine offensive Automatisierung
#>

[CmdletBinding()]
param(
	[switch]$RunOnce,
	[switch]$Loop,
	[switch]$InstallTask,
	[switch]$RemoveTask,
	[switch]$ResetBaseline,
	[int]$IntervalSeconds = 60
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root = 'C:\Windows\SecurityGuardian'
$LogDir = Join-Path $Root 'Logs'
$StateDir = Join-Path $Root 'State'
$ReportDir = Join-Path $Root 'Reports'
$PortalDir = Join-Path $Root 'Portal'

$TaskName = 'AVA_3_14_NEXT_LAYER_ALL'
$ScriptPath = $PSCommandPath

$EventLog = Join-Path $LogDir 'ava_3_14_events.jsonl'
$AlertLog = Join-Path $LogDir 'ava_3_14_alerts.jsonl'
$TangleLog = Join-Path $LogDir 'ava_3_14_tangle.jsonl'
$TangleState = Join-Path $StateDir 'ava_3_14_tangle_state.json'
$BaselinePath = Join-Path $StateDir 'ava_3_14_baseline.json'
$PortalHtml = Join-Path $PortalDir 'index.html'
$SnapshotJson = Join-Path $ReportDir 'ava_3_14_latest_snapshot.json'
$AnalysisJson = Join-Path $ReportDir 'ava_3_14_latest_analysis.json'

$RiskPorts = @(21, 23, 135, 139, 445, 3389, 5985, 5986)
$SuspiciousCmdPatterns = @(
	'-enc',
	'encodedcommand',
	'downloadstring',
	'invoke-expression',
	'iex ',
	'-nop',
	'noprofile',
	'-w hidden',
	'windowstyle hidden',
	'executionpolicy bypass',
	'-ep bypass',
	'frombase64string',
	'bitsadmin',
	'certutil',
	'mshta'
)

function Ensure-Dirs {
	foreach ($d in @($Root, $LogDir, $StateDir, $ReportDir, $PortalDir)) {
		if (-not (Test-Path -LiteralPath $d)) {
			New-Item -ItemType Directory -Path $d -Force | Out-Null
		}
	}
}

function HtmlEncode {
	param([AllowNull()][object]$Value)
	if ($null -eq $Value) { return '' }
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

	$Object | ConvertTo-Json -Depth 40 -Compress | Add-Content -LiteralPath $Path -Encoding UTF8
}

function Rotate-LogIfLarge {
	param(
		[Parameter(Mandatory)][string]$Path,
		[int]$MaxMB = 25
	)

	if (Test-Path -LiteralPath $Path) {
		$file = Get-Item -LiteralPath $Path
		if ($file.Length -gt ($MaxMB * 1MB)) {
			$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
			Rename-Item -LiteralPath $Path -NewName "$($file.BaseName)_$stamp$($file.Extension)" -Force
		}
	}
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

	$raw = $event | ConvertTo-Json -Depth 40 -Compress
	$hash = Sha256Text -Text $raw
	$event['hash'] = $hash

	Write-JsonLine -Path $TangleLog -Object $event

	[ordered]@{
		updated   = (Get-Date).ToString('o')
		last_hash = $hash
	} | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $TangleState -Encoding UTF8
}

function Add-Alert {
	param(
		[Parameter(Mandatory)][string]$Severity,
		[Parameter(Mandatory)][string]$Title,
		[Parameter(Mandatory)][string]$Message,
		[Parameter(Mandatory)][int]$Score,
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

function Get-DefenderSafe {
	try {
		Get-MpComputerStatus | Select-Object `
			AMServiceEnabled,
			AntivirusEnabled,
			AntispywareEnabled,
			BehaviorMonitorEnabled,
			RealTimeProtectionEnabled,
			IoavProtectionEnabled,
			NISEnabled,
			OnAccessProtectionEnabled,
			AntivirusSignatureLastUpdated,
			QuickScanEndTime,
			FullScanEndTime
	} catch {
		[pscustomobject]@{ Error = $_.Exception.Message }
	}
}

function Get-FirewallSafe {
	try {
		Get-NetFirewallProfile | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction
	} catch {
		@([pscustomobject]@{ Error = $_.Exception.Message })
	}
}

function Get-AdminsSafe {
	try {
		Get-LocalGroupMember -Group 'Administrators' | Select-Object Name, ObjectClass, PrincipalSource
	} catch {
		@([pscustomobject]@{ Error = $_.Exception.Message })
	}
}

function Get-TasksSafe {
	try {
		Get-ScheduledTask |
			Where-Object { $_.TaskPath -notlike '\Microsoft*' } |
			Select-Object TaskName, TaskPath, State
	} catch {
		@([pscustomobject]@{ Error = $_.Exception.Message })
	}
}

function Get-ServicesSafe {
	try {
		Get-CimInstance Win32_Service |
			Where-Object { $_.State -eq 'Running' } |
			Select-Object Name, DisplayName, State, StartMode, StartName, PathName
	} catch {
		@([pscustomobject]@{ Error = $_.Exception.Message })
	}
}

function Get-ProcessesSafe {
	try {
		Get-CimInstance Win32_Process | Select-Object ProcessId, ParentProcessId, Name, ExecutablePath, CommandLine
	} catch {
		@([pscustomobject]@{ Error = $_.Exception.Message })
	}
}

function Get-ConnectionsSafe {
	try {
		$procMap = @{}
		Get-Process | ForEach-Object {
			$procMap[$_.Id] = $_.ProcessName
		}

		Get-NetTCPConnection -State Established |
			ForEach-Object {
				[pscustomobject]@{
					LocalAddress  = $_.LocalAddress
					LocalPort     = $_.LocalPort
					RemoteAddress = $_.RemoteAddress
					RemotePort    = $_.RemotePort
					State         = $_.State
					PID           = $_.OwningProcess
					Process       = $procMap[$_.OwningProcess]
				}
			}
	} catch {
		@([pscustomobject]@{ Error = $_.Exception.Message })
	}
}

function Get-WlanNetworksSafe {
	try {
		$raw = netsh wlan show networks mode=bssid 2>&1 | Out-String
	} catch {
		return @([pscustomobject]@{ Error = $_.Exception.Message })
	}

	$items = New-Object System.Collections.Generic.List[object]
	$ssid = $null
	$auth = $null
	$enc = $null

	foreach ($line in ($raw -split "`r?`n")) {
		$l = $line.Trim()

		if ($l -match '^SSID\s+\d+\s+:\s+(.*)$') {
			$ssid = $Matches[1]
			$auth = $null
			$enc = $null
		}
		elseif ($l -match '^Authentication\s+:\s+(.*)$') {
			$auth = $Matches[1]
		}
		elseif ($l -match '^Encryption\s+:\s+(.*)$') {
			$enc = $Matches[1]
		}
		elseif ($l -match '^BSSID\s+\d+\s+:\s+(.*)$') {
			$items.Add([pscustomobject]@{
				SSID           = $ssid
				BSSID          = $Matches[1]
				Authentication = $auth
				Encryption     = $enc
				Signal         = $null
				RadioType      = $null
				Channel        = $null
			}) | Out-Null
		}
		elseif ($l -match '^Signal\s+:\s+(.*)$') {
			if ($items.Count -gt 0) { $items[$items.Count - 1].Signal = $Matches[1] }
		}
		elseif ($l -match '^Radio type\s+:\s+(.*)$') {
			if ($items.Count -gt 0) { $items[$items.Count - 1].RadioType = $Matches[1] }
		}
		elseif ($l -match '^Channel\s+:\s+(.*)$') {
			if ($items.Count -gt 0) { $items[$items.Count - 1].Channel = $Matches[1] }
		}
	}

	return $items
}

function Get-NetworkLocalSafe {
	$adapters = try {
		Get-NetAdapter | Select-Object Name, InterfaceDescription, Status, MacAddress, LinkSpeed
	} catch {
		@([pscustomobject]@{ Error = $_.Exception.Message })
	}

	$ipconfig = try {
		Get-NetIPConfiguration | Select-Object InterfaceAlias, IPv4Address, IPv6Address, IPv4DefaultGateway, DNSServer
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

	[ordered]@{
		adapters  = $adapters
		ipconfig  = $ipconfig
		neighbors = $neighbors
	}
}

function New-Snapshot {
	[ordered]@{
		time        = (Get-Date).ToString('o')
		computer    = $env:COMPUTERNAME
		user        = $env:USERNAME
		mode        = 'LOCAL_DEFENSIVE_READ_ONLY'
		defender    = Get-DefenderSafe
		firewall    = Get-FirewallSafe
		admins      = Get-AdminsSafe
		tasks       = Get-TasksSafe
		services    = Get-ServicesSafe
		processes   = Get-ProcessesSafe
		connections = Get-ConnectionsSafe
		network     = Get-NetworkLocalSafe
		wlan        = Get-WlanNetworksSafe
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
	$Snapshot | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath $BaselinePath -Encoding UTF8
}

function Analyze-Snapshot {
	param([Parameter(Mandatory)][object]$Snapshot)

	$alerts = New-Object System.Collections.Generic.List[object]
	$score = 0

	if ($Snapshot.defender.PSObject.Properties.Name -contains 'RealTimeProtectionEnabled') {
		if ($Snapshot.defender.RealTimeProtectionEnabled -eq $false) {
			$score += 100
			$alerts.Add((Add-Alert -Severity 'CRITICAL' -Title 'Defender Echtzeitschutz deaktiviert' -Message 'Windows Defender RealTimeProtectionEnabled ist FALSE.' -Score 100 -Data $Snapshot.defender)) | Out-Null
		}
	}

	foreach ($fw in @($Snapshot.firewall)) {
		if ($fw.Enabled -eq $false) {
			$score += 80
			$alerts.Add((Add-Alert -Severity 'HIGH' -Title 'Firewall Profil deaktiviert' -Message "Firewall-Profil deaktiviert: $($fw.Name)" -Score 80 -Data $fw)) | Out-Null
		}
	}

	foreach ($c in @($Snapshot.connections)) {
		if ($null -ne $c.RemotePort) {
			$remotePort = [int]$c.RemotePort
			if ($RiskPorts -contains $remotePort) {
				$sev = 'MEDIUM'
				$s = 45
				if ($remotePort -in @(445, 3389, 5985, 5986)) {
					$sev = 'HIGH'
					$s = 75
				}

				$score += $s
				$alerts.Add((Add-Alert -Severity $sev -Title 'Risiko-Port Verbindung' -Message "Established TCP zu Risiko-Port $remotePort durch Prozess $($c.Process)." -Score $s -Data $c)) | Out-Null
			}
		}
	}

	foreach ($p in @($Snapshot.processes)) {
		$cmd = ''
		if ($p.CommandLine) {
			$cmd = ([string]$p.CommandLine).ToLowerInvariant()
		}

		$procName = ''
		if ($p.Name) {
			$procName = ([string]$p.Name).ToLowerInvariant()
		}

		if ($procName -in @('powershell.exe', 'pwsh.exe', 'cmd.exe', 'wscript.exe', 'cscript.exe', 'mshta.exe', 'rundll32.exe', 'regsvr32.exe')) {
			$hits = @()
			foreach ($pattern in $SuspiciousCmdPatterns) {
				if ($cmd.Contains($pattern)) {
					$hits += $pattern
				}
			}

			if ($hits.Count -gt 0) {
				$s = 85
				$score += $s
				$alerts.Add((Add-Alert -Severity 'HIGH' -Title 'Verdächtige Kommandozeile' -Message "Verdächtige Parameter erkannt bei $($p.Name)." -Score $s -Data ([ordered]@{
					process = $p
					hits    = $hits
				}))) | Out-Null
			}
		}
	}

	$baseline = Load-Baseline
	$delta = [ordered]@{
		baseline_exists = $null -ne $baseline
		new_admins      = @()
		new_neighbors   = @()
		new_wlan_bssid  = @()
		new_tasks       = @()
		new_services    = @()
	}

	if ($null -eq $baseline) {
		Save-Baseline -Snapshot $Snapshot
	}
	else {
		$oldAdmins = @($baseline.admins | ForEach-Object { $_.Name })
		foreach ($a in @($Snapshot.admins)) {
			if ($a.Name -and ($oldAdmins -notcontains $a.Name)) {
				$delta.new_admins += $a
				$score += 90
				$alerts.Add((Add-Alert -Severity 'HIGH' -Title 'Neuer lokaler Administrator' -Message "Neuer Admin seit Baseline: $($a.Name)" -Score 90 -Data $a)) | Out-Null
			}
		}

		$oldNeighbors = @($baseline.network.neighbors | ForEach-Object { "$($_.IPAddress)|$($_.LinkLayerAddress)" })
		foreach ($n in @($Snapshot.network.neighbors)) {
			$key = "$($n.IPAddress)|$($n.LinkLayerAddress)"
			if ($n.IPAddress -and ($oldNeighbors -notcontains $key)) {
				$delta.new_neighbors += $n
				$score += 25
			}
		}

		$oldBssid = @($baseline.wlan | ForEach-Object { $_.BSSID })
		foreach ($w in @($Snapshot.wlan)) {
			if ($w.BSSID -and ($oldBssid -notcontains $w.BSSID)) {
				$delta.new_wlan_bssid += $w
				$score += 10
			}
		}

		$oldTasks = @($baseline.tasks | ForEach-Object { "$($_.TaskPath)$($_.TaskName)" })
		foreach ($t in @($Snapshot.tasks)) {
			$key = "$($t.TaskPath)$($t.TaskName)"
			if ($t.TaskName -and ($oldTasks -notcontains $key)) {
				$delta.new_tasks += $t
				$score += 30
			}
		}

		$oldServices = @($baseline.services | ForEach-Object { $_.Name })
		foreach ($s in @($Snapshot.services)) {
			if ($s.Name -and ($oldServices -notcontains $s.Name)) {
				$delta.new_services += $s
				$score += 20
			}
		}
	}

	foreach ($a in @($alerts)) {
		Write-JsonLine -Path $AlertLog -Object $a
	}

	return [ordered]@{
		time          = (Get-Date).ToString('o')
		score         = [Math]::Min($score, 999)
		alert_count   = @($alerts).Count
		alerts        = $alerts
		delta         = $delta
		principles    = 'LOCAL / DEFENSIVE / READ-ONLY'
		core_sentence = 'Fakten vor Angst. Baseline vor Chaos. Sichtbarkeit vor Kontrolle.'
	}
}

function Make-Rows {
	param(
		[AllowNull()][object[]]$Items,
		[Parameter(Mandatory)][string[]]$Props
	)

	foreach ($item in @($Items)) {
		$tds = foreach ($p in $Props) {
			"<td>$(HtmlEncode $item.$p)</td>"
		}

		"<tr>$($tds -join '')</tr>"
	}
}

function New-Portal {
	param(
		[Parameter(Mandatory)][object]$Snapshot,
		[Parameter(Mandatory)][object]$Analysis
	)

	$score = [int]$Analysis.score
	$health = 'OK'
	if ($score -ge 150) { $health = 'WARN' }
	if ($score -ge 300) { $health = 'HIGH' }
	if ($score -ge 500) { $health = 'CRITICAL' }

	$lastHash = 'N/A'
	if (Test-Path -LiteralPath $TangleState) {
		try {
			$lastHash = (Get-Content -LiteralPath $TangleState -Raw | ConvertFrom-Json).last_hash
		} catch {
			$lastHash = 'N/A'
		}
	}

	$alertRows = foreach ($a in @($Analysis.alerts | Sort-Object score -Descending | Select-Object -First 50)) {
		"<tr><td>$(HtmlEncode $a.severity)</td><td>$(HtmlEncode $a.title)</td><td>$(HtmlEncode $a.message)</td><td>$(HtmlEncode $a.score)</td><td>$(HtmlEncode $a.time)</td></tr>"
	}

	$connRows = Make-Rows -Items (@($Snapshot.connections) | Select-Object -First 100) -Props @('Process', 'PID', 'LocalAddress', 'LocalPort', 'RemoteAddress', 'RemotePort', 'State')
	$procRows = Make-Rows -Items (@($Snapshot.processes) | Select-Object -First 100) -Props @('Name', 'ProcessId', 'ParentProcessId', 'ExecutablePath', 'CommandLine')
	$wlanRows = Make-Rows -Items (@($Snapshot.wlan) | Select-Object -First 100) -Props @('SSID', 'BSSID', 'Authentication', 'Encryption', 'Signal', 'RadioType', 'Channel')
	$neighborRows = Make-Rows -Items (@($Snapshot.network.neighbors) | Select-Object -First 100) -Props @('InterfaceAlias', 'IPAddress', 'LinkLayerAddress', 'State')
	$adminRows = Make-Rows -Items (@($Snapshot.admins)) -Props @('Name', 'ObjectClass', 'PrincipalSource')
	$taskRows = Make-Rows -Items (@($Snapshot.tasks) | Select-Object -First 100) -Props @('TaskName', 'TaskPath', 'State')
	$serviceRows = Make-Rows -Items (@($Snapshot.services) | Select-Object -First 100) -Props @('Name', 'DisplayName', 'State', 'StartMode', 'StartName')
	$fwRows = Make-Rows -Items (@($Snapshot.firewall)) -Props @('Name', 'Enabled', 'DefaultInboundAction', 'DefaultOutboundAction')

@"
<!doctype html>
<html lang="de">
<head>
<meta charset="utf-8">
<title>AVA 3.14 NEXT LAYER — ALL</title>
<style>
body{font-family:Segoe UI,Tahoma,Arial,sans-serif;background:#0b1016;color:#e9f3ff;padding:18px}
h1{margin:0 0 8px 0;color:#67d1ff}
.card{background:#121a24;border:1px solid #23354a;border-radius:8px;padding:12px;margin:12px 0}
table{width:100%;border-collapse:collapse}
th,td{padding:6px;border-bottom:1px solid #223547;text-align:left;font-size:12px;vertical-align:top}
th{color:#89dbff}
.health-OK{color:#5cff9f}.health-WARN{color:#ffda75}.health-HIGH,.health-CRITICAL{color:#ff7d8a}
.hash{word-break:break-all;color:#9ab4c8;font-size:12px}
</style>
</head>
<body>
<h1>AVA 3.14 NEXT LAYER — ALL</h1>
<div class="card">Health: <b class="health-$health">$health</b> · Score: <b>$score</b> · Alerts: <b>$(@($Analysis.alerts).Count)</b> · Snapshot: $(HtmlEncode $Snapshot.time)</div>
<div class="card"><b>Prinzip:</b> $(HtmlEncode $Analysis.principles)<br><b>Kernsatz:</b> $(HtmlEncode $Analysis.core_sentence)</div>
<div class="card"><b>Tangle Last Hash:</b><div class="hash">$(HtmlEncode $lastHash)</div></div>

<div class="card">
<h2>Alerts</h2>
<table><tbody><tr><th>Severity</th><th>Title</th><th>Message</th><th>Score</th><th>Time</th></tr>
$($alertRows -join "`n")
</tbody></table>
</div>

<div class="card">
<h2>Firewall Profiles</h2>
<table><tbody><tr><th>Name</th><th>Enabled</th><th>Inbound</th><th>Outbound</th></tr>
$($fwRows -join "`n")
</tbody></table>
</div>

<div class="card">
<h2>Established Connections</h2>
<table><tbody><tr><th>Process</th><th>PID</th><th>Local</th><th>LPort</th><th>Remote</th><th>RPort</th><th>State</th></tr>
$($connRows -join "`n")
</tbody></table>
</div>

<div class="card">
<h2>Processes</h2>
<table><tbody><tr><th>Name</th><th>PID</th><th>PPID</th><th>Path</th><th>CommandLine</th></tr>
$($procRows -join "`n")
</tbody></table>
</div>

<div class="card">
<h2>WLAN</h2>
<table><tbody><tr><th>SSID</th><th>BSSID</th><th>Auth</th><th>Encryption</th><th>Signal</th><th>Radio</th><th>Channel</th></tr>
$($wlanRows -join "`n")
</tbody></table>
</div>

<div class="card">
<h2>LAN Neighbors</h2>
<table><tbody><tr><th>Interface</th><th>IP</th><th>MAC</th><th>State</th></tr>
$($neighborRows -join "`n")
</tbody></table>
</div>

<div class="card">
<h2>Local Admins</h2>
<table><tbody><tr><th>Name</th><th>Class</th><th>Source</th></tr>
$($adminRows -join "`n")
</tbody></table>
</div>

<div class="card">
<h2>Non-Microsoft Scheduled Tasks</h2>
<table><tbody><tr><th>Name</th><th>Path</th><th>State</th></tr>
$($taskRows -join "`n")
</tbody></table>
</div>

<div class="card">
<h2>Running Services</h2>
<table><tbody><tr><th>Name</th><th>DisplayName</th><th>State</th><th>StartMode</th><th>StartName</th></tr>
$($serviceRows -join "`n")
</tbody></table>
</div>
</body>
</html>
"@ | Set-Content -LiteralPath $PortalHtml -Encoding UTF8
}

function Invoke-Ava314 {
	Ensure-Dirs
	foreach ($path in @($EventLog, $AlertLog, $TangleLog)) {
		Rotate-LogIfLarge -Path $path
	}

	$snapshot = New-Snapshot
	$analysis = Analyze-Snapshot -Snapshot $snapshot

	$snapshot | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath $SnapshotJson -Encoding UTF8
	$analysis | ConvertTo-Json -Depth 40 | Set-Content -LiteralPath $AnalysisJson -Encoding UTF8
	New-Portal -Snapshot $snapshot -Analysis $analysis

	Write-JsonLine -Path $EventLog -Object ([ordered]@{
		time    = (Get-Date).ToString('o')
		type    = 'SOC_SNAPSHOT'
		host    = $snapshot.computer
		score   = $analysis.score
		alerts  = $analysis.alert_count
		summary = 'Snapshot + Analyse erstellt'
	})

	Write-Tangle -Type 'SOC_SNAPSHOT' -Summary 'AVA 3.14 Snapshot erstellt' -Data ([ordered]@{
		time   = $snapshot.time
		score  = $analysis.score
		alerts = $analysis.alert_count
		host   = $snapshot.computer
	})

	Write-Host 'AVA 3.14 NEXT LAYER Snapshot erstellt.' -ForegroundColor Green
	Write-Host "Score: $($analysis.score) | Alerts: $($analysis.alert_count)" -ForegroundColor Yellow
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

if ($ResetBaseline -and (Test-Path -LiteralPath $BaselinePath)) {
	Remove-Item -LiteralPath $BaselinePath -Force
	Write-Host 'Baseline wurde zurückgesetzt.' -ForegroundColor Yellow
}

if ($InstallTask) {
	Install-AvaTask
	exit
}

if ($Loop) {
	while ($true) {
		Invoke-Ava314
		Start-Sleep -Seconds $IntervalSeconds
	}
}
else {
	Invoke-Ava314
}

if ($RunOnce -and (Test-Path -LiteralPath $PortalHtml)) {
	Start-Process $PortalHtml
}
