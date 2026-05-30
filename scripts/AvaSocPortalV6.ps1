#requires -Version 5.1
<#
AVA SOC PORTAL V6 - SAFE GRAPH ENGINE
Defensiv / Lokal / Read-Only

- Kein Angriff
- Kein Exploit
- Kein Scan fremder Systeme
- Nur lokale Sichtbarkeit, Timeline, Heatmap, Anomalie-Erkennung

Features:
- Timeline Engine: Prozess-, Netzwerk- und Alertereignisse chronologisch verknüpft
- Top-Risk Heatmap: Priorisierte Risikoübersicht nach Schweregrad
- Historien-Delta: Vergleich mit letztem Snapshot
- HTML-Portal mit interaktiver Visualisierung
#>

[CmdletBinding()]
param(
    [switch]$RunOnce,
    [switch]$Loop,
    [int]$IntervalSeconds = 60
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root     = Join-Path $env:USERPROFILE 'Desktop\AVA_SOC_V6_GRAPH'
$LogDir   = Join-Path $Root 'Logs'
$StateDir = Join-Path $Root 'State'
$ReportDir = Join-Path $Root 'Reports'

$TimelineLog  = Join-Path $LogDir 'ava_v6_timeline.jsonl'
$AlertLog     = Join-Path $LogDir 'ava_v6_alerts.jsonl'
$TangleLog    = Join-Path $LogDir 'ava_v6_tangle.jsonl'
$TangleState  = Join-Path $StateDir 'ava_v6_tangle_state.json'
$BaselinePath = Join-Path $StateDir 'ava_v6_baseline.json'
$PortalHtml   = Join-Path $ReportDir 'ava_soc_portal_v6.html'

$RiskPorts = @(21, 23, 135, 139, 445, 3389, 5985, 5986)
$SuspiciousPatterns = @(
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

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

function Ensure-Dir {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Force -Path $Path | Out-Null
    }
}

function Ensure-AllDirs {
    foreach ($d in @($Root, $LogDir, $StateDir, $ReportDir)) {
        Ensure-Dir $d
    }
}

function HtmlEncode {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value) { return '' }
    return [System.Net.WebUtility]::HtmlEncode([string]$Value)
}

