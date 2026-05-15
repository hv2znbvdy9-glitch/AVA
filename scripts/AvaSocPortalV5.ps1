#requires -RunAsAdministrator
<#
AVA SOC PORTAL V5 - ALL IN ONE ELITE
Defensiv / Lokal / Read-Only

- Kein Angriff
- Kein Exploit
- Kein Scan fremder Systeme
- Kein Deauth / Cracken / Payload
- Nur lokale Sichtbarkeit, Baseline, Delta, Risk Score, HTML Portal
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

$TaskName = 'AVA_SOC_PORTAL_V5'
$ScriptPath = $PSCommandPath

$EventLog = Join-Path $LogDir 'ava_soc_v5_events.jsonl'
$AlertLog = Join-Path $LogDir 'ava_soc_v5_alerts.jsonl'
$TangleLog = Join-Path $LogDir 'ava_soc_v5_tangle.jsonl'
$TangleState = Join-Path $StateDir 'ava_soc_v5_tangle_state.json'
$Baseline = Join-Path $StateDir 'ava_soc_v5_baseline.json'
$PortalHtml = Join-Path $ReportDir 'ava_soc_portal_v5.html'

$RiskPorts = @(21, 23, 135, 139, 445, 3389, 5985, 5986)
$SuspiciousPowerShell = @(
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
    '-ep bypass'
)

function Ensure-Dirs {
    foreach ($dir in @($Root, $LogDir, $StateDir, $ReportDir)) {
        if (-not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
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
        [string]$Type,
        [string]$Summary,
        [object]$Data
    )

    $previousHash = $null
    if (Test-Path -LiteralPath $TangleState) {
        try {
            $previousHash = (Get-Content -LiteralPath $TangleState -Raw | ConvertFrom-Json).last_hash
        } catch {}
    }

    $event = [ordered]@{
        time          = (Get-Date).ToString('o')
        host          = $env:COMPUTERNAME
        user          = $env:USERNAME
        type          = $Type
        summary       = $Summary
        previous_hash = $previousHash
        data          = $Data
    }

    $raw = $event | ConvertTo-Json -Depth 30 -Compress
    $hash = Sha256Text -Text $raw
    $event['hash'] = $hash

    Write-JsonLine -Path $TangleLog -Object $event

    [ordered]@{
        updated   = (Get-Date).ToString('o')
        last_hash = $hash
    } | ConvertTo-Json | Set-Content -LiteralPath $TangleState -Encoding UTF8
}

function Add-Alert {
    param(
        [string]$Severity,
        [string]$Title,
        [string]$Message,
        [int]$Score,
        [object]$Data
    )

    $alert = [ordered]@{
        time     = (Get-Date).ToString('o')
        severity = $Severity
        title    = $Title
        message  = $Message
        score    = $Score
        data     = $Data
    }

    Write-JsonLine -Path $AlertLog -Object $alert
    return $alert
}

function Get-WlanNetworksSafe {
    try {
        $raw = netsh wlan show networks mode=BSSID 2>&1 | Out-String
    } catch {
        return @([pscustomobject]@{ Error = $_.Exception.Message })
    }

    $items = New-Object System.Collections.Generic.List[object]
    $ssid = $null
    $auth = $null
    $enc = $null

    foreach ($line in ($raw -split "`r?`n")) {
        $trimmed = $line.Trim()

        if ($trimmed -match '^SSID\s+\d+\s+:\s+(.*)$') {
            $ssid = $Matches[1]
            $auth = $null
            $enc = $null
        } elseif ($trimmed -match '^Authentication\s+:\s+(.*)$') {
            $auth = $Matches[1]
        } elseif ($trimmed -match '^Encryption\s+:\s+(.*)$') {
            $enc = $Matches[1]
        } elseif ($trimmed -match '^BSSID\s+\d+\s+:\s+(.*)$') {
            $items.Add([pscustomobject]@{
                SSID           = $ssid
                BSSID          = $Matches[1]
                Authentication = $auth
                Encryption     = $enc
                Signal         = $null
                RadioType      = $null
                Channel        = $null
            }) | Out-Null
        } elseif ($trimmed -match '^Signal\s+:\s+(.*)$') {
            if ($items.Count -gt 0) {
                $items[$items.Count - 1].Signal = $Matches[1]
            }
        } elseif ($trimmed -match '^Radio type\s+:\s+(.*)$') {
            if ($items.Count -gt 0) {
                $items[$items.Count - 1].RadioType = $Matches[1]
            }
        } elseif ($trimmed -match '^Channel\s+:\s+(.*)$') {
            if ($items.Count -gt 0) {
                $items[$items.Count - 1].Channel = $Matches[1]
            }
        }
    }

    return $items
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
            FullScanEndTime,
            QuickScanEndTime
    } catch {
        return [pscustomobject]@{ Error = $_.Exception.Message }
    }
}

