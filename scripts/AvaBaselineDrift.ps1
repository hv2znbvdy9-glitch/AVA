#requires -Version 5.1
<#
AVA BASELINE DRIFT DETECTION
Defensiv / Lokal / Read-Only

- Kein Angriff
- Kein Exploit
- Keine Fremdscans
- Kein Auto-Spread

Ergänzung zu Ava314SafeLocalNode.ps1

Features:
- Erfasst einen signierten Baseline-Snapshot (Prozesse, TCP-Ports, Netzwerk-Nachbarn, Dienste)
- Vergleicht regelmäßig gegen gespeicherte Baseline
- Erkennt Drift: neue/entfernte Prozesse, neue Ports, neue Nachbarn, Dienststatus-Änderungen
- Signiert jeden Drift-Report mit SHA-256 Hash Chain (Tangle)
- Erzeugt HTML- und JSON-Report
#>

[CmdletBinding()]
param(
    [switch]$SaveBaseline,
    [switch]$Compare,
    [switch]$Loop,
    [int]$IntervalSeconds = 120
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$Root      = Join-Path $env:USERPROFILE 'Desktop\AVA_BASELINE_DRIFT'
$LogDir    = Join-Path $Root 'Logs'
$StateDir  = Join-Path $Root 'State'
$ReportDir = Join-Path $Root 'Reports'

$BaselinePath  = Join-Path $StateDir 'baseline_snapshot.json'
$DriftLog      = Join-Path $LogDir 'drift_history.jsonl'
$TangleLog     = Join-Path $LogDir 'drift_tangle.jsonl'
$TangleState   = Join-Path $StateDir 'drift_tangle_state.json'
$DriftHtml     = Join-Path $ReportDir 'ava_baseline_drift.html'
$DriftJson     = Join-Path $ReportDir 'ava_baseline_drift_latest.json'

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

    return $hash
}

# ---------------------------------------------------------------------------
# Snapshot collection
# ---------------------------------------------------------------------------

function Get-ProcessesSafe {
    try {
        @(Get-CimInstance Win32_Process | Select-Object ProcessId, ParentProcessId, Name, ExecutablePath)
    } catch {
        @([pscustomobject]@{ Error = $_.Exception.Message })
    }
}

function Get-ListeningPortsSafe {
    try {
        @(Get-NetTCPConnection -State Listen |
            Select-Object LocalAddress, LocalPort, State, OwningProcess |
            Sort-Object LocalPort)
    } catch {
        @([pscustomobject]@{ Error = $_.Exception.Message })
    }
}

function Get-NetworkNeighborsSafe {
    try {
        @(Get-NetNeighbor -AddressFamily IPv4 |
            Where-Object { $_.State -ne 'Unreachable' } |
            Select-Object InterfaceAlias, IPAddress, LinkLayerAddress, State)
    } catch {
        @([pscustomobject]@{ Error = $_.Exception.Message })
    }
}

function Get-ServicesSafe {
    try {
        @(Get-CimInstance Win32_Service |
            Where-Object { $_.State -eq 'Running' } |
            Select-Object Name, DisplayName, State, StartMode, StartName |
            Sort-Object Name)
    } catch {
        @([pscustomobject]@{ Error = $_.Exception.Message })
    }
}

function Get-AdaptersSafe {
    try {
        @(Get-NetAdapter | Select-Object Name, InterfaceDescription, Status, MacAddress, LinkSpeed)
    } catch {
        @([pscustomobject]@{ Error = $_.Exception.Message })
    }
}

function New-BaselineSnapshot {
    $snap = [ordered]@{
        time      = (Get-Date).ToString('o')
        computer  = $env:COMPUTERNAME
        user      = $env:USERNAME
        processes = Get-ProcessesSafe
        ports     = Get-ListeningPortsSafe
        neighbors = Get-NetworkNeighborsSafe
        services  = Get-ServicesSafe
        adapters  = Get-AdaptersSafe
    }

    # Sign the snapshot
    $raw  = $snap | ConvertTo-Json -Depth 30 -Compress
    $hash = Sha256Text -Text $raw
    $snap['signature'] = $hash

    return $snap
}

