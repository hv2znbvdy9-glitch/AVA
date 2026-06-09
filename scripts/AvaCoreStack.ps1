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
$TrendFile    = Join-Path $StateDir "trend_core.json"
$MemoryFile   = Join-Path $StateDir "ava_memory.json"
$IntegrityFile = Join-Path $StateDir "ava_core_integrity.json"

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

function Load-JsonFile {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $null }
    try {
        return (Get-Content $Path -Raw | ConvertFrom-Json)
    } catch {
        return $null
    }
}

function Save-JsonFile {
    param([string]$Path, $Data)
    $Data | ConvertTo-Json -Depth 20 | Set-Content -Path $Path -Encoding UTF8
}

function Get-JsonLines {
    param([string]$Path)

    if (-not (Test-Path $Path)) { return @() }

    $out = New-Object System.Collections.Generic.List[object]
    foreach ($line in (Get-Content -Path $Path)) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try {
            $out.Add(($line | ConvertFrom-Json)) | Out-Null
        } catch {}
    }
    return @($out)
}

function Get-RemoteIpReputation {
    param([string]$Address)

    if ([string]::IsNullOrWhiteSpace($Address)) { return "UNKNOWN" }
    if ($Address -in @("::","0.0.0.0","*")) { return "LOCAL_OR_UNSPECIFIED" }

    $ipObj = $null
    if (-not [System.Net.IPAddress]::TryParse($Address, [ref]$ipObj)) {
        return "UNKNOWN"
    }

    if ($ipObj.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetworkV6) {
        if ($Address -eq "::1") { return "LOOPBACK" }
        if ($Address -like "fe80:*") { return "LINK_LOCAL" }
        if ($Address -like "fc*" -or $Address -like "fd*") { return "PRIVATE" }
        return "PUBLIC_UNKNOWN"
    }

    $b = $ipObj.GetAddressBytes()
    if ($b[0] -eq 10) { return "PRIVATE" }
    if ($b[0] -eq 127) { return "LOOPBACK" }
    if ($b[0] -eq 169 -and $b[1] -eq 254) { return "LINK_LOCAL" }
    if ($b[0] -eq 172 -and $b[1] -ge 16 -and $b[1] -le 31) { return "PRIVATE" }
    if ($b[0] -eq 192 -and $b[1] -eq 168) { return "PRIVATE" }
    if ($b[0] -eq 192 -and $b[1] -eq 0 -and $b[2] -eq 2) { return "DOCUMENTATION" }
    if ($b[0] -eq 198 -and $b[1] -eq 51 -and $b[2] -eq 100) { return "DOCUMENTATION" }
    if ($b[0] -eq 203 -and $b[1] -eq 0 -and $b[2] -eq 113) { return "DOCUMENTATION" }

    return "PUBLIC_UNKNOWN"
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
            remote_reputation = Get-RemoteIpReputation -Address $c.RemoteAddress
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

    function Get-ProcessGraph {
        param($Snapshot)

        $nodes = New-Object System.Collections.Generic.List[object]
        $edges = New-Object System.Collections.Generic.List[object]

        foreach ($p in @($Snapshot.powershell)) {
            $nodes.Add([ordered]@{
                pid  = $p.pid
                ppid = $p.ppid
                name = $p.name
            }) | Out-Null

            if ($p.ppid -and [int]$p.ppid -gt 0) {
                $edges.Add([ordered]@{
                    relation = "parent_child"
                    from     = $p.ppid
                    to       = $p.pid
                    detail   = "$($p.ppid) -> $($p.pid)"
                }) | Out-Null
            }
        }

        foreach ($c in @($Snapshot.network.tcp)) {
            if (-not $c.pid) { continue }
            $edges.Add([ordered]@{
                relation          = "process_network"
                from              = $c.pid
                to                = "$($c.remote_address):$($c.remote_port)"
                detail            = "$($c.process) -> $($c.remote_address):$($c.remote_port)"
                remote_reputation = $c.remote_reputation
            }) | Out-Null
        }

        [ordered]@{
            nodes = @($nodes)
            edges = @($edges)
        }
    }

    function Get-AvaFileIntegrity {
        $current = @{}
        Get-ChildItem -Path $PSScriptRoot -Filter "*.ps1" -File | ForEach-Object {
            try {
                $current[$_.Name] = (Get-FileHash -Path $_.FullName -Algorithm SHA256).Hash
            } catch {}
        }

        $baseline = Load-JsonFile -Path $IntegrityFile
        if (-not $baseline) {
            Save-JsonFile -Path $IntegrityFile -Data $current
            return [ordered]@{
                status  = "BASELINE_CREATED"
                added   = @($current.Keys)
                changed = @()
                missing = @()
                files   = $current
            }
        }

        $added = New-Object System.Collections.Generic.List[object]
        $changed = New-Object System.Collections.Generic.List[object]
        $missing = New-Object System.Collections.Generic.List[object]

        foreach ($k in $current.Keys) {
            if (-not $baseline.PSObject.Properties.Name.Contains($k)) {
                $added.Add($k) | Out-Null
                continue
            }
            if ($baseline.$k -ne $current[$k]) {
                $changed.Add($k) | Out-Null
            }
        }
        foreach ($k in $baseline.PSObject.Properties.Name) {
            if (-not $current.ContainsKey($k)) {
                $missing.Add($k) | Out-Null
            }
        }

        $status = if ($added.Count -or $changed.Count -or $missing.Count) { "CHANGED" } else { "OK" }
        Save-JsonFile -Path $IntegrityFile -Data $current

        return [ordered]@{
            status  = $status
            added   = @($added)
            changed = @($changed)
            missing = @($missing)
            files   = $current
        }
    }

    function Add-TimelineEntry {
        param(
            [string]$Category,
            [string]$Severity,
            [string]$Title,
            [string]$Detail = ""
        )
        [ordered]@{
            time     = (Get-Date).ToString("s")
            category = $Category
            severity = $Severity
            title    = $Title
            detail   = $Detail
        }
    }

    function Get-RiskAssessment {
        param($Alerts, $Snapshot, $Integrity)

        $score = 0
        $reasons = New-Object System.Collections.Generic.List[string]

        foreach ($a in @($Alerts)) {
            switch ($a.severity) {
                "CRITICAL" { $score += 40; $reasons.Add("CRITICAL Alert: $($a.type)") | Out-Null }
                "HIGH"     { $score += 25; $reasons.Add("HIGH Alert: $($a.type)") | Out-Null }
                "MEDIUM"   { $score += 15; $reasons.Add("MEDIUM Alert: $($a.type)") | Out-Null }
                "LOW"      { $score += 5;  $reasons.Add("LOW Alert: $($a.type)") | Out-Null }
            }
        }

        $suspiciousPs = @($Snapshot.powershell | Where-Object { $_.suspicious }).Count
        if ($suspiciousPs -gt 0) {
            $score += 15
            $reasons.Add("Verdaechtige PowerShell-Prozesse: $suspiciousPs") | Out-Null
        }

        if ($Integrity.status -eq "CHANGED") {
            $score += 20
            $reasons.Add("Integritaetsabweichung in AVA-Dateien erkannt.") | Out-Null
        }

        if ($score -gt 100) { $score = 100 }

        $level = "LOW"
        if ($score -ge 80) { $level = "CRITICAL" }
        elseif ($score -ge 60) { $level = "HIGH" }
        elseif ($score -ge 30) { $level = "MEDIUM" }

        if ($reasons.Count -eq 0) {
            $reasons.Add("Keine relevanten Abweichungen erkannt.") | Out-Null
        }

        [ordered]@{
            score   = $score
            level   = $level
            reasons = @($reasons)
        }
    }

    function Update-TrendState {
        param($Snapshot, $Alerts, $Risk)

        $trend = Load-JsonFile -Path $TrendFile
        if (-not $trend) { $trend = @() }

        $entry = [ordered]@{
            time         = (Get-Date).ToString("s")
            date         = (Get-Date).ToString("yyyy-MM-dd")
            alerts_total = @($Alerts).Count
            critical     = @($Alerts | Where-Object { $_.severity -eq "CRITICAL" }).Count
            high         = @($Alerts | Where-Object { $_.severity -eq "HIGH" }).Count
            medium       = @($Alerts | Where-Object { $_.severity -eq "MEDIUM" }).Count
            low          = @($Alerts | Where-Object { $_.severity -eq "LOW" }).Count
            risk_score   = $Risk.score
            tcp_count    = @($Snapshot.network.tcp).Count
        }

        $trend = @($trend) + @($entry)
        $trend = @($trend | Sort-Object time | Select-Object -Last 200)
        Save-JsonFile -Path $TrendFile -Data $trend

        return @($trend)
    }

    function Get-TrendByDay {
        param($TrendEntries)

        $groups = @($TrendEntries | Group-Object date | Sort-Object Name)
        $out = foreach ($g in $groups) {
            $items = @($g.Group)
            [ordered]@{
                date            = $g.Name
                sample_count    = $items.Count
                max_risk_score  = ($items | Measure-Object -Property risk_score -Maximum).Maximum
                avg_risk_score  = [Math]::Round((($items | Measure-Object -Property risk_score -Average).Average), 2)
                alerts_total    = ($items | Measure-Object -Property alerts_total -Sum).Sum
                critical_total  = ($items | Measure-Object -Property critical -Sum).Sum
                high_total      = ($items | Measure-Object -Property high -Sum).Sum
            }
        }
        return @($out | Select-Object -Last 14)
    }

    function Update-AvaMemory {
        param($Alerts)

        $memory = Load-JsonFile -Path $MemoryFile
        if (-not $memory) { $memory = @() }
        $list = New-Object System.Collections.Generic.List[object]
        foreach ($m in @($memory)) { $list.Add($m) | Out-Null }

        foreach ($a in @($Alerts)) {
            $pid = ""
            $processName = ""
            $remoteIp = ""
            if ($a.data) {
                if ($a.data.pid) { $pid = [string]$a.data.pid }
                if ($a.data.process) { $processName = [string]$a.data.process }
                if ($a.data.remote_address) { $remoteIp = [string]$a.data.remote_address }
            }

            $corrId = Sha256Text "$($a.type)|$($a.message)|$pid|$remoteIp"
            $entry = [ordered]@{
                time          = (Get-Date).ToString("s")
                correlation_id = $corrId
                alert_type    = $a.type
                severity      = $a.severity
                message       = $a.message
                process_pid   = $pid
                process_name  = $processName
                remote_ip     = $remoteIp
                memory_tag    = "AVA Memory ↔ Alert ↔ Prozess ↔ Netzwerk"
            }

            $exists = $false
            foreach ($m in @($list)) {
                if ($m.correlation_id -eq $corrId) { $exists = $true; break }
            }
            if (-not $exists) { $list.Add($entry) | Out-Null }
        }

        $final = @($list | Sort-Object time | Select-Object -Last 500)
        Save-JsonFile -Path $MemoryFile -Data $final
        return $final
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
    param($Snapshot, $Alerts, $Risk, $Timeline, $Trend, $ProcessGraph, $Integrity, $Memory)

    $alertRows = foreach ($a in $Alerts) {
        "<tr><td>$(HtmlEncode $a.severity)</td><td>$(HtmlEncode $a.type)</td><td>$(HtmlEncode $a.message)</td></tr>"
    }

    $psRows = foreach ($p in $Snapshot.powershell) {
        "<tr><td>$(HtmlEncode $p.pid)</td><td>$(HtmlEncode $p.name)</td><td>$(HtmlEncode $p.suspicious)</td><td>$(HtmlEncode (($p.hits -join ', ')))</td></tr>"
    }

    $tcpRows = foreach ($c in ($Snapshot.network.tcp | Select-Object -First 50)) {
        "<tr><td>$(HtmlEncode $c.process)</td><td>$(HtmlEncode $c.pid)</td><td>$(HtmlEncode $c.local_port)</td><td>$(HtmlEncode $c.remote_address)</td><td>$(HtmlEncode $c.remote_port)</td><td>$(HtmlEncode $c.remote_reputation)</td></tr>"
    }

    $timelineRows = foreach ($t in (@($Timeline) | Select-Object -Last 50)) {
        "<tr><td>$(HtmlEncode $t.time)</td><td>$(HtmlEncode $t.category)</td><td>$(HtmlEncode $t.severity)</td><td>$(HtmlEncode $t.title)</td><td>$(HtmlEncode $t.detail)</td></tr>"
    }

    $trendRows = foreach ($d in @($Trend)) {
        "<tr><td>$(HtmlEncode $d.date)</td><td>$(HtmlEncode $d.sample_count)</td><td>$(HtmlEncode $d.avg_risk_score)</td><td>$(HtmlEncode $d.max_risk_score)</td><td>$(HtmlEncode $d.alerts_total)</td><td>$(HtmlEncode $d.critical_total)</td><td>$(HtmlEncode $d.high_total)</td></tr>"
    }

    $graphRows = foreach ($e in (@($ProcessGraph.edges) | Select-Object -First 60)) {
        "<tr><td>$(HtmlEncode $e.relation)</td><td>$(HtmlEncode $e.from)</td><td>$(HtmlEncode $e.to)</td><td>$(HtmlEncode $e.detail)</td><td>$(HtmlEncode $e.remote_reputation)</td></tr>"
    }

    $memoryRows = foreach ($m in (@($Memory) | Select-Object -Last 50)) {
        "<tr><td>$(HtmlEncode $m.time)</td><td>$(HtmlEncode $m.alert_type)</td><td>$(HtmlEncode $m.severity)</td><td>$(HtmlEncode $m.process_pid)</td><td>$(HtmlEncode $m.process_name)</td><td>$(HtmlEncode $m.remote_ip)</td><td>$(HtmlEncode $m.correlation_id)</td></tr>"
    }

    $alertRowsHtml  = $alertRows  -join "`n"
    $psRowsHtml     = $psRows     -join "`n"
    $tcpRowsHtml    = $tcpRows    -join "`n"
    $timelineRowsHtml = $timelineRows -join "`n"
    $trendRowsHtml = $trendRows -join "`n"
    $graphRowsHtml = $graphRows -join "`n"
    $memoryRowsHtml = $memoryRows -join "`n"
    $riskReasonsHtml = (@($Risk.reasons) | ForEach-Object { "<li>$(HtmlEncode $_)</li>" }) -join "`n"
    $integrityAdded = ((@($Integrity.added) -join ", "))
    $integrityChanged = ((@($Integrity.changed) -join ", "))
    $integrityMissing = ((@($Integrity.missing) -join ", "))

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
<h2>Risiko-Score mit Begruendung</h2>
<p><span class="$(HtmlEncode $Risk.level)">Score: $(HtmlEncode $Risk.score) | Level: $(HtmlEncode $Risk.level)</span></p>
<ul>
$riskReasonsHtml
</ul>
</div>

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
<thead><tr><th>Prozess</th><th>PID</th><th>Lokaler Port</th><th>Remote Adresse</th><th>Remote Port</th><th>Remote-IP-Reputation</th></tr></thead>
<tbody>
$tcpRowsHtml
</tbody></table>
</div>

<div class="card">
<h2>Prozess-Graphen (Parent ↔ Child ↔ Netzwerk)</h2>
<table>
<thead><tr><th>Relation</th><th>Von</th><th>Nach</th><th>Detail</th><th>Remote Reputation</th></tr></thead>
<tbody>
$graphRowsHtml
</tbody></table>
</div>

<div class="card">
<h2>AVA Memory ↔ Alert ↔ Prozess ↔ Netzwerk</h2>
<table>
<thead><tr><th>Zeit</th><th>Alert</th><th>Severity</th><th>PID</th><th>Prozess</th><th>Remote-IP</th><th>Correlation ID</th></tr></thead>
<tbody>
$memoryRowsHtml
</tbody></table>
</div>

<div class="card">
<h2>Portal-Dashboard mit Zeitachse</h2>
<table>
<thead><tr><th>Zeit</th><th>Kategorie</th><th>Severity</th><th>Titel</th><th>Detail</th></tr></thead>
<tbody>
$timelineRowsHtml
</tbody></table>
</div>

<div class="card">
<h2>Trendanalyse über mehrere Tage</h2>
<table>
<thead><tr><th>Tag</th><th>Samples</th><th>Avg Risk</th><th>Max Risk</th><th>Alerts Total</th><th>Critical</th><th>High</th></tr></thead>
<tbody>
$trendRowsHtml
</tbody></table>
</div>

<div class="card">
<h2>Integritätsprüfung der AVA-Dateien selbst</h2>
<p>Status: <strong>$(HtmlEncode $Integrity.status)</strong></p>
<p>Added: $(HtmlEncode $integrityAdded)</p>
<p>Changed: $(HtmlEncode $integrityChanged)</p>
<p>Missing: $(HtmlEncode $integrityMissing)</p>
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
$integrity = Get-AvaFileIntegrity

if ($integrity.status -eq "CHANGED") {
    $alerts.Add([ordered]@{
        severity = "HIGH"
        type     = "AVA_INTEGRITY"
        message  = "Integritaetspruefung meldet AVA-Dateiabweichung."
        data     = $integrity
    })
}

$risk = Get-RiskAssessment -Alerts $alerts -Snapshot $snapshot -Integrity $integrity
$memory = Update-AvaMemory -Alerts $alerts
$processGraph = Get-ProcessGraph -Snapshot $snapshot

$timeline = New-Object System.Collections.Generic.List[object]
$timeline.Add((Add-TimelineEntry -Category "SYSTEM" -Severity "INFO" -Title "Snapshot erstellt" -Detail $snapshot.time)) | Out-Null
$timeline.Add((Add-TimelineEntry -Category "INTEGRITY" -Severity ($(if ($integrity.status -eq "OK") { "INFO" } else { "HIGH" })) -Title "AVA Integritaet" -Detail $integrity.status)) | Out-Null
$timeline.Add((Add-TimelineEntry -Category "RISK" -Severity $risk.level -Title "Risiko-Score" -Detail "Score=$($risk.score)")) | Out-Null
foreach ($a in $alerts) {
    $timeline.Add((Add-TimelineEntry -Category "ALERT" -Severity $a.severity -Title $a.type -Detail $a.message)) | Out-Null
}
foreach ($edge in (@($processGraph.edges) | Select-Object -First 25)) {
    if ($edge.relation -eq "process_network") {
        $timeline.Add((Add-TimelineEntry -Category "NETWORK" -Severity "INFO" -Title "ProcessNet Link" -Detail $edge.detail)) | Out-Null
    }
}

$trendEntries = Update-TrendState -Snapshot $snapshot -Alerts $alerts -Risk $risk
$trend = Get-TrendByDay -TrendEntries $trendEntries

Write-TangleEvent -Type "SNAPSHOT" -Severity "INFO" -Message "Snapshot erstellt." -Data @{
    powershell_count = @($snapshot.powershell).Count
    tcp_count        = @($snapshot.network.tcp).Count
    udp_count        = @($snapshot.network.udp).Count
    admin_count      = @($snapshot.admins).Count
    task_count       = @($snapshot.tasks).Count
    service_count    = @($snapshot.services).Count
    risk_score       = $risk.score
    risk_level       = $risk.level
    integrity_status = $integrity.status
    trend_samples    = @($trendEntries).Count
}

foreach ($a in $alerts) {
    $sev = if ($a.severity) { $a.severity } else { "LOW" }
    $typ = if ($a.type) { $a.type } else { "ALERT" }
    $msg = if ($a.message) { $a.message } else { "Alert ohne Meldung" }

    Write-TangleEvent -Type $typ -Severity $sev -Message $msg -Data @{
        alert = $a
    }
}

Build-Portal -Snapshot $snapshot -Alerts $alerts -Risk $risk -Timeline @($timeline) -Trend @($trend) -ProcessGraph $processGraph -Integrity $integrity -Memory $memory

Write-Host ""
Write-Host "AVA CORE STACK abgeschlossen." -ForegroundColor Cyan
Write-Host "Portal: $PortalFile" -ForegroundColor Green
Write-Host "Eventlog: $EventLog" -ForegroundColor Green
Write-Host "Alerts: $AlertLog" -ForegroundColor Green
Write-Host "Trend: $TrendFile" -ForegroundColor Green
Write-Host "Memory: $MemoryFile" -ForegroundColor Green
Write-Host "Integrity: $IntegrityFile" -ForegroundColor Green

if ($OpenPortal) {
    Start-Process $PortalFile
}