function Get-AdminsSafe {
    try {
        return Get-LocalGroupMember -Group 'Administrators' |
            Select-Object Name, ObjectClass, PrincipalSource
    } catch {
        return @([pscustomobject]@{ Error = $_.Exception.Message })
    }
}

function Get-TasksSafe {
    try {
        return Get-ScheduledTask |
            Where-Object { $_.TaskPath -notlike '\Microsoft*' } |
            Select-Object TaskName, TaskPath, State
    } catch {
        return @([pscustomobject]@{ Error = $_.Exception.Message })
    }
}

function Get-ServicesSafe {
    try {
        return Get-CimInstance Win32_Service |
            Where-Object { $_.State -eq 'Running' } |
            Select-Object Name, DisplayName, State, StartMode, StartName, PathName
    } catch {
        return @([pscustomobject]@{ Error = $_.Exception.Message })
    }
}

function Get-ProcessesSafe {
    try {
        return Get-CimInstance Win32_Process |
            Select-Object ProcessId, ParentProcessId, Name, ExecutablePath, CommandLine
    } catch {
        return @([pscustomobject]@{ Error = $_.Exception.Message })
    }
}

function Get-ConnectionsSafe {
    try {
        $processesById = @{}
        Get-Process | ForEach-Object { $processesById[$_.Id] = $_.ProcessName }

        return Get-NetTCPConnection -State Established |
            Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, State, OwningProcess |
            ForEach-Object {
                [pscustomobject]@{
                    LocalAddress  = $_.LocalAddress
                    LocalPort     = $_.LocalPort
                    RemoteAddress = $_.RemoteAddress
                    RemotePort    = $_.RemotePort
                    State         = $_.State
                    PID           = $_.OwningProcess
                    Process       = $processesById[$_.OwningProcess]
                }
            }
    } catch {
        return @([pscustomobject]@{ Error = $_.Exception.Message })
    }
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

    return [ordered]@{
        adapters  = $adapters
        ipconfig  = $ipconfig
        neighbors = $neighbors
    }
}

function Get-FirewallSafe {
    try {
        return Get-NetFirewallProfile | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction
    } catch {
        return @([pscustomobject]@{ Error = $_.Exception.Message })
    }
}

