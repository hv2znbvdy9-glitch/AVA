#requires -RunAsAdministrator
<#
AVA SOC CORE v1
Defensiv / Lokal / Read-Only Monitoring
Keine Angriffe. Keine Exploits. Keine fremden Systeme.
Erstellt Logs, Alerts, Baseline und HTML Dashboard.
#>

[CmdletBinding()]
param(
    [switch]$RunOnce,
    [switch]$InstallTask,
    [switch]$RemoveTask
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root      = "C:\Windows\SecurityGuardian"
$LogDir    = Join-Path $Root "Logs"
$ReportDir = Join-Path $Root "Reports"
$StateDir  = Join-Path $Root "State"
$TaskName  = "AVA_SOC_CORE"

$EventLog     = Join-Path $LogDir "events.jsonl"
$AlertLog     = Join-Path $LogDir "alerts.jsonl"
$BaselinePath = Join-Path $StateDir "baseline.json"
$HtmlReport   = Join-Path $ReportDir "ava_soc_dashboard.html"

$CanaryFiles = @(
    (Join-Path $Root "finance_decoy_2026.txt"),
    (Join-Path $Root "admin_notes_decoy.txt"),
    (Join-Path $Root "vpn_inventory_decoy.txt")
)

$RiskPorts = @(21,23,135,139,445,3389,5985,5986)
$AllowedAdmins = @(
    "Administrator",
    "$env:USERNAME"
)

function Ensure-Dirs {
    foreach ($d in @($Root,$LogDir,$ReportDir,$StateDir)) {
        if (-not (Test-Path $d)) {
            New-Item -ItemType Directory -Path $d -Force | Out-Null
        }
    }
}

function Write-JsonLine {
    param(
        [string]$Path,
        [object]$Object
    )
    ($Object | ConvertTo-Json -Depth 8 -Compress) | Add-Content -Path $Path -Encoding UTF8
}

function New-Event {
    param(
        [string]$Type,
        [string]$Severity,
        [string]$Summary,
        [object]$Data
    )

    $ev = [ordered]@{
        time     = (Get-Date).ToString("o")
        host     = $env:COMPUTERNAME
        user     = $env:USERNAME
        type     = $Type
        severity = $Severity
        summary  = $Summary
        data     = $Data
    }

    Write-JsonLine -Path $EventLog -Object $ev
    return $ev
}

function New-Alert {
    param(
        [string]$Title,
        [string]$Severity,
        [int]$Score,
        [string]$Reason,
        [object]$Data
    )

    $alert = [ordered]@{
        time     = (Get-Date).ToString("o")
        host     = $env:COMPUTERNAME
        title    = $Title
        severity = $Severity
        score    = $Score
        reason   = $Reason
        data     = $Data
    }

    Write-JsonLine -Path $AlertLog -Object $alert
    return $alert
}

function Initialize-Canaries {
    foreach ($file in $CanaryFiles) {
        if (-not (Test-Path $file)) {
            "AVA CANARY FILE - DO NOT TOUCH - $(Get-Date -Format o)" |
                Set-Content -Path $file -Encoding UTF8
        }
    }
}

function Get-AdminSnapshot {
    try {
        Get-LocalGroupMember -Group "Administrators" |
            Select-Object Name, ObjectClass, PrincipalSource, SID
    } catch {
        @([pscustomobject]@{ Error = $_.Exception.Message })
    }
}

function Get-NetSnapshot {
    $proc = @{}
    Get-Process | ForEach-Object { $proc[$_.Id] = $_.ProcessName }

    Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue |
        Select-Object LocalAddress,LocalPort,RemoteAddress,RemotePort,State,OwningProcess,
        @{Name="ProcessName";Expression={ $proc[$_.OwningProcess] }}
}

function Get-ServiceSnapshot {
    Get-CimInstance Win32_Service |
        Where-Object { $_.StartName -notmatch "LocalSystem|LocalService|NetworkService" } |
        Select-Object Name, DisplayName, State, StartMode, StartName
}

function Get-TaskSnapshot {
    Get-ScheduledTask |
        Where-Object { $_.TaskPath -notlike "\Microsoft\*" } |
        Select-Object TaskName, TaskPath, State
}

function Get-DefenderSnapshot {
    try {
        Get-MpComputerStatus | Select-Object `
            AMServiceEnabled,
            AntivirusEnabled,
            RealTimeProtectionEnabled,
            BehaviorMonitorEnabled,
            IoavProtectionEnabled,
            AntispywareEnabled,
            NISEnabled
    } catch {
        [pscustomobject]@{ Error = $_.Exception.Message }
    }
}

function Save-Baseline {
    $baseline = [ordered]@{
        created   = (Get-Date).ToString("o")
        host      = $env:COMPUTERNAME
        admins    = @(Get-AdminSnapshot)
        tasks     = @(Get-TaskSnapshot)
        services  = @(Get-ServiceSnapshot)
        defender  = Get-DefenderSnapshot
    }

    $baseline | ConvertTo-Json -Depth 10 | Set-Content -Path $BaselinePath -Encoding UTF8
    New-Event -Type "baseline" -Severity "INFO" -Summary "Neue AVA Baseline erstellt" -Data $baseline | Out-Null
}

function Test-AdminDrift {
    if (-not (Test-Path $BaselinePath)) { return }

    $baseline = Get-Content $BaselinePath -Raw | ConvertFrom-Json
    $oldNames = @($baseline.admins.Name)
    $current = @(Get-AdminSnapshot)

    foreach ($admin in $current) {
        if ($oldNames -notcontains $admin.Name) {
            New-Alert `
                -Title "Neue Administrator-Mitgliedschaft erkannt" `
                -Severity "HIGH" `
                -Score 90 `
                -Reason "Ein Admin ist nicht in der Baseline enthalten." `
                -Data $admin | Out-Null
        }
    }
}