function Sha256Text {
    param([Parameter(Mandatory)][string]$Text)
    $sha   = [System.Security.Cryptography.SHA256]::Create()
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
    param([string]$Type, [string]$Summary, [object]$Data)

    $previousHash = $null
    if (Test-Path -LiteralPath $TangleState) {
        try { $previousHash = (Get-Content -LiteralPath $TangleState -Raw | ConvertFrom-Json).last_hash } catch {}
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

    $raw  = $event | ConvertTo-Json -Depth 30 -Compress
    $hash = Sha256Text -Text $raw
    $event['hash'] = $hash

    Write-JsonLine -Path $TangleLog -Object $event
    [ordered]@{ updated = (Get-Date).ToString('o'); last_hash = $hash } |
        ConvertTo-Json | Set-Content -LiteralPath $TangleState -Encoding UTF8
}

# ---------------------------------------------------------------------------
# Data collection
# ---------------------------------------------------------------------------

function Get-ProcessesSafe {
    try {
        Get-CimInstance Win32_Process |
            Select-Object ProcessId, ParentProcessId, Name, ExecutablePath, CommandLine
    } catch {
        @([pscustomobject]@{ Error = $_.Exception.Message })
    }
}

function Get-ConnectionsSafe {
    try {
        $byId = @{}
        Get-Process | ForEach-Object { $byId[$_.Id] = $_.ProcessName }

        Get-NetTCPConnection -State Established |
            Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, State, OwningProcess |
            ForEach-Object {
                [pscustomobject]@{
                    LocalAddress  = $_.LocalAddress
                    LocalPort     = $_.LocalPort
                    RemoteAddress = $_.RemoteAddress
                    RemotePort    = $_.RemotePort
                    State         = $_.State
                    PID           = $_.OwningProcess
                    Process       = $byId[$_.OwningProcess]
                }
            }
    } catch {
        @([pscustomobject]@{ Error = $_.Exception.Message })
    }
}

function Get-NetworkNeighborsSafe {
    try {
        Get-NetNeighbor -AddressFamily IPv4 |
            Where-Object { $_.State -ne 'Unreachable' } |
            Select-Object InterfaceAlias, IPAddress, LinkLayerAddress, State
    } catch {
        @([pscustomobject]@{ Error = $_.Exception.Message })
    }
}

function Get-WlanNetworksSafe {
    try {
        $raw = netsh wlan show networks mode=BSSID 2>&1 | Out-String
    } catch {
        return @([pscustomobject]@{ Error = $_.Exception.Message })
    }

    $items = New-Object System.Collections.Generic.List[object]
    $ssid  = $null; $auth = $null; $enc = $null

    foreach ($line in ($raw -split "`r?`n")) {
        $t = $line.Trim()
        if     ($t -match '^SSID\s+\d+\s+:\s+(.*)$')       { $ssid = $Matches[1]; $auth = $null; $enc = $null }
        elseif ($t -match '^Authentication\s+:\s+(.*)$')    { $auth = $Matches[1] }
        elseif ($t -match '^Encryption\s+:\s+(.*)$')        { $enc  = $Matches[1] }
        elseif ($t -match '^BSSID\s+\d+\s+:\s+(.*)$') {
            $items.Add([pscustomobject]@{
                SSID = $ssid; BSSID = $Matches[1]
                Authentication = $auth; Encryption = $enc; Signal = $null
            }) | Out-Null
        } elseif ($t -match '^Signal\s+:\s+(.*)$' -and $items.Count -gt 0) {
            $items[$items.Count - 1].Signal = $Matches[1]
        }
    }
    return $items
}

function New-Snapshot {
    [ordered]@{
        time        = (Get-Date).ToString('o')
        computer    = $env:COMPUTERNAME
        user        = $env:USERNAME
        processes   = Get-ProcessesSafe
        connections = Get-ConnectionsSafe
        neighbors   = Get-NetworkNeighborsSafe
        wlan        = Get-WlanNetworksSafe
    }
}

# ---------------------------------------------------------------------------
# Timeline Engine
# ---------------------------------------------------------------------------

function New-TimelineEvent {
    param(
        [Parameter(Mandatory)][string]$Category,
        [Parameter(Mandatory)][string]$Severity,
        [Parameter(Mandatory)][string]$Title,
        [string]$Detail = '',
        [object]$Data   = $null
    )

    $entry = [ordered]@{
        time     = (Get-Date).ToString('o')
        category = $Category
        severity = $Severity
        title    = $Title
        detail   = $Detail
        data     = $Data
    }
    Write-JsonLine -Path $TimelineLog -Object $entry
    return $entry
}

# ---------------------------------------------------------------------------
# Analysis + alert generation with timeline integration
# ---------------------------------------------------------------------------

function Analyze-Snapshot {
    param([object]$Snapshot)

    $alerts   = New-Object System.Collections.Generic.List[object]
    $timeline = New-Object System.Collections.Generic.List[object]
    $score    = 0

    # Timeline event: snapshot start
    $timeline.Add((New-TimelineEvent -Category 'SYSTEM' -Severity 'INFO' -Title 'Snapshot gestartet' -Detail "Host: $($Snapshot.computer)")) | Out-Null

    # Process analysis
    foreach ($proc in @($Snapshot.processes)) {
        $cmdLow = ''
        if ($proc.CommandLine) { $cmdLow = ([string]$proc.CommandLine).ToLowerInvariant() }

        if ($proc.Name -in @('powershell.exe', 'pwsh.exe', 'cmd.exe', 'wscript.exe', 'cscript.exe', 'mshta.exe', 'rundll32.exe', 'regsvr32.exe')) {
            $hits = @($SuspiciousPatterns | Where-Object { $cmdLow.Contains($_) })
            if ($hits.Count -gt 0) {
                $score += 85
                $a = [ordered]@{ time = (Get-Date).ToString('o'); severity = 'HIGH'; title = 'Suspicious Process'; message = "Verdächtige Kommandozeile: $($proc.Name)"; score = 85; data = [ordered]@{ process = $proc; hits = $hits } }
                $alerts.Add($a) | Out-Null
                Write-JsonLine -Path $AlertLog -Object $a
                $timeline.Add((New-TimelineEvent -Category 'PROCESS' -Severity 'HIGH' -Title 'Suspicious Process' -Detail $proc.Name -Data $proc)) | Out-Null
            }
        }
    }

    # Network analysis
    foreach ($conn in @($Snapshot.connections)) {
        if ($RiskPorts -contains [int]$conn.RemotePort) {
            $sev   = if ($conn.RemotePort -in @(445, 3389, 5985, 5986)) { 'HIGH' } else { 'MEDIUM' }
            $pts   = if ($sev -eq 'HIGH') { 75 } else { 45 }
            $score += $pts
            $a = [ordered]@{ time = (Get-Date).ToString('o'); severity = $sev; title = 'Risk Port Connection'; message = "Verbindung zu Risiko-Port $($conn.RemotePort) durch $($conn.Process)"; score = $pts; data = $conn }
            $alerts.Add($a) | Out-Null
            Write-JsonLine -Path $AlertLog -Object $a
            $timeline.Add((New-TimelineEvent -Category 'NETWORK' -Severity $sev -Title "Risk Port $($conn.RemotePort)" -Detail "$($conn.Process) -> $($conn.RemoteAddress):$($conn.RemotePort)" -Data $conn)) | Out-Null
        }
    }

    # Baseline delta
    $delta = [ordered]@{ baseline_exists = $false; new_neighbors = @(); new_wlan_bssid = @(); new_processes = @() }

    if (Test-Path -LiteralPath $BaselinePath) {
        $delta.baseline_exists = $true
        try {
            $base = Get-Content -LiteralPath $BaselinePath -Raw | ConvertFrom-Json

            # New neighbors
            $oldNeighbors = @($base.neighbors | ForEach-Object { "$($_.IPAddress)|$($_.LinkLayerAddress)" })
            foreach ($n in @($Snapshot.neighbors)) {
                $key = "$($n.IPAddress)|$($n.LinkLayerAddress)"
                if ($n.IPAddress -and ($oldNeighbors -notcontains $key)) {
                    $delta.new_neighbors += $n
                    $score += 25
                    $timeline.Add((New-TimelineEvent -Category 'NETWORK' -Severity 'MEDIUM' -Title 'Neuer Netzwerk-Nachbar' -Detail "$($n.IPAddress) [$($n.LinkLayerAddress)]" -Data $n)) | Out-Null
                }
            }

            # New WLAN BSSIDs
            $oldBssid = @($base.wlan | ForEach-Object { $_.BSSID })
            foreach ($w in @($Snapshot.wlan)) {
                if ($w.BSSID -and ($oldBssid -notcontains $w.BSSID)) {
                    $delta.new_wlan_bssid += $w
                    $score += 10
                    $timeline.Add((New-TimelineEvent -Category 'WLAN' -Severity 'LOW' -Title 'Neues WLAN erkannt' -Detail "$($w.SSID) [$($w.BSSID)]" -Data $w)) | Out-Null
                }
            }

            # New processes (by name)
            $oldProcNames = @($base.processes | ForEach-Object { $_.Name })
            foreach ($p in @($Snapshot.processes)) {
                if ($p.Name -and ($oldProcNames -notcontains $p.Name)) {
                    $delta.new_processes += $p.Name
                    $timeline.Add((New-TimelineEvent -Category 'PROCESS' -Severity 'INFO' -Title 'Neuer Prozess' -Detail $p.Name -Data $p)) | Out-Null
                }
            }
        } catch {}
    } else {
        $Snapshot | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $BaselinePath -Encoding UTF8
        $timeline.Add((New-TimelineEvent -Category 'SYSTEM' -Severity 'INFO' -Title 'Baseline gespeichert' -Detail $BaselinePath)) | Out-Null
    }

    return [ordered]@{
        score    = [Math]::Min($score, 999)
        alerts   = $alerts
        timeline = $timeline
        delta    = $delta
    }
}

# ---------------------------------------------------------------------------
# Heatmap builder
# ---------------------------------------------------------------------------

function Build-HeatmapHtml {
    param([object[]]$Alerts)

    $categories = @('PROCESS', 'NETWORK', 'WLAN', 'SYSTEM')
    $severities = @('CRITICAL', 'HIGH', 'MEDIUM', 'LOW', 'INFO')

    $matrix = @{}
    foreach ($cat in $categories) {
        foreach ($sev in $severities) {
            $matrix["$cat|$sev"] = 0
        }
    }

    foreach ($a in @($Alerts)) {
        $sev = [string]$a.severity
        $cat = if ($a.title -like '*Process*' -or $a.title -like '*Command*') { 'PROCESS' }
               elseif ($a.title -like '*Port*' -or $a.title -like '*Neighbor*') { 'NETWORK' }
               elseif ($a.title -like '*WLAN*' -or $a.title -like '*Wifi*') { 'WLAN' }
               else { 'SYSTEM' }
        $key = "$cat|$sev"
        if ($matrix.ContainsKey($key)) { $matrix[$key]++ }
    }

    $colorMap = @{
        'CRITICAL' = '#ef4444'
        'HIGH'     = '#f97316'
        'MEDIUM'   = '#eab308'
        'LOW'      = '#22c55e'
        'INFO'     = '#3b82f6'
    }

    $header = '<th>Kategorie</th>' + ($severities | ForEach-Object { "<th>$_</th>" } | Out-String).Replace("`r`n","").Replace("`n","")
    $rows = foreach ($cat in $categories) {
        $cells = foreach ($sev in $severities) {
            $count = $matrix["$cat|$sev"]
            $bg    = if ($count -gt 0) { $colorMap[$sev] } else { '#1f2937' }
            $opacity = if ($count -gt 0) { [Math]::Min(0.3 + $count * 0.15, 1.0) } else { 1.0 }
            "<td style='background:$bg;opacity:$opacity;text-align:center;font-weight:700;color:#fff;'>$count</td>"
        }
        "<tr><td style='font-weight:600;padding:8px 12px;'>$cat</td>$($cells -join '')</tr>"
    }

    return @"
<table class="heatmap">
<thead><tr>$header</tr></thead>
<tbody>
$($rows -join "`n")
</tbody>
</table>
"@
}

# ---------------------------------------------------------------------------
# Timeline HTML builder
# ---------------------------------------------------------------------------

function Build-TimelineHtml {
    param([object[]]$Events)

    $colorMap = @{
        'CRITICAL' = '#ef4444'
        'HIGH'     = '#f97316'
        'MEDIUM'   = '#eab308'
        'LOW'      = '#22c55e'
        'INFO'     = '#3b82f6'
    }

    $items = foreach ($e in ($Events | Select-Object -Last 100)) {
        $sev   = [string]$e.severity
        $color = if ($colorMap.ContainsKey($sev)) { $colorMap[$sev] } else { '#6b7280' }
        $ts    = try { ([datetime]$e.time).ToString('HH:mm:ss') } catch { [string]$e.time }
@"
<div class="tl-item">
  <div class="tl-dot" style="background:$color;"></div>
  <div class="tl-body">
    <span class="tl-time">$ts</span>
    <span class="tl-sev" style="color:$color;">$(HtmlEncode $sev)</span>
    <span class="tl-cat">[$(HtmlEncode $e.category)]</span>
    <strong>$(HtmlEncode $e.title)</strong>
    <span class="tl-detail">$(HtmlEncode $e.detail)</span>
  </div>
</div>
"@
    }

    return "<div class='timeline'>$($items -join '')</div>"
}

# ---------------------------------------------------------------------------
# Portal HTML generator
# ---------------------------------------------------------------------------

function New-Portal {
    param([object]$Snapshot, [object]$Analysis)

    $score   = $Analysis.score
    $health  = 'OK'
    if ($score -ge 150) { $health = 'WARN' }
    if ($score -ge 300) { $health = 'HIGH' }
    if ($score -ge 500) { $health = 'CRITICAL' }

    $healthColor = @{ 'OK' = '#22c55e'; 'WARN' = '#eab308'; 'HIGH' = '#f97316'; 'CRITICAL' = '#ef4444' }[$health]

    $lastHash = 'N/A'
    if (Test-Path -LiteralPath $TangleState) {
        try { $lastHash = (Get-Content -LiteralPath $TangleState -Raw | ConvertFrom-Json).last_hash } catch {}
    }

    $alertRows = foreach ($a in @($Analysis.alerts | Sort-Object score -Descending | Select-Object -First 50)) {
        $sev = [string]$a.severity
        $sevColor = @{ 'CRITICAL' = '#ef4444'; 'HIGH' = '#f97316'; 'MEDIUM' = '#eab308'; 'LOW' = '#22c55e'; 'INFO' = '#3b82f6' }
        $c = if ($sevColor.ContainsKey($sev)) { $sevColor[$sev] } else { '#9ca3af' }
        "<tr><td style='color:$c;font-weight:700;'>$(HtmlEncode $sev)</td><td>$(HtmlEncode $a.title)</td><td>$(HtmlEncode $a.message)</td><td style='text-align:right;'>$(HtmlEncode $a.score)</td></tr>"
    }

    $heatmapHtml  = Build-HeatmapHtml  -Alerts   @($Analysis.alerts)
    $timelineHtml = Build-TimelineHtml -Events @($Analysis.timeline)

    $newNeighborCount = @($Analysis.delta.new_neighbors).Count
    $newWlanCount     = @($Analysis.delta.new_wlan_bssid).Count
    $newProcCount     = @($Analysis.delta.new_processes).Count

    $Html = @"
<!doctype html>
<html lang="de">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>AVA SOC Portal V6 — Safe Graph Engine</title>
<style>
:root { color-scheme: dark; --bg: #0f172a; --card: #111827; --line: #374151; --text: #f3f4f6; --muted: #9ca3af; --accent: #38bdf8; }
* { box-sizing: border-box; }
body { margin: 0; font-family: Segoe UI, Tahoma, Arial, sans-serif; background: radial-gradient(circle at top, #1e293b, var(--bg) 60%); color: var(--text); padding: 28px; line-height: 1.5; }
h1 { margin: 0 0 4px; }
.sub { color: var(--muted); margin: 0 0 18px; }
.stats { display: grid; grid-template-columns: repeat(auto-fit,minmax(160px,1fr)); gap: 10px; margin-bottom: 18px; }
.stat { background: var(--card); border: 1px solid var(--line); border-radius: 10px; padding: 10px 14px; }
.stat .k { font-size: 12px; color: var(--muted); }
.stat .v { font-size: 22px; font-weight: 700; color: var(--accent); }
.section { background: var(--card); border: 1px solid var(--line); border-radius: 12px; padding: 16px; margin-bottom: 18px; }
.section h2 { margin: 0 0 12px; font-size: 17px; }
table { width: 100%; border-collapse: collapse; font-size: 13px; }
th { text-align: left; color: var(--muted); border-bottom: 1px solid var(--line); padding: 6px 8px; }
td { padding: 6px 8px; border-bottom: 1px solid #1f2937; word-break: break-word; }
.heatmap td, .heatmap th { border: 1px solid #1f2937; padding: 10px 14px; }
.heatmap thead { background: #1f2937; }
.timeline { display: flex; flex-direction: column; gap: 8px; max-height: 420px; overflow-y: auto; }
.tl-item { display: flex; align-items: flex-start; gap: 10px; }
.tl-dot { width: 10px; height: 10px; border-radius: 50%; margin-top: 4px; flex-shrink: 0; }
.tl-body { font-size: 13px; display: flex; flex-wrap: wrap; gap: 6px; align-items: baseline; }
.tl-time { color: var(--muted); font-size: 11px; }
.tl-sev { font-weight: 700; font-size: 11px; }
.tl-cat { color: var(--muted); font-size: 11px; }
.tl-detail { color: var(--muted); font-size: 12px; }
footer { margin-top: 18px; font-size: 12px; color: var(--muted); }
code { background: #1f2937; padding: 1px 5px; border-radius: 4px; }
</style>
</head>
<body>
<h1>AVA SOC PORTAL V6 — SAFE GRAPH ENGINE</h1>
<p class="sub">Defensiv / Lokal / Read-Only &nbsp;·&nbsp; $(HtmlEncode $Snapshot.computer) &nbsp;·&nbsp; $(HtmlEncode $Snapshot.time)</p>

<div class="stats">
  <div class="stat"><div class="k">Risk Score</div><div class="v" style="color:$healthColor;">$score</div></div>
  <div class="stat"><div class="k">Health</div><div class="v" style="color:$healthColor;">$health</div></div>
  <div class="stat"><div class="k">Alerts</div><div class="v">$(@($Analysis.alerts).Count)</div></div>
  <div class="stat"><div class="k">Timeline Events</div><div class="v">$(@($Analysis.timeline).Count)</div></div>
  <div class="stat"><div class="k">Neue Nachbarn</div><div class="v">$newNeighborCount</div></div>
  <div class="stat"><div class="k">Neue WLANs</div><div class="v">$newWlanCount</div></div>
  <div class="stat"><div class="k">Neue Prozesse</div><div class="v">$newProcCount</div></div>
  <div class="stat"><div class="k">Tangle Hash</div><div class="v" style="font-size:11px;word-break:break-all;">$(HtmlEncode ($lastHash.Substring(0, [Math]::Min(16, $lastHash.Length))))…</div></div>
</div>

<div class="section">
<h2>Top-Risk Heatmap</h2>
$heatmapHtml
</div>

<div class="section">
<h2>Timeline Engine</h2>
$timelineHtml
</div>

<div class="section">
<h2>Alerts (Top 50)</h2>
<table>
<thead><tr><th>Severity</th><th>Titel</th><th>Meldung</th><th style="text-align:right;">Score</th></tr></thead>
<tbody>
$($alertRows -join "`n")
</tbody>
</table>
</div>

<footer>
  Portal: <code>$(HtmlEncode $PortalHtml)</code> &nbsp;·&nbsp;
  Timeline-Log: <code>$(HtmlEncode $TimelineLog)</code> &nbsp;·&nbsp;
  Alert-Log: <code>$(HtmlEncode $AlertLog)</code>
</footer>
</body>
</html>
"@

    $Html | Set-Content -LiteralPath $PortalHtml -Encoding UTF8
    Write-Host "Portal gespeichert: $PortalHtml" -ForegroundColor Cyan
}

# ---------------------------------------------------------------------------
# Main run logic
# ---------------------------------------------------------------------------

function Invoke-Run {
    Ensure-AllDirs

    Write-Host '[AVA V6] Snapshot wird erfasst...' -ForegroundColor Cyan
    $snap     = New-Snapshot
    $analysis = Analyze-Snapshot -Snapshot $snap

    Write-Tangle -Type 'SNAPSHOT' -Summary "Score=$($analysis.score) Alerts=$(@($analysis.alerts).Count)" -Data ([ordered]@{ score = $analysis.score; alert_count = @($analysis.alerts).Count })

    New-Portal -Snapshot $snap -Analysis $analysis

    Write-Host "[AVA V6] Risk Score: $($analysis.score) | Alerts: $(@($analysis.alerts).Count) | Timeline: $(@($analysis.timeline).Count) Events" -ForegroundColor Green
}

if ($Loop) {
    while ($true) {
        Invoke-Run
        Start-Sleep -Seconds $IntervalSeconds
    }
} else {
    Invoke-Run
}
