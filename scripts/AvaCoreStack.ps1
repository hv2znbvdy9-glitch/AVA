#requires -RunAsAdministrator
<#
AVA CORE STACK v1
Defensiv / Lokal / Read-Only
Windows Defender Telemetrie
PowerShell Prozessanalyse
Netzwerk TCP/UDP
Baseline + Delta Engine
Event-/Alert-Tangle
HTML Portal
Optional: Nmap Inventarisierung nur wenn installiert
#>

param(
    [switch]$RunOnce,
    [switch]$CreateBaseline,
    [switch]$OpenPortal
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

$Root      = "C:\Windows\SecurityGuardian"
$LogDir    = Join-Path $Root "Logs"
$StateDir  = Join-Path $Root "State"
$ReportDir = Join-Path $Root "Reports"

$EventLog     = Join-Path $LogDir "events_tangle.jsonl"
$AlertLog     = Join-Path $LogDir "alerts.jsonl"
$BaselineFile = Join-Path $StateDir "baseline_core.json"
$TangleState  = Join-Path $StateDir "tangle_state.json"
$PortalFile   = Join-Path $ReportDir "ava_core_portal.html"

foreach ($d in @($Root,$LogDir,$StateDir,$ReportDir)) {
    New-Item -ItemType Directory -Force -Path $d | Out-Null
}

function HtmlEncode($v) {
    if ($null -eq $v) { return "" }
    return [System.Net.WebUtility]::HtmlEncode([string]$v)
}

function Sha256Text($Text) {
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $bytes = [Text.Encoding]::UTF8.GetBytes($Text)
    $hash = $sha.ComputeHash($bytes)
    return (($hash | ForEach-Object { $_.ToString("x2") }) -join "")
}

function Get-LastTangleHash {
    if (Test-Path $TangleState) {
        try {
            return (Get-Content $TangleState -Raw | ConvertFrom-Json).last_hash
        } catch {}
    }
    return "GENESIS"
}

function Write-TangleEvent {
    param(
        [string]$Type,
        [string]$Severity = "INFO",
        [string]$Message,
        [hashtable]$Data = @{}
    )

    $prev = Get-LastTangleHash

    $obj = [ordered]@{
        time          = (Get-Date).ToString("s")
        computer      = $env:COMPUTERNAME
        user          = $env:USERNAME
        type          = $Type
        severity      = $Severity
        message       = $Message
        data          = $Data
        previous_hash = $prev
    }

    $raw = ($obj | ConvertTo-Json -Depth 8 -Compress)
    $hash = Sha256Text $raw
    $obj["hash"] = $hash

    ($obj | ConvertTo-Json -Depth 8 -Compress) | Add-Content -Path $EventLog -Encoding UTF8

    @{ last_hash = $hash; updated = (Get-Date).ToString("s") } |
        ConvertTo-Json | Set-Content $TangleState -Encoding UTF8

    if ($Severity -in @("LOW","MEDIUM","HIGH","CRITICAL")) {
        ($obj | ConvertTo-Json -Depth 8 -Compress) | Add-Content -Path $AlertLog -Encoding UTF8
    }
}

function Get-DefenderInfo {
    try {
        $mp = Get-MpComputerStatus
        return [ordered]@{
            available             = $true
            realtime_protection   = $mp.RealTimeProtectionEnabled
            antivirus_enabled     = $mp.AntivirusEnabled
            antispyware_enabled   = $mp.AntispywareEnabled
            signature_age         = $mp.AntivirusSignatureAge
            last_quick_scan       = $mp.QuickScanEndTime
            last_full_scan        = $mp.FullScanEndTime
            tamper_protection     = $mp.IsTamperProtected
        }
    } catch {
        return [ordered]@{
            available = $false
            error     = $_.Exception.Message
        }
    }
}

function Get-PowerShellProcessInfo {
    $bad = @(
        "-enc","encodedcommand","-nop","noprofile",
        "-w hidden","windowstyle hidden",
        "downloadstring","invoke-expression","iex ",
        "bypass","-ep bypass","frombase64string"
    )

    Get-CimInstance Win32_Process |
        Where-Object { $_.Name -in @("powershell.exe","pwsh.exe") } |
        ForEach-Object {
            $cmd = [string]$_.CommandLine
            $lower = $cmd.ToLowerInvariant()
            $hits = @($bad | Where-Object { $lower.Contains($_) })

            [ordered]@{
                pid          = $_.ProcessId
                ppid         = $_.ParentProcessId
                name         = $_.Name
                path         = $_.ExecutablePath
                command_line = $cmd
                suspicious   = ($hits.Count -gt 0)
                hits         = $hits
            }
        }
}

function Get-NetworkInfo {
    $tcp = @()
    $udp = @()

    try {
        $tcp = Get-NetTCPConnection |
            Where-Object { $_.State -eq "Established" } |
            Select-Object LocalAddress,LocalPort,RemoteAddress,RemotePort,State,OwningProcess
    } catch {}

    try {
        $udp = Get-NetUDPEndpoint |
            Select-Object LocalAddress,LocalPort,OwningProcess
    } catch {}

    $procMap = @{}
    Get-Process | ForEach-Object {
        $procMap[[int]$_.Id] = $_.ProcessName
    }

    $tcpOut = foreach ($c in $tcp) {
        [ordered]@{
            protocol       = "TCP"
            local_address  = $c.LocalAddress
            local_port     = $c.LocalPort
            remote_address = $c.RemoteAddress
            remote_port    = $c.RemotePort
            state          = $c.State
            pid            = $c.OwningProcess
            process        = $procMap[[int]$c.OwningProcess]
        }
    }

    $udpOut = foreach ($u in $udp) {
        [ordered]@{
            protocol      = "UDP"
            local_address = $u.LocalAddress
            local_port    = $u.LocalPort
            pid           = $u.OwningProcess
            process       = $procMap[[int]$u.OwningProcess]
        }
    }

    [ordered]@{
        tcp = @($tcpOut)
        udp = @($udpOut)
    }
}

function Get-Admins {
    try {
        Get-LocalGroupMember -Group "Administratoren" |
            Select-Object Name,ObjectClass,PrincipalSource
    } catch {
        try {
            Get-LocalGroupMember -Group "Administrators" |
                Select-Object Name,ObjectClass,PrincipalSource
        } catch {
            @()
        }
    }
}

function Get-TasksLite {
    try {
        Get-ScheduledTask |
            Where-Object {
                $_.TaskPath -notlike "\Microsoft\*" -and
                $_.TaskName -notlike "AVA*"
            } |
            Select-Object TaskName,TaskPath,State
    } catch {
        @()
    }
}

function Get-ServiceLite {
    try {
        Get-CimInstance Win32_Service |
            Where-Object { $_.State -eq "Running" } |
            Select-Object Name,DisplayName,State,StartMode,StartName,PathName
    } catch {
        @()
    }
}

function Get-NmapInfo {
    $nmap = Get-Command nmap.exe -ErrorAction SilentlyContinue
    if (-not $nmap) {
        return [ordered]@{
            installed = $false
            note      = "Nmap nicht gefunden. Optional installieren, falls gewünscht."
        }
    }

    return [ordered]@{
        installed = $true
        path      = $nmap.Source
        note      = "Nur Erkennung. Kein Scan ausgefuehrt."
    }
}

function New-Snapshot {
    [ordered]@{
        time          = (Get-Date).ToString("s")
        computer      = $env:COMPUTERNAME
        user          = $env:USERNAME
        defender      = Get-DefenderInfo
        powershell    = @(Get-PowerShellProcessInfo)
        network       = Get-NetworkInfo
        admins        = @(Get-Admins)
        tasks         = @(Get-TasksLite)
        services      = @(Get-ServiceLite)
        nmap          = Get-NmapInfo
    }
}

function Compare-WithBaseline {
    param($Snapshot)

    $alerts = New-Object System.Collections.Generic.List[object]

    if (-not (Test-Path $BaselineFile)) {
        $alerts.Add([ordered]@{
            severity = "LOW"
            type     = "BASELINE"
            message  = "Keine Baseline vorhanden. Starte mit -CreateBaseline."
        })
        return $alerts
    }

    $base = Get-Content $BaselineFile -Raw | ConvertFrom-Json

    foreach ($p in $Snapshot.powershell) {
        if ($p.suspicious) {
            $alerts.Add([ordered]@{
                severity = "HIGH"
                type     = "POWERSHELL"
                message  = "Verdaechtiger PowerShell-Prozess erkannt: PID $($p.pid)"
                data     = $p
            })
        }
    }

    if ($Snapshot.defender.available -and -not $Snapshot.defender.realtime_protection) {
        $alerts.Add([ordered]@{
            severity = "CRITICAL"
            type     = "DEFENDER"
            message  = "Defender Echtzeitschutz ist AUS."
        })
    }

    $baseAdmins = @($base.admins | ForEach-Object { $_.Name })
    foreach ($a in $Snapshot.admins) {
        if ($baseAdmins -notcontains $a.Name) {
            $alerts.Add([ordered]@{
                severity = "HIGH"
                type     = "ADMIN_DELTA"
                message  = "Neuer lokaler Admin seit Baseline: $($a.Name)"
                data     = @{ admin = $a.Name }
            })
        }
    }

    $baseTasks = @($base.tasks | ForEach-Object { "$($_.TaskPath)$($_.TaskName)" })
    foreach ($t in $Snapshot.tasks) {
        $id = "$($t.TaskPath)$($t.TaskName)"
        if ($baseTasks -notcontains $id) {
            $alerts.Add([ordered]@{
                severity = "MEDIUM"
                type     = "TASK_DELTA"
                message  = "Neue geplante Aufgabe seit Baseline: $id"
            })
        }
    }

    $riskPorts = @(21,23,135,139,445,3389,5985,5986)
    foreach ($c in $Snapshot.network.tcp) {
        if ($riskPorts -contains [int]$c.local_port -or $riskPorts -contains [int]$c.remote_port) {
            $alerts.Add([ordered]@{
                severity = "MEDIUM"
                type     = "NETWORK_RISK_PORT"
                message  = "Risikorelevante TCP-Verbindung/Port erkannt: $($c.process) PID $($c.pid)"
                data     = $c
            })
        }
    }

    return $alerts
}

function Build-Portal {
    param($Snapshot, $Alerts)

    $alertRows = foreach ($a in $Alerts) {
        "<tr><td>$(HtmlEncode $a.severity)</td><td>$(HtmlEncode $a.type)</td><td>$(HtmlEncode $a.message)</td></tr>"
    }

    $psRows = foreach ($p in $Snapshot.powershell) {
        "<tr><td>$(HtmlEncode $p.pid)</td><td>$(HtmlEncode $p.name)</td><td>$(HtmlEncode $p.suspicious)</td><td>$(HtmlEncode (($p.hits -join ', ')))</td></tr>"
    }

    $tcpRows = foreach ($c in ($Snapshot.network.tcp | Select-Object -First 50)) {
        "<tr><td>$(HtmlEncode $c.process)</td><td>$(HtmlEncode $c.pid)</td><td>$(HtmlEncode $c.local_port)</td><td>$(HtmlEncode $c.remote_address)</td><td>$(HtmlEncode $c.remote_port)</td></tr>"
    }

    $alertRowsHtml  = $alertRows  -join "`n"
    $psRowsHtml     = $psRows     -join "`n"
    $tcpRowsHtml    = $tcpRows    -join "`n"

@"
<!DOCTYPE html>
<html lang="de">
<head>
<meta charset="UTF-8">
<title>AVA CORE STACK</title>
<style>
body { font-family: monospace; background: #0d1117; color: #c9d1d9; margin: 2em; }
h1 { color: #58a6ff; }
h2 { color: #79c0ff; border-bottom: 1px solid #30363d; padding-bottom: 4px; }
table { border-collapse: collapse; width: 100%; margin-bottom: 1em; }
th, td { border: 1px solid #30363d; padding: 4px 8px; text-align: left; }
th { background: #161b22; color: #8b949e; }
.card { background: #161b22; border: 1px solid #30363d; border-radius: 6px; padding: 1em; margin-bottom: 1.5em; }
.CRITICAL { color: #f85149; font-weight: bold; }
.HIGH { color: #ff7b72; }
.MEDIUM { color: #d29922; }
.LOW { color: #3fb950; }
.INFO { color: #8b949e; }
</style>
</head>
<body>
<h1>AVA CORE STACK v1</h1>
<p>Computer: $(HtmlEncode $Snapshot.computer) | User: $(HtmlEncode $Snapshot.user) | Zeit: $(HtmlEncode $Snapshot.time)</p>

<div class="card">
<h2>Alerts</h2>
<table>
<thead><tr><th>Severity</th><th>Typ</th><th>Meldung</th></tr></thead>
<tbody>
$alertRowsHtml
</tbody></table>
</div>

<div class="card">
<h2>PowerShell Prozesse</h2>
<table>
<thead><tr><th>PID</th><th>Name</th><th>Verdaechtig</th><th>Treffer</th></tr></thead>
<tbody>
$psRowsHtml
</tbody></table>
</div>

<div class="card">
<h2>TCP Verbindungen (max 50)</h2>
<table>
<thead><tr><th>Prozess</th><th>PID</th><th>Lokaler Port</th><th>Remote Adresse</th><th>Remote Port</th></tr></thead>
<tbody>
$tcpRowsHtml
</tbody></table>
</div>
</body>
</html>
"@ | Set-Content -Path $PortalFile -Encoding UTF8
}

$snapshot = New-Snapshot

if ($CreateBaseline) {
    $snapshot | ConvertTo-Json -Depth 12 | Set-Content $BaselineFile -Encoding UTF8
    Write-TangleEvent -Type "BASELINE" -Severity "INFO" -Message "Baseline erstellt." -Data @{ path = $BaselineFile }
    Write-Host "AVA Baseline erstellt: $BaselineFile" -ForegroundColor Green
}

$alerts = Compare-WithBaseline -Snapshot $snapshot

Write-TangleEvent -Type "SNAPSHOT" -Severity "INFO" -Message "Snapshot erstellt." -Data @{
    powershell_count = @($snapshot.powershell).Count
    tcp_count        = @($snapshot.network.tcp).Count
    udp_count        = @($snapshot.network.udp).Count
    admin_count      = @($snapshot.admins).Count
    task_count       = @($snapshot.tasks).Count
    service_count    = @($snapshot.services).Count
}

foreach ($a in $alerts) {
    $sev = if ($a.severity) { $a.severity } else { "LOW" }
    $typ = if ($a.type) { $a.type } else { "ALERT" }
    $msg = if ($a.message) { $a.message } else { "Alert ohne Meldung" }

    Write-TangleEvent -Type $typ -Severity $sev -Message $msg -Data @{
        alert = $a
    }
}

Build-Portal -Snapshot $snapshot -Alerts $alerts

Write-Host ""
Write-Host "AVA CORE STACK abgeschlossen." -ForegroundColor Cyan
Write-Host "Portal: $PortalFile" -ForegroundColor Green
Write-Host "Eventlog: $EventLog" -ForegroundColor Green
Write-Host "Alerts: $AlertLog" -ForegroundColor Green

if ($OpenPortal) {
    Start-Process $PortalFile
}