function New-Snapshot {
    return [ordered]@{
        time        = (Get-Date).ToString('o')
        computer    = $env:COMPUTERNAME
        user        = $env:USERNAME
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
    if (Test-Path -LiteralPath $Baseline) {
        try {
            return Get-Content -LiteralPath $Baseline -Raw | ConvertFrom-Json
        } catch {
            return $null
        }
    }

    return $null
}

function Save-Baseline {
    param([object]$Snapshot)

    $Snapshot | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $Baseline -Encoding UTF8
}

function Test-IsPrivateIp {
    param([string]$Ip)

    if ($Ip -match '^(127\.|10\.|192\.168\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|169\.254\.|::1|fe80:)') {
        return $true
    }

    return $false
}

function Analyze-Snapshot {
    param([object]$Snapshot)

    $alerts = New-Object System.Collections.Generic.List[object]
    $score = 0

    if ($Snapshot.defender.RealTimeProtectionEnabled -eq $false) {
        $score += 100
        $alerts.Add((Add-Alert -Severity 'CRITICAL' -Title 'Defender Realtime Off' -Message 'Windows Defender Echtzeitschutz ist deaktiviert.' -Score 100 -Data $Snapshot.defender)) | Out-Null
    }

    foreach ($firewallProfile in @($Snapshot.firewall)) {
        if ($firewallProfile.Enabled -eq $false) {
            $score += 80
            $alerts.Add((Add-Alert -Severity 'HIGH' -Title 'Firewall Profile Disabled' -Message "Firewall-Profil deaktiviert: $($firewallProfile.Name)" -Score 80 -Data $firewallProfile)) | Out-Null
        }
    }

    foreach ($connection in @($Snapshot.connections)) {
        if ($RiskPorts -contains [int]$connection.RemotePort) {
            $severity = 'MEDIUM'
            $riskScore = 45
            if ($connection.RemotePort -in @(445, 3389, 5985, 5986)) {
                $severity = 'HIGH'
                $riskScore = 75
            }

            $score += $riskScore
            $alerts.Add((Add-Alert -Severity $severity -Title 'Risk Port Connection' -Message "Verbindung zu Risiko-Port $($connection.RemotePort) durch $($connection.Process)." -Score $riskScore -Data $connection)) | Out-Null
        }
    }

    foreach ($process in @($Snapshot.processes)) {
        $commandLine = ''
        if ($process.CommandLine) {
            $commandLine = ([string]$process.CommandLine).ToLowerInvariant()
        }

        if ($process.Name -in @('powershell.exe', 'pwsh.exe', 'cmd.exe', 'wscript.exe', 'cscript.exe', 'mshta.exe', 'rundll32.exe', 'regsvr32.exe')) {
            $hits = @()
            foreach ($signature in $SuspiciousPowerShell) {
                if ($commandLine.Contains($signature)) {
                    $hits += $signature
                }
            }

            if ($hits.Count -gt 0) {
                $riskScore = 85
                $score += $riskScore
                $alerts.Add((Add-Alert -Severity 'HIGH' -Title 'Suspicious Command Line' -Message "Verdächtige Kommandozeile erkannt: $($process.Name)" -Score $riskScore -Data ([ordered]@{ process = $process; hits = $hits }))) | Out-Null
            }
        }
    }

    $base = Load-Baseline
    $delta = [ordered]@{
        baseline_exists = $null -ne $base
        new_admins      = @()
        new_neighbors   = @()
        new_wlan_bssid  = @()
    }

    if ($null -eq $base) {
        Save-Baseline -Snapshot $Snapshot
    } else {
        $oldAdmins = @($base.admins | ForEach-Object { $_.Name })
        foreach ($admin in @($Snapshot.admins)) {
            if ($admin.Name -and ($oldAdmins -notcontains $admin.Name)) {
                $delta.new_admins += $admin
                $score += 90
                $alerts.Add((Add-Alert -Severity 'HIGH' -Title 'New Local Admin' -Message "Neuer lokaler Administrator: $($admin.Name)" -Score 90 -Data $admin)) | Out-Null
            }
        }

        $oldNeighbors = @($base.network.neighbors | ForEach-Object { "$($_.IPAddress)|$($_.LinkLayerAddress)" })
        foreach ($neighbor in @($Snapshot.network.neighbors)) {
            $key = "$($neighbor.IPAddress)|$($neighbor.LinkLayerAddress)"
            if ($neighbor.IPAddress -and ($oldNeighbors -notcontains $key)) {
                $delta.new_neighbors += $neighbor
                $score += 25
            }
        }

        $oldBssid = @($base.wlan | ForEach-Object { $_.BSSID })
        foreach ($wlanItem in @($Snapshot.wlan)) {
            if ($wlanItem.BSSID -and ($oldBssid -notcontains $wlanItem.BSSID)) {
                $delta.new_wlan_bssid += $wlanItem
                $score += 10
            }
        }
    }

    return [ordered]@{
        score  = [Math]::Min($score, 999)
        alerts = $alerts
        delta  = $delta
    }
}

function Make-Rows {
    param([object[]]$Items, [string[]]$Props)

    foreach ($item in @($Items)) {
        $cells = foreach ($prop in $Props) {
            "<td>$(HtmlEncode $item.$prop)</td>"
        }

        "<tr>$($cells -join '')</tr>"
    }
}

function New-Portal {
    param(
        [object]$Snapshot,
        [object]$Analysis
    )

    $alertCount = @($Analysis.alerts).Count
    $connectionCount = @($Snapshot.connections).Count
    $processCount = @($Snapshot.processes).Count
    $wlanCount = @($Snapshot.wlan).Count
    $neighborCount = @($Snapshot.network.neighbors).Count
    $score = $Analysis.score

    $health = 'OK'
    if ($score -ge 150) { $health = 'WARN' }
    if ($score -ge 300) { $health = 'HIGH' }
    if ($score -ge 500) { $health = 'CRITICAL' }

    $lastHash = 'N/A'
    if (Test-Path -LiteralPath $TangleState) {
        try {
            $lastHash = (Get-Content -LiteralPath $TangleState -Raw | ConvertFrom-Json).last_hash
        } catch {}
    }

    $alertRows = foreach ($alert in @($Analysis.alerts | Sort-Object score -Descending | Select-Object -First 30)) {
        "<tr><td>$(HtmlEncode $alert.severity)</td><td>$(HtmlEncode $alert.title)</td><td>$(HtmlEncode $alert.message)</td><td>$(HtmlEncode $alert.score)</td><td>$(HtmlEncode $alert.time)</td></tr>"
    }

    $connectionRows = Make-Rows -Items (@($Snapshot.connections) | Select-Object -First 80) -Props @('Process', 'PID', 'LocalAddress', 'LocalPort', 'RemoteAddress', 'RemotePort', 'State')
    $processRows = Make-Rows -Items (@($Snapshot.processes) | Select-Object -First 80) -Props @('Name', 'ProcessId', 'ParentProcessId', 'ExecutablePath', 'CommandLine')
    $wlanRows = Make-Rows -Items (@($Snapshot.wlan) | Select-Object -First 80) -Props @('SSID', 'BSSID', 'Authentication', 'Encryption', 'Signal', 'RadioType', 'Channel')
    $neighborRows = Make-Rows -Items (@($Snapshot.network.neighbors) | Select-Object -First 80) -Props @('InterfaceAlias', 'IPAddress', 'LinkLayerAddress', 'State')
    $adminRows = Make-Rows -Items (@($Snapshot.admins)) -Props @('Name', 'ObjectClass', 'PrincipalSource')
    $taskRows = Make-Rows -Items (@($Snapshot.tasks) | Select-Object -First 80) -Props @('TaskName', 'TaskPath', 'State')
    $firewallRows = Make-Rows -Items (@($Snapshot.firewall)) -Props @('Name', 'Enabled', 'DefaultInboundAction', 'DefaultOutboundAction')

@"
<!doctype html>
<html lang="de">
<head>
<meta charset="utf-8">
<title>AVA SOC PORTAL V5</title>
<style>
:root{
--bg:#05080c;--panel:#0c1520dd;--line:#16384d;--green:#19ff8f;--blue:#22a7ff;
--text:#eaf6ff;--muted:#8fa3ad;--warn:#ffcc66;--danger:#ff5d6c;
}
*{box-sizing:border-box}
body{
margin:0;padding:34px;background:
linear-gradient(rgba(255,255,255,.025) 1px,transparent 1px),
linear-gradient(90deg,rgba(255,255,255,.025) 1px,transparent 1px),
radial-gradient(circle at top,#0d1720 0%,#05080c 60%);
background-size:60px 60px,60px 60px,cover;color:var(--text);
font-family:Consolas,"Segoe UI",monospace;
}
.frame{border:1px solid rgba(25,255,143,.35);padding:26px;min-height:92vh;box-shadow:0 0 35px rgba(25,255,143,.08)}
.topbar{display:flex;justify-content:space-between;border-bottom:1px solid var(--line);padding-bottom:18px;margin-bottom:30px}
.badge{border:1px solid rgba(25,255,143,.45);color:var(--green);padding:8px 14px;letter-spacing:3px;font-size:12px}
h1{font-size:56px;margin:10px 0 4px 0;letter-spacing:3px;line-height:1}
h1 span{color:var(--blue)}
.subtitle{color:var(--muted);letter-spacing:4px;font-size:12px}
.grid{display:grid;grid-template-columns:repeat(6,1fr);gap:16px;margin:26px 0}
.card{background:var(--panel);border:1px solid var(--line);padding:16px;box-shadow:inset 0 0 22px rgba(34,167,255,.04)}
.card h2{color:var(--green);font-size:13px;letter-spacing:3px;margin:0 0 12px 0;text-transform:uppercase}
.big{font-size:30px;color:var(--blue);font-weight:bold}
.small{color:var(--muted);font-size:12px}
.section{margin-top:24px}
table{width:100%;border-collapse:collapse;margin-top:10px}
th,td{padding:8px;border-bottom:1px solid rgba(255,255,255,.07);text-align:left;vertical-align:top;font-size:12px}
th{color:var(--blue);text-transform:uppercase;letter-spacing:1px}
.notice{border-left:4px solid var(--warn);background:rgba(255,204,102,.08);padding:16px;color:#ffe3a3}
.legal{border-left:4px solid var(--green);background:rgba(25,255,143,.06);padding:16px;color:#bfffdc}
.hash{word-break:break-all;color:var(--muted);font-size:12px}
.footer{margin-top:30px;padding-top:18px;border-top:1px solid var(--line);color:var(--muted);display:flex;justify-content:space-between;font-size:12px;letter-spacing:2px}
.status-OK{color:var(--green)}.status-WARN{color:var(--warn)}.status-HIGH,.status-CRITICAL{color:var(--danger)}
</style>
</head>
<body>
<div class="frame">

<div class="topbar">
<div class="badge">AVA SOC PORTAL V5</div>
<div class="badge">LOCAL / READ ONLY / DEFENSIVE</div>
</div>

<div>
<div class="subtitle">// SECURITY OPERATIONS VISIBILITY</div>
<h1>AVA SOC <span>PORTAL V5</span></h1>
<div class="subtitle">BASELINE · DELTA · TANGLE · DEFENDER · WLAN · NETWORK · PROCESS</div>
</div>

<div class="grid">
<div class="card"><h2>Health</h2><div class="big status-$health">$health</div><div class="small">Score: $score</div></div>
<div class="card"><h2>Alerts</h2><div class="big">$alertCount</div><div class="small">Risk Events</div></div>
<div class="card"><h2>Connections</h2><div class="big">$connectionCount</div><div class="small">Established TCP</div></div>
<div class="card"><h2>Processes</h2><div class="big">$processCount</div><div class="small">Local Processes</div></div>
<div class="card"><h2>WLAN</h2><div class="big">$wlanCount</div><div class="small">Visible BSSID</div></div>
<div class="card"><h2>Neighbors</h2><div class="big">$neighborCount</div><div class="small">LAN / ARP</div></div>
</div>

<div class="section legal">
<b>Kernsatz:</b> Fakten vor Angst. Baseline vor Chaos. Sichtbarkeit vor Kontrolle.<br>
Dieses System ist lokal, defensiv und read-only. Keine Angriffe, keine Exploits, keine fremden Ziele.
</div>

<div class="section card">
<h2>Tangle Hash Chain</h2>
<div class="small">Letzter Hash:</div>
<div class="hash">$(HtmlEncode $lastHash)</div>
</div>

<div class="section card">
<h2>Alerts</h2>
<table><tbody><tr><th>Severity</th><th>Title</th><th>Message</th><th>Score</th><th>Time</th></tr>
$($alertRows -join "`n")
</tbody></table>
</div>

<div class="section card">
<h2>Firewall Profiles</h2>
<table><tbody><tr><th>Name</th><th>Enabled</th><th>Inbound</th><th>Outbound</th></tr>
$($firewallRows -join "`n")
</tbody></table>
</div>

<div class="section card">
<h2>Established Connections</h2>
<table><tbody><tr><th>Process</th><th>PID</th><th>Local</th><th>LPort</th><th>Remote</th><th>RPort</th><th>State</th></tr>
$($connectionRows -join "`n")
</tbody></table>
</div>

<div class="section card">
<h2>Suspicious Process View</h2>
<table><tbody><tr><th>Name</th><th>PID</th><th>PPID</th><th>Path</th><th>CommandLine</th></tr>
$($processRows -join "`n")
</tbody></table>
</div>

<div class="section card">
<h2>WLAN View</h2>
<table><tbody><tr><th>SSID</th><th>BSSID</th><th>Auth</th><th>Encryption</th><th>Signal</th><th>Radio</th><th>Channel</th></tr>
$($wlanRows -join "`n")
</tbody></table>
</div>

<div class="section card">
<h2>LAN Neighbors</h2>
<table><tbody><tr><th>Interface</th><th>IP</th><th>MAC</th><th>State</th></tr>
$($neighborRows -join "`n")
</tbody></table>
</div>

<div class="section card">
<h2>Local Admins</h2>
<table><tbody><tr><th>Name</th><th>Class</th><th>Source</th></tr>
$($adminRows -join "`n")
</tbody></table>
</div>

<div class="section card">
<h2>Non-Microsoft Scheduled Tasks</h2>
<table><tbody><tr><th>Name</th><th>Path</th><th>State</th></tr>
$($taskRows -join "`n")
</tbody></table>
</div>

<div class="section notice">
<b>AVA Hinweis:</b> Wichtig sind Veränderungen: neue Admins, neue LAN-Nachbarn, neue BSSID, Risiko-Ports,
verdächtige PowerShell-Parameter oder deaktivierter Defender.
</div>

<div class="footer">
<div>AVA SOC PORTAL V5 · THE CYBER BITE HUD STYLE</div>
<div>$(HtmlEncode $Snapshot.time)</div>
</div>

</div>
</body>
</html>
"@ | Set-Content -LiteralPath $PortalHtml -Encoding UTF8
}

function Invoke-AvaSoc {
    Ensure-Dirs

    $snapshot = New-Snapshot
    $analysis = Analyze-Snapshot -Snapshot $snapshot

    Write-JsonLine -Path $EventLog -Object $snapshot
    Write-Tangle -Type 'SOC_SNAPSHOT' -Summary 'AVA SOC Portal V5 Snapshot erstellt' -Data ([ordered]@{
        score    = $analysis.score
        alerts   = @($analysis.alerts).Count
        computer = $snapshot.computer
        time     = $snapshot.time
    })

    New-Portal -Snapshot $snapshot -Analysis $analysis

    Write-Host 'AVA SOC PORTAL V5 erstellt.' -ForegroundColor Green
    Write-Host "Score: $($analysis.score)" -ForegroundColor Yellow
    Write-Host "Alerts: $(@($analysis.alerts).Count)" -ForegroundColor Yellow
    Write-Host "Portal: $PortalHtml" -ForegroundColor Cyan
}

function Install-AvaTask {
    if (-not $ScriptPath) {
        throw 'Bitte zuerst als .ps1 speichern.'
    }

    Ensure-Dirs

    $action = New-ScheduledTaskAction `
        -Execute 'powershell.exe' `
        -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`" -RunOnce"

    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1)
    $trigger.Repetition.Interval = 'PT1M'
    $trigger.Repetition.Duration = 'P3650D'

    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -RunLevel Highest

    Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $action `
        -Trigger $trigger `
        -Principal $principal `
        -Force | Out-Null

    Write-Host "Task installiert: $TaskName" -ForegroundColor Green
}

function Remove-AvaTask {
    $task = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($task) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Host "Task entfernt: $TaskName" -ForegroundColor Yellow
    } else {
        Write-Host "Task nicht gefunden: $TaskName" -ForegroundColor DarkYellow
    }
}

if ($InstallTask) {
    Install-AvaTask
    exit
}

if ($RemoveTask) {
    Remove-AvaTask
    exit
}

if ($Loop) {
    while ($true) {
        Invoke-AvaSoc
        Start-Sleep -Seconds $IntervalSeconds
    }
}

Invoke-AvaSoc

if ($RunOnce) {
    Start-Process $PortalHtml
}