# ---------------------------------------------------------------------------
# Baseline persistence
# ---------------------------------------------------------------------------

function Save-Baseline {
    param([object]$Snapshot)
    $Snapshot | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $BaselinePath -Encoding UTF8
    Write-Host "Baseline gespeichert: $BaselinePath" -ForegroundColor Green
    Write-Host "Signatur: $($Snapshot.signature)" -ForegroundColor Yellow
}

function Load-Baseline {
    if (-not (Test-Path -LiteralPath $BaselinePath)) {
        return $null
    }
    try {
        return Get-Content -LiteralPath $BaselinePath -Raw | ConvertFrom-Json
    } catch {
        Write-Warning "Baseline konnte nicht geladen werden: $($_.Exception.Message)"
        return $null
    }
}

# ---------------------------------------------------------------------------
# Drift comparison
# ---------------------------------------------------------------------------

function Compare-Snapshots {
    param(
        [Parameter(Mandatory)][object]$Baseline,
        [Parameter(Mandatory)][object]$Current
    )

    $drift = [ordered]@{
        time             = (Get-Date).ToString('o')
        baseline_time    = [string]$Baseline.time
        current_time     = [string]$Current.time
        computer         = $env:COMPUTERNAME
        baseline_sig     = [string]$Baseline.signature
        current_sig      = [string]$Current.signature
        has_drift        = $false
        new_processes    = @()
        removed_processes = @()
        new_ports        = @()
        removed_ports    = @()
        new_neighbors    = @()
        removed_neighbors = @()
        new_services     = @()
        removed_services = @()
        changed_services = @()
        drift_score      = 0
    }

    # --- Processes ---
    $baseProcs    = @($Baseline.processes | Where-Object { $_.Name } | ForEach-Object { $_.Name })
    $currentProcs = @($Current.processes  | Where-Object { $_.Name } | ForEach-Object { $_.Name })

    $newProcs     = @($currentProcs | Where-Object { $baseProcs -notcontains $_ } | Select-Object -Unique)
    $removedProcs = @($baseProcs    | Where-Object { $currentProcs -notcontains $_ } | Select-Object -Unique)

    $drift.new_processes     = $newProcs
    $drift.removed_processes = $removedProcs
    $drift.drift_score      += $newProcs.Count * 5
    $drift.drift_score      += $removedProcs.Count * 3

    # --- Ports ---
    $basePorts    = @($Baseline.ports | Where-Object { $_.LocalPort } | ForEach-Object { "$($_.LocalAddress):$($_.LocalPort)" })
    $currentPorts = @($Current.ports  | Where-Object { $_.LocalPort } | ForEach-Object { "$($_.LocalAddress):$($_.LocalPort)" })

    $newPorts     = @($currentPorts | Where-Object { $basePorts -notcontains $_ })
    $removedPorts = @($basePorts    | Where-Object { $currentPorts -notcontains $_ })

    $drift.new_ports     = $newPorts
    $drift.removed_ports = $removedPorts
    $drift.drift_score  += $newPorts.Count * 15
    $drift.drift_score  += $removedPorts.Count * 5

    # --- Neighbors ---
    $baseNeigh    = @($Baseline.neighbors | Where-Object { $_.IPAddress } | ForEach-Object { "$($_.IPAddress)|$($_.LinkLayerAddress)" })
    $currentNeigh = @($Current.neighbors  | Where-Object { $_.IPAddress } | ForEach-Object { "$($_.IPAddress)|$($_.LinkLayerAddress)" })

    $newNeigh     = @($currentNeigh | Where-Object { $baseNeigh -notcontains $_ })
    $removedNeigh = @($baseNeigh    | Where-Object { $currentNeigh -notcontains $_ })

    $drift.new_neighbors     = $newNeigh
    $drift.removed_neighbors = $removedNeigh
    $drift.drift_score      += $newNeigh.Count * 20
    $drift.drift_score      += $removedNeigh.Count * 5

    # --- Services ---
    $baseSvcMap = @{}
    foreach ($s in @($Baseline.services | Where-Object { $_.Name })) {
        $baseSvcMap[[string]$s.Name] = [string]$s.State
    }
    $currentSvcMap = @{}
    foreach ($s in @($Current.services | Where-Object { $_.Name })) {
        $currentSvcMap[[string]$s.Name] = [string]$s.State
    }

    $newSvcs     = @($currentSvcMap.Keys | Where-Object { -not $baseSvcMap.ContainsKey($_) })
    $removedSvcs = @($baseSvcMap.Keys    | Where-Object { -not $currentSvcMap.ContainsKey($_) })
    $changedSvcs = @($currentSvcMap.Keys | Where-Object {
        $baseSvcMap.ContainsKey($_) -and $baseSvcMap[$_] -ne $currentSvcMap[$_]
    } | ForEach-Object {
        [pscustomobject]@{ Name = $_; OldState = $baseSvcMap[$_]; NewState = $currentSvcMap[$_] }
    })

    $drift.new_services     = $newSvcs
    $drift.removed_services = $removedSvcs
    $drift.changed_services = $changedSvcs
    $drift.drift_score     += $newSvcs.Count * 10
    $drift.drift_score     += $changedSvcs.Count * 20

    $drift.has_drift = (
        $newProcs.Count -gt 0 -or $removedProcs.Count -gt 0 -or
        $newPorts.Count -gt 0 -or $removedPorts.Count -gt 0 -or
        $newNeigh.Count -gt 0 -or $removedNeigh.Count -gt 0 -or
        $newSvcs.Count  -gt 0 -or $changedSvcs.Count  -gt 0
    )

    $drift.drift_score = [Math]::Min($drift.drift_score, 999)

    return $drift
}

