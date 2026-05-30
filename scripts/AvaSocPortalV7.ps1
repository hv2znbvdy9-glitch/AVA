#requires -Version 5.1
<#
AVA SOC PORTAL V7 - SAFE MEMORY LAYER
Defensiv / Lokal / Read-Only

- Kein Angriff
- Kein Exploit
- Keine Fremdscans

Features:
- Lädt existierende Alert-Logs (JSONL) und korreliert sie mit Prozess-/Netzwerk-Snapshots
- Tagging-System: automatische und manuelle Tags pro Event
- Korrelations-Engine: verknüpft Alerts nach Zeit, Prozess, IP und Schweregrad
- Export: JSON-Dump und HTML-Portal
#>

[CmdletBinding()]
param(
    [switch]$RunOnce,
    [switch]$Loop,
    [int]$IntervalSeconds = 60,
    [string]$AlertLogImport = '',
    [string]$ExportJson     = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root      = Join-Path $env:USERPROFILE 'Desktop\AVA_SOC_V7_MEMORY'
$LogDir    = Join-Path $Root 'Logs'
$StateDir  = Join-Path $Root 'State'
$ReportDir = Join-Path $Root 'Reports'

$AlertLog     = Join-Path $LogDir 'ava_v7_alerts.jsonl'
$MemoryStore  = Join-Path $StateDir 'ava_v7_memory.json'
$TangleLog    = Join-Path $LogDir 'ava_v7_tangle.jsonl'
$TangleState  = Join-Path $StateDir 'ava_v7_tangle_state.json'
$PortalHtml   = Join-Path $ReportDir 'ava_soc_portal_v7.html'
$ExportPath   = if ($ExportJson) { $ExportJson } else { Join-Path $ReportDir 'ava_v7_export.json' }

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
# Tagging Engine
# ---------------------------------------------------------------------------

$TagRules = @(
    @{ Pattern = '*CRITICAL*';          Tag = 'critical' }
    @{ Pattern = '*HIGH*';              Tag = 'high-severity' }
    @{ Pattern = '*Suspicious*';        Tag = 'suspicious-process' }
    @{ Pattern = '*Risk Port*';         Tag = 'risk-port' }
    @{ Pattern = '*powershell*';        Tag = 'powershell' }
    @{ Pattern = '*pwsh*';              Tag = 'powershell' }
    @{ Pattern = '*Defender*';          Tag = 'defender' }
    @{ Pattern = '*Firewall*';          Tag = 'firewall' }
    @{ Pattern = '*Admin*';             Tag = 'admin-change' }
    @{ Pattern = '*WLAN*';              Tag = 'wlan' }
    @{ Pattern = '*Neighbor*';          Tag = 'network-neighbor' }
    @{ Pattern = '*3389*';              Tag = 'rdp' }
    @{ Pattern = '*445*';               Tag = 'smb' }
    @{ Pattern = '*5985*';              Tag = 'winrm' }
    @{ Pattern = '*5986*';              Tag = 'winrm-https' }
)

function Get-AutoTags {
    param([object]$Alert)

    $combined = "$($Alert.severity) $($Alert.title) $($Alert.message)"
    $tags = New-Object System.Collections.Generic.List[string]

    foreach ($rule in $TagRules) {
        if ($combined -like $rule.Pattern) {
            if (-not $tags.Contains($rule.Tag)) {
                $tags.Add($rule.Tag) | Out-Null
            }
        }
    }

    # Score-based tags
    if ([int]$Alert.score -ge 80) { if (-not $tags.Contains('high-score')) { $tags.Add('high-score') | Out-Null } }
    if ([int]$Alert.score -ge 50) { if (-not $tags.Contains('medium-score')) { $tags.Add('medium-score') | Out-Null } }

    return @($tags)
}

# ---------------------------------------------------------------------------
# Correlation Engine
# ---------------------------------------------------------------------------

function Get-CorrelationGroups {
    param([object[]]$Alerts)

    $groups = @{}

    foreach ($a in @($Alerts)) {
        # Group by normalized title
        $key = [string]$a.title
        if (-not $groups.ContainsKey($key)) {
            $groups[$key] = New-Object System.Collections.Generic.List[object]
        }
        $groups[$key].Add($a) | Out-Null
    }

    $result = foreach ($k in $groups.Keys) {
        $items     = @($groups[$k])
        $maxScore  = ($items | Measure-Object -Property score -Maximum).Maximum
        $minTime   = ($items.time | Sort-Object | Select-Object -First 1)
        $maxTime   = ($items.time | Sort-Object | Select-Object -Last 1)
        $allTags   = @($items | ForEach-Object { $_.tags } | Select-Object -Unique)

        [ordered]@{
            title       = $k
            count       = $items.Count
            max_score   = $maxScore
            first_seen  = $minTime
            last_seen   = $maxTime
            severities  = @($items.severity | Select-Object -Unique)
            tags        = $allTags
        }
    }

    return @($result | Sort-Object max_score -Descending)
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

function New-Snapshot {
    [ordered]@{
        time        = (Get-Date).ToString('o')
        computer    = $env:COMPUTERNAME
        user        = $env:USERNAME
        processes   = Get-ProcessesSafe
        connections = Get-ConnectionsSafe
    }
}

# ---------------------------------------------------------------------------
# Memory Layer: load, enrich, persist
# ---------------------------------------------------------------------------

function Load-Memory {
    if (Test-Path -LiteralPath $MemoryStore) {
        try {
            return @(Get-Content -LiteralPath $MemoryStore -Raw | ConvertFrom-Json)
        } catch {}
    }
    return @()
}

function Save-Memory {
    param([object[]]$Entries)
    $Entries | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $MemoryStore -Encoding UTF8
}

function Add-MemoryEntry {
    param(
        [Parameter(Mandatory)][object]$Alert,
        [object[]]$Memory,
        [string]$SnapshotTime
    )

    $id   = Sha256Text -Text "$($Alert.time)$($Alert.title)$($Alert.message)"
    $tags = Get-AutoTags -Alert $Alert

    # Correlate with snapshot processes if data contains process name
    $linkedProcess = $null
    if ($Alert.data -and $Alert.data.Name) {
        $linkedProcess = [string]$Alert.data.Name
    } elseif ($Alert.data -and $Alert.data.process -and $Alert.data.process.Name) {
        $linkedProcess = [string]$Alert.data.process.Name
    }

    $entry = [ordered]@{
        id             = $id
        ingested_at    = (Get-Date).ToString('o')
        snapshot_time  = $SnapshotTime
        alert          = $Alert
        tags           = $tags
        linked_process = $linkedProcess
        correlation_id = ($Alert.title -replace '\s', '_').ToLowerInvariant()
    }

    return $entry
}

function Import-AlertLog {
    param([string]$Path)

    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) {
        return @()
    }

    $entries = New-Object System.Collections.Generic.List[object]
    foreach ($line in (Get-Content -LiteralPath $Path)) {
        $line = $line.Trim()
        if ($line) {
            try {
                $entries.Add(($line | ConvertFrom-Json)) | Out-Null
            } catch {}
        }
    }

    return @($entries)
}

function Build-CurrentAlerts {
    param([object]$Snapshot)

    $alerts = New-Object System.Collections.Generic.List[object]

    foreach ($proc in @($Snapshot.processes)) {
        $cmdLow = ''
        if ($proc.CommandLine) { $cmdLow = ([string]$proc.CommandLine).ToLowerInvariant() }

        if ($proc.Name -in @('powershell.exe', 'pwsh.exe', 'cmd.exe', 'wscript.exe', 'cscript.exe', 'mshta.exe', 'rundll32.exe', 'regsvr32.exe')) {
            $hits = @($SuspiciousPatterns | Where-Object { $cmdLow.Contains($_) })
            if ($hits.Count -gt 0) {
                $alerts.Add([ordered]@{
                    time     = (Get-Date).ToString('o')
                    severity = 'HIGH'
                    title    = 'Suspicious Process'
                    message  = "Verdächtige Kommandozeile: $($proc.Name)"
                    score    = 85
                    data     = [ordered]@{ process = $proc; hits = $hits }
                }) | Out-Null
            }
        }
    }

    foreach ($conn in @($Snapshot.connections)) {
        if ($RiskPorts -contains [int]$conn.RemotePort) {
            $sev = if ($conn.RemotePort -in @(445, 3389, 5985, 5986)) { 'HIGH' } else { 'MEDIUM' }
            $pts = if ($sev -eq 'HIGH') { 75 } else { 45 }
            $alerts.Add([ordered]@{
                time     = (Get-Date).ToString('o')
                severity = $sev
                title    = 'Risk Port Connection'
                message  = "Verbindung zu Risiko-Port $($conn.RemotePort) durch $($conn.Process)"
                score    = $pts
                data     = $conn
            }) | Out-Null
        }
    }

    return @($alerts)
}

# ---------------------------------------------------------------------------
# Portal HTML generator
# ---------------------------------------------------------------------------

function New-Portal {
    param(
        [object[]]$MemoryEntries,
        [object[]]$CorrelationGroups,
        [object]$Snapshot
    )

    $totalAlerts  = $MemoryEntries.Count
    $uniqueTitles = @($CorrelationGroups).Count
    $allTags      = @($MemoryEntries | ForEach-Object { $_.tags } | Where-Object { $_ } | Select-Object -Unique | Sort-Object)

    $tagCloud = ($allTags | ForEach-Object { "<span class='tag'>$(HtmlEncode $_)</span>" }) -join ' '

    $corrRows = foreach ($g in ($CorrelationGroups | Select-Object -First 30)) {
        $tagsText = ($g.tags | Where-Object { $_ }) -join ', '
        $sevs     = ($g.severities | Where-Object { $_ }) -join ', '
        "<tr><td>$(HtmlEncode $g.title)</td><td style='text-align:center;'>$(HtmlEncode $g.count)</td><td style='text-align:right;font-weight:700;'>$(HtmlEncode $g.max_score)</td><td>$sevs</td><td>$(HtmlEncode $tagsText)</td><td>$(HtmlEncode $g.first_seen)</td></tr>"
    }

    $memRows = foreach ($e in ($MemoryEntries | Sort-Object { $_.alert.score } -Descending | Select-Object -First 50)) {
        $tagsHtml = ($e.tags | ForEach-Object { "<span class='tag'>$(HtmlEncode $_)</span>" }) -join ' '
        $linked   = if ($e.linked_process) { HtmlEncode $e.linked_process } else { '<span style="color:#6b7280;">—</span>' }
        "<tr><td>$(HtmlEncode $e.alert.time)</td><td>$(HtmlEncode $e.alert.severity)</td><td>$(HtmlEncode $e.alert.title)</td><td>$(HtmlEncode $e.alert.message)</td><td style='text-align:right;font-weight:700;'>$(HtmlEncode $e.alert.score)</td><td>$linked</td><td>$tagsHtml</td></tr>"
    }

    $Html = @"
<!doctype html>
<html lang="de">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>AVA SOC Portal V7 — Safe Memory Layer</title>
<style>
:root { color-scheme: dark; --bg: #0f172a; --card: #111827; --line: #374151; --text: #f3f4f6; --muted: #9ca3af; --accent: #a78bfa; }
* { box-sizing: border-box; }
body { margin: 0; font-family: Segoe UI, Tahoma, Arial, sans-serif; background: radial-gradient(circle at top, #1e0f3a, var(--bg) 60%); color: var(--text); padding: 28px; line-height: 1.5; }
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
td { padding: 6px 8px; border-bottom: 1px solid #1f2937; word-break: break-word; vertical-align: top; }
.tag { font-size: 11px; padding: 2px 7px; border-radius: 999px; background: rgba(167,139,250,0.15); color: #c4b5fd; border: 1px solid rgba(167,139,250,0.35); display: inline-block; margin: 1px; }
.tag-cloud { margin-bottom: 12px; }
footer { margin-top: 18px; font-size: 12px; color: var(--muted); }
code { background: #1f2937; padding: 1px 5px; border-radius: 4px; }
</style>
</head>
<body>
<h1>AVA SOC PORTAL V7 — SAFE MEMORY LAYER</h1>
<p class="sub">Defensiv / Lokal / Read-Only &nbsp;·&nbsp; $(HtmlEncode $Snapshot.computer) &nbsp;·&nbsp; $(HtmlEncode $Snapshot.time)</p>

<div class="stats">
  <div class="stat"><div class="k">Memory Einträge</div><div class="v">$totalAlerts</div></div>
  <div class="stat"><div class="k">Korrelationsgruppen</div><div class="v">$uniqueTitles</div></div>
  <div class="stat"><div class="k">Unique Tags</div><div class="v">$($allTags.Count)</div></div>
</div>

<div class="section">
<h2>Tag Cloud</h2>
<div class="tag-cloud">$tagCloud</div>
</div>

<div class="section">
<h2>Korrelationsgruppen</h2>
<table>
<thead><tr><th>Alert-Typ</th><th>Anzahl</th><th style="text-align:right;">Max Score</th><th>Schweregrade</th><th>Tags</th><th>Erstes Auftreten</th></tr></thead>
<tbody>
$($corrRows -join "`n")
</tbody>
</table>
</div>

<div class="section">
<h2>Memory Store — Alle Einträge (Top 50 nach Score)</h2>
<table>
<thead><tr><th>Zeit</th><th>Severity</th><th>Titel</th><th>Meldung</th><th style="text-align:right;">Score</th><th>Prozess</th><th>Tags</th></tr></thead>
<tbody>
$($memRows -join "`n")
</tbody>
</table>
</div>

<footer>
  Portal: <code>$(HtmlEncode $PortalHtml)</code> &nbsp;·&nbsp;
  Memory Store: <code>$(HtmlEncode $MemoryStore)</code> &nbsp;·&nbsp;
  Export: <code>$(HtmlEncode $ExportPath)</code>
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

    Write-Host '[AVA V7] Snapshot + Memory Layer wird aufgebaut...' -ForegroundColor Cyan

    $snap = New-Snapshot

    # Build current alerts from live snapshot
    $liveAlerts = Build-CurrentAlerts -Snapshot $snap

    # Optionally import external alert log
    $importedAlerts = @()
    if ($AlertLogImport) {
        $importedAlerts = Import-AlertLog -Path $AlertLogImport
        Write-Host "[AVA V7] $($importedAlerts.Count) Alerts aus '$AlertLogImport' importiert." -ForegroundColor Yellow
    }

    $allAlerts = @($liveAlerts) + @($importedAlerts)

    # Load existing memory and add new entries
    $memory = [System.Collections.Generic.List[object]]@(Load-Memory)
    $existingIds = @($memory | ForEach-Object { $_.id })

    foreach ($a in @($allAlerts)) {
        $entry = Add-MemoryEntry -Alert $a -Memory @($memory) -SnapshotTime $snap.time
        if ($existingIds -notcontains $entry.id) {
            $memory.Add($entry) | Out-Null
            Write-JsonLine -Path $AlertLog -Object $entry.alert
        }
    }

    Save-Memory -Entries @($memory)

    # Correlation
    $corrGroups = Get-CorrelationGroups -Alerts @($memory | ForEach-Object { $_.alert })

    # Export JSON
    [ordered]@{
        exported_at        = (Get-Date).ToString('o')
        computer           = $env:COMPUTERNAME
        memory_count       = $memory.Count
        correlation_groups = $corrGroups
        entries            = @($memory)
    } | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $ExportPath -Encoding UTF8

    Write-Tangle -Type 'MEMORY_SNAPSHOT' -Summary "Entries=$($memory.Count) Groups=$($corrGroups.Count)" -Data ([ordered]@{ count = $memory.Count; groups = $corrGroups.Count })

    New-Portal -MemoryEntries @($memory) -CorrelationGroups $corrGroups -Snapshot $snap

    Write-Host "[AVA V7] Memory: $($memory.Count) Einträge | Gruppen: $($corrGroups.Count)" -ForegroundColor Green
    Write-Host "[AVA V7] Export: $ExportPath" -ForegroundColor Yellow
}

if ($Loop) {
    while ($true) {
        Invoke-Run
        Start-Sleep -Seconds $IntervalSeconds
    }
} else {
    Invoke-Run
}