function Test-RiskConnections {
    $connections = @(Get-NetSnapshot)

    foreach ($c in $connections) {
        if ($RiskPorts -contains [int]$c.RemotePort -or $RiskPorts -contains [int]$c.LocalPort) {
            New-Alert `
                -Title "Riskanter Netzwerk-Port aktiv" `
                -Severity "MEDIUM" `
                -Score 69 `
                -Reason "Verbindung nutzt typischen Admin-/Remote-/Legacy-Port." `
                -Data $c | Out-Null
        }
    }

    New-Event -Type "network_snapshot" -Severity "INFO" -Summary "Netzwerk-Snapshot erstellt" -Data $connections | Out-Null
}

function Test-Canaries {
    foreach ($file in $CanaryFiles) {
        if (-not (Test-Path $file)) {
            New-Alert `
                -Title "Canary-Datei fehlt" `
                -Severity "CRITICAL" `
                -Score 100 `
                -Reason "Eine AVA Canary-Datei wurde gelöscht oder verschoben." `
                -Data @{ path = $file } | Out-Null
        }
    }
}

function Test-Defender {
    $d = Get-DefenderSnapshot
    New-Event -Type "defender_snapshot" -Severity "INFO" -Summary "Defender Status geprüft" -Data $d | Out-Null

    if ($d.RealTimeProtectionEnabled -eq $false) {
        New-Alert `
            -Title "Defender Echtzeitschutz deaktiviert" `
            -Severity "CRITICAL" `
            -Score 100 `
            -Reason "RealTimeProtectionEnabled ist FALSE." `
            -Data $d | Out-Null
    }
}

function Build-HtmlDashboard {
    $alerts = @()
    if (Test-Path $AlertLog) {
        $alerts = Get-Content $AlertLog -Tail 50 | ForEach-Object {
            try { $_ | ConvertFrom-Json } catch { $null }
        } | Where-Object { $_ }
    }

    $events = @()
    if (Test-Path $EventLog) {
        $events = Get-Content $EventLog -Tail 30 | ForEach-Object {
            try { $_ | ConvertFrom-Json } catch { $null }
        } | Where-Object { $_ }
    }

    $alertRows = foreach ($a in $alerts) {
        "<tr><td>$($a.time)</td><td>$($a.severity)</td><td>$($a.score)</td><td>$($a.title)</td><td>$($a.reason)</td></tr>"
    }

    $eventRows = foreach ($e in $events) {
        "<tr><td>$($e.time)</td><td>$($e.severity)</td><td>$($e.type)</td><td>$($e.summary)</td></tr>"
    }

$html = @"
<!doctype html>
<html>
<head>
<meta charset="utf-8">
<title>AVA SOC CORE Dashboard</title>
<style>
body { background:#07111f; color:#d8f7ff; font-family:Segoe UI,Arial; margin:30px; }
h1 { color:#79fff2; }
.card { border:1px solid #1f6f80; border-radius:14px; padding:18px; margin:18px 0; background:#0b1d2e; }
table { width:100%; border-collapse:collapse; }
td,th { border-bottom:1px solid #1f6f80; padding:8px; text-align:left; }
th { color:#8dffb0; }
.critical { color:#ff5f6d; }
</style>
</head>
<body>
<h1>🧠 AVA SOC CORE</h1>
<div class="card">
<b>Status:</b> Aktiv / Defensiv / Lokal<br>
<b>Host:</b> $env:COMPUTERNAME<br>
<b>User:</b> $env:USERNAME<br>
<b>Update:</b> $(Get-Date)
</div>

<div class="card">
<h2>🚨 Letzte Alerts</h2>
<table>
<tr><th>Zeit</th><th>Severity</th><th>Score</th><th>Titel</th><th>Grund</th></tr>
$($alertRows -join "`n")
</table>
</div>

<div class="card">
<h2>📋 Letzte Events</h2>
<table>
<tr><th>Zeit</th><th>Severity</th><th>Typ</th><th>Zusammenfassung</th></tr>
$($eventRows -join "`n")
</table>
</div>

</body>
</html>
"@

    $html | Set-Content -Path $HtmlReport -Encoding UTF8
}

function Install-Task {
    $scriptPath = $MyInvocation.ScriptName
    if (-not $scriptPath) {
        $scriptPath = $PSCommandPath
    }

    $action  = New-ScheduledTaskAction -Execute "powershell.exe" `
        -Argument "-NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`" -RunOnce"
    $trigger = New-ScheduledTaskTrigger -RepetitionInterval (New-TimeSpan -Minutes 15) `
        -Once -At (Get-Date)
    $settings = New-ScheduledTaskSettingsSet -MultipleInstances IgnoreNew `
        -ExecutionTimeLimit (New-TimeSpan -Minutes 10)
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest

    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger `
        -Settings $settings -Principal $principal -Force | Out-Null

    Write-Host "AVA SOC CORE Scheduled Task installiert: $TaskName" -ForegroundColor Green
}

function Remove-Task {
    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
        Write-Host "AVA SOC CORE Scheduled Task entfernt: $TaskName" -ForegroundColor Yellow
    } else {
        Write-Host "Scheduled Task nicht gefunden: $TaskName" -ForegroundColor Gray
    }
}

function Invoke-MonitoringCycle {
    Test-AdminDrift
    Test-RiskConnections
    Test-Canaries
    Test-Defender
    Build-HtmlDashboard
    New-Event -Type "cycle_complete" -Severity "INFO" `
        -Summary "AVA SOC CORE Monitoring-Zyklus abgeschlossen" `
        -Data @{ report = $HtmlReport } | Out-Null
}

# ------------------------------------------------------------
# MAIN
# ------------------------------------------------------------
if ($InstallTask) {
    Install-Task
    exit 0
}

if ($RemoveTask) {
    Remove-Task
    exit 0
}

Ensure-Dirs
Initialize-Canaries

if (-not (Test-Path $BaselinePath)) {
    Write-Host "Keine Baseline gefunden – erstelle initiale Baseline..." -ForegroundColor Cyan
    Save-Baseline
}

if ($RunOnce) {
    Invoke-MonitoringCycle
    Write-Host "AVA SOC CORE Einmalprüfung abgeschlossen." -ForegroundColor Green
    Write-Host "Dashboard: $HtmlReport" -ForegroundColor Cyan
    exit 0
}

Write-Host "AVA SOC CORE gestartet (kontinuierlich, Ctrl+C zum Beenden)." -ForegroundColor Green
Write-Host "Dashboard: $HtmlReport" -ForegroundColor Cyan
Write-Host ""

while ($true) {
    try {
        Invoke-MonitoringCycle
    } catch {
        New-Event -Type "error" -Severity "ERROR" `
            -Summary "Fehler im Monitoring-Zyklus" `
            -Data @{ message = $_.Exception.Message } | Out-Null
    }
    Start-Sleep -Seconds 300
}