# ---------------------------------------------------------------------------
# Report generator
# ---------------------------------------------------------------------------

function New-DriftReport {
    param([object]$Drift, [object]$Baseline, [object]$Current)

    $scoreColor = '#22c55e'
    if ($Drift.drift_score -ge 50)  { $scoreColor = '#eab308' }
    if ($Drift.drift_score -ge 150) { $scoreColor = '#f97316' }
    if ($Drift.drift_score -ge 300) { $scoreColor = '#ef4444' }

    $driftStatus = if ($Drift.has_drift) { 'DRIFT ERKANNT' } else { 'STABIL — Kein Drift' }
    $driftStatusColor = if ($Drift.has_drift) { '#f97316' } else { '#22c55e' }

    function List-Items {
        param([object[]]$Items, [string]$EmptyText = 'Keine Änderungen')
        if (-not $Items -or $Items.Count -eq 0) { return "<li style='color:#6b7280;'>$EmptyText</li>" }
        return ($Items | ForEach-Object { "<li><code>$(HtmlEncode $_)</code></li>" }) -join ''
    }

    function List-Changed {
        param([object[]]$Items)
        if (-not $Items -or $Items.Count -eq 0) { return "<li style='color:#6b7280;'>Keine Änderungen</li>" }
        return ($Items | ForEach-Object { "<li><code>$(HtmlEncode $_.Name)</code>: <span style='color:#ef4444;'>$(HtmlEncode $_.OldState)</span> → <span style='color:#22c55e;'>$(HtmlEncode $_.NewState)</span></li>" }) -join ''
    }

    $lastHash = 'N/A'
    if (Test-Path -LiteralPath $TangleState) {
        try { $lastHash = (Get-Content -LiteralPath $TangleState -Raw | ConvertFrom-Json).last_hash } catch {}
    }

    $Html = @"
<!doctype html>
<html lang="de">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>AVA Baseline Drift Detection</title>
<style>
:root { color-scheme: dark; --bg: #0f172a; --card: #111827; --line: #374151; --text: #f3f4f6; --muted: #9ca3af; --accent: #34d399; }
* { box-sizing: border-box; }
body { margin: 0; font-family: Segoe UI, Tahoma, Arial, sans-serif; background: radial-gradient(circle at top, #0f2a1a, var(--bg) 60%); color: var(--text); padding: 28px; line-height: 1.5; }
h1 { margin: 0 0 4px; }
.sub { color: var(--muted); margin: 0 0 18px; }
.stats { display: grid; grid-template-columns: repeat(auto-fit,minmax(160px,1fr)); gap: 10px; margin-bottom: 18px; }
.stat { background: var(--card); border: 1px solid var(--line); border-radius: 10px; padding: 10px 14px; }
.stat .k { font-size: 12px; color: var(--muted); }
.stat .v { font-size: 22px; font-weight: 700; color: var(--accent); }
.section { background: var(--card); border: 1px solid var(--line); border-radius: 12px; padding: 16px; margin-bottom: 18px; }
.section h2 { margin: 0 0 12px; font-size: 17px; }
.grid2 { display: grid; grid-template-columns: 1fr 1fr; gap: 14px; }
.drift-box { background: var(--card); border: 1px solid var(--line); border-radius: 10px; padding: 14px; }
.drift-box h3 { margin: 0 0 8px; font-size: 14px; color: var(--muted); }
ul { margin: 0; padding-left: 18px; }
li { padding: 3px 0; font-size: 13px; }
code { background: #1f2937; padding: 1px 5px; border-radius: 4px; font-size: 12px; }
footer { margin-top: 18px; font-size: 12px; color: var(--muted); }
</style>
</head>
<body>
<h1>AVA BASELINE DRIFT DETECTION</h1>
<p class="sub">Defensiv / Lokal / Read-Only &nbsp;·&nbsp; $(HtmlEncode $Current.computer) &nbsp;·&nbsp; $(HtmlEncode $Drift.current_time)</p>

<div class="stats">
  <div class="stat"><div class="k">Status</div><div class="v" style="font-size:14px;color:$driftStatusColor;">$driftStatus</div></div>
  <div class="stat"><div class="k">Drift Score</div><div class="v" style="color:$scoreColor;">$($Drift.drift_score)</div></div>
  <div class="stat"><div class="k">Neue Prozesse</div><div class="v">$(@($Drift.new_processes).Count)</div></div>
  <div class="stat"><div class="k">Neue Ports</div><div class="v">$(@($Drift.new_ports).Count)</div></div>
  <div class="stat"><div class="k">Neue Nachbarn</div><div class="v">$(@($Drift.new_neighbors).Count)</div></div>
  <div class="stat"><div class="k">Dienst-Änderungen</div><div class="v">$(@($Drift.changed_services).Count)</div></div>
  <div class="stat"><div class="k">Baseline-Zeit</div><div class="v" style="font-size:11px;word-break:break-word;">$(HtmlEncode $Drift.baseline_time)</div></div>
  <div class="stat"><div class="k">Tangle Hash</div><div class="v" style="font-size:11px;word-break:break-all;">$(HtmlEncode ($lastHash.Substring(0,[Math]::Min(16,$lastHash.Length))))…</div></div>
</div>

<div class="section">
<h2>Drift Details</h2>
<div class="grid2">
  <div class="drift-box">
    <h3>Neue Prozesse ($((@($Drift.new_processes)).Count))</h3>
    <ul>$(List-Items $Drift.new_processes)</ul>
  </div>
  <div class="drift-box">
    <h3>Entfernte Prozesse ($((@($Drift.removed_processes)).Count))</h3>
    <ul>$(List-Items $Drift.removed_processes)</ul>
  </div>
  <div class="drift-box">
    <h3>Neue offene Ports ($((@($Drift.new_ports)).Count))</h3>
    <ul>$(List-Items $Drift.new_ports)</ul>
  </div>
  <div class="drift-box">
    <h3>Geschlossene Ports ($((@($Drift.removed_ports)).Count))</h3>
    <ul>$(List-Items $Drift.removed_ports)</ul>
  </div>
  <div class="drift-box">
    <h3>Neue Netzwerk-Nachbarn ($((@($Drift.new_neighbors)).Count))</h3>
    <ul>$(List-Items $Drift.new_neighbors)</ul>
  </div>
  <div class="drift-box">
    <h3>Verschwundene Nachbarn ($((@($Drift.removed_neighbors)).Count))</h3>
    <ul>$(List-Items $Drift.removed_neighbors)</ul>
  </div>
  <div class="drift-box">
    <h3>Neue Dienste ($((@($Drift.new_services)).Count))</h3>
    <ul>$(List-Items $Drift.new_services)</ul>
  </div>
  <div class="drift-box">
    <h3>Dienststatus-Änderungen ($((@($Drift.changed_services)).Count))</h3>
    <ul>$(List-Changed $Drift.changed_services)</ul>
  </div>
</div>
</div>

<div class="section">
<h2>Signaturen &amp; Integrität</h2>
<ul>
  <li><strong>Baseline-Signatur:</strong> <code>$(HtmlEncode $Drift.baseline_sig)</code></li>
  <li><strong>Aktuell-Signatur:</strong> <code>$(HtmlEncode $Drift.current_sig)</code></li>
  <li><strong>Tangle Hash:</strong> <code>$(HtmlEncode $lastHash)</code></li>
</ul>
</div>

<footer>
  Report: <code>$(HtmlEncode $DriftHtml)</code> &nbsp;·&nbsp;
  JSON: <code>$(HtmlEncode $DriftJson)</code> &nbsp;·&nbsp;
  Drift-Log: <code>$(HtmlEncode $DriftLog)</code>
</footer>
</body>
</html>
"@

    $Html | Set-Content -LiteralPath $DriftHtml -Encoding UTF8
    Write-Host "Drift-Report gespeichert: $DriftHtml" -ForegroundColor Cyan
}

# ---------------------------------------------------------------------------
# Main run logic
# ---------------------------------------------------------------------------

function Invoke-SaveBaseline {
    Ensure-AllDirs
    Write-Host '[AVA Drift] Baseline-Snapshot wird erfasst...' -ForegroundColor Cyan
    $snap = New-BaselineSnapshot
    Save-Baseline -Snapshot $snap
    Write-Tangle -Type 'BASELINE_SAVED' -Summary "Computer=$($snap.computer) Processes=$(@($snap.processes).Count) Ports=$(@($snap.ports).Count)" -Data ([ordered]@{ processes = @($snap.processes).Count; ports = @($snap.ports).Count; neighbors = @($snap.neighbors).Count; services = @($snap.services).Count }) | Out-Null
    Write-Host "[AVA Drift] Prozesse: $(@($snap.processes).Count) | Ports: $(@($snap.ports).Count) | Nachbarn: $(@($snap.neighbors).Count) | Dienste: $(@($snap.services).Count)" -ForegroundColor Green
}

function Invoke-Compare {
    Ensure-AllDirs
    $baseline = Load-Baseline
    if ($null -eq $baseline) {
        Write-Host '[AVA Drift] Keine Baseline gefunden. Bitte zuerst -SaveBaseline ausführen.' -ForegroundColor Yellow
        Invoke-SaveBaseline
        return
    }

    Write-Host "[AVA Drift] Vergleiche mit Baseline vom $($baseline.time)..." -ForegroundColor Cyan
    $current = New-BaselineSnapshot
    $drift   = Compare-Snapshots -Baseline $baseline -Current $current

    # Persist drift report
    $drift | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $DriftJson -Encoding UTF8
    Write-JsonLine -Path $DriftLog -Object $drift

    Write-Tangle -Type 'DRIFT_REPORT' -Summary "Score=$($drift.drift_score) HasDrift=$($drift.has_drift)" -Data ([ordered]@{ score = $drift.drift_score; has_drift = $drift.has_drift; new_procs = @($drift.new_processes).Count; new_ports = @($drift.new_ports).Count; new_neighbors = @($drift.new_neighbors).Count }) | Out-Null

    New-DriftReport -Drift $drift -Baseline $baseline -Current $current

    if ($drift.has_drift) {
        Write-Host "[AVA Drift] DRIFT ERKANNT — Score: $($drift.drift_score)" -ForegroundColor Red
    } else {
        Write-Host "[AVA Drift] STABIL — Kein Drift erkannt. Score: $($drift.drift_score)" -ForegroundColor Green
    }
}

if ($Loop) {
    # First run: save baseline if none exists; then compare every interval
    Ensure-AllDirs
    if (-not (Test-Path -LiteralPath $BaselinePath)) {
        Invoke-SaveBaseline
    }
    while ($true) {
        Invoke-Compare
        Start-Sleep -Seconds $IntervalSeconds
    }
} elseif ($SaveBaseline) {
    Invoke-SaveBaseline
} else {
    # Default: compare (saves baseline on first run)
    Invoke-Compare
}
