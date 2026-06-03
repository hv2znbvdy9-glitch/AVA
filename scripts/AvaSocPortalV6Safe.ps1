#requires -Version 5.1
<#
AVA SOC PORTAL V6 SAFE EDITION
Lokal / Defensiv / Read-Only

Keine Angriffe
Keine Exploits
Keine Fremdscans
Keine automatische Ausbreitung
Keine Änderungen am System

Funktionen:
- Host / MAC / IP Monitoring
- WLAN / LAN Neighbor Sicht
- Baseline + Delta Detection
- Timeline JSONL
- Risk Score
- Tangle Hash Chain
- HTML Security Dashboard
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Continue"

$Now = Get-Date -Format "yyyyMMdd_HHmmss"

$Root      = Join-Path $env:USERPROFILE "Desktop\AVA_SOC_PORTAL_V6_SAFE"
$LogDir    = Join-Path $Root "Logs"
$StateDir  = Join-Path $Root "State"
$ReportDir = Join-Path $Root "Reports"

$SnapshotJson = Join-Path $ReportDir "snapshot_latest.json"
$AnalysisJson = Join-Path $ReportDir "analysis_latest.json"
$PortalHtml   = Join-Path $ReportDir "ava_soc_portal_v6_safe.html"

$TimelineLog  = Join-Path $LogDir "ava_v6_timeline.jsonl"
$AlertLog     = Join-Path $LogDir "ava_v6_alerts.jsonl"
$TangleLog    = Join-Path $LogDir "ava_v6_tangle.jsonl"
$TangleState  = Join-Path $StateDir "tangle_state.json"
$BaselinePath = Join-Path $StateDir "baseline.json"

$RiskPorts = @(21,23,135,139,445,3389,5985,5986)

foreach ($d in @($Root,$LogDir,$StateDir,$ReportDir)) {
    if (-not (Test-Path -LiteralPath $d)) {
        New-Item -ItemType Directory -Force -Path $d | Out-Null
    }
}

function H {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value) { return "" }
    return [System.Net.WebUtility]::HtmlEncode([string]$Value)
}

function Sha256Text {
    param([string]$Text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    (($sha.ComputeHash($bytes) | ForEach-Object { $_.ToString("x2") }) -join "")
}

function Write-JsonLine {
    param([string]$Path,[object]$Object)
    $Object | ConvertTo-Json -Depth 30 -Compress | Add-Content -LiteralPath $Path -Encoding UTF8
}

function Write-Tangle {
    param([string]$Type,[string]$Summary,[object]$Data)

    $prev = $null
    if (Test-Path -LiteralPath $TangleState) {
        try { $prev = (Get-Content -LiteralPath $TangleState -Raw | ConvertFrom-Json).last_hash } catch {}
    }

    $event = [ordered]@{
        time          = (Get-Date).ToString("o")
        computer      = $env:COMPUTERNAME
        user          = $env:USERNAME
        type          = $Type
        summary       = $Summary
        previous_hash = $prev
        data          = $Data
    }

    $raw = $event | ConvertTo-Json -Depth 30 -Compress
    $hash = Sha256Text $raw
    $event["hash"] = $hash

    Write-JsonLine -Path $TangleLog -Object $event

    [pscustomobject]@{
        updated   = (Get-Date).ToString("o")
        last_hash = $hash
    } | ConvertTo-Json | Set-Content -LiteralPath $TangleState -Encoding UTF8
}

function New-TimelineEvent {
    param([string]$Category,[string]$Title,[string]$Message,[string]$Severity,[object]$Data)

    Write-JsonLine -Path $TimelineLog -Object ([ordered]@{
        time     = (Get-Date).ToString("o")
        category = $Category
        title    = $Title
        message  = $Message
        severity = $Severity
        data     = $Data
    })
}

function Add-Alert {
    param([string]$Severity,[string]$Title,[string]$Message,[int]$Score,[object]$Data)

    $alert = [ordered]@{
        time     = (Get-Date).ToString("o")
        severity = $Severity
        title    = $Title
        message  = $Message
        score    = $Score
        data     = $Data
    }

    Write-JsonLine -Path $AlertLog -Object $alert
    New-TimelineEvent -Category "Alert" -Title $Title -Message $Message -Severity $Severity -Data $Data
    return $alert
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
    $enc  = $null

    foreach ($line in ($raw -split "`r?`n")) {
        $l = $line.Trim()

        if ($l -match "^SSID\s+\d+\s+:\s+(.*)$") {
            $ssid = $Matches[1]
            $auth = $null
            $enc  = $null
        }
        elseif ($l -match "^Authentication\s+:\s+(.*)$") {
            $auth = $Matches[1]
        }
        elseif ($l -match "^Encryption\s+:\s+(.*)$") {
            $enc = $Matches[1]
        }
        elseif ($l -match "^BSSID\s+\d+\s+:\s+(.*)$") {
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
        elseif ($l -match "^Signal\s+:\s+(.*)$") {
            if ($items.Count -gt 0) { $items[$items.Count - 1].Signal = $Matches[1] }
        }
        elseif ($l -match "^Radio type\s+:\s+(.*)$") {
            if ($items.Count -gt 0) { $items[$items.Count - 1].RadioType = $Matches[1] }
        }
        elseif ($l -match "^Channel\s+:\s+(.*)$") {
            if ($items.Count -gt 0) { $items[$items.Count - 1].Channel = $Matches[1] }
        }
    }

    return $items
}

function New-Snapshot {
    $procMap = @{}
    try { Get-Process | ForEach-Object { $procMap[$_.Id] = $_.ProcessName } } catch {}

    $connections = try {
        Get-NetTCPConnection -State Established | ForEach-Object {
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

    $defender  = try { Get-MpComputerStatus | Select-Object RealTimeProtectionEnabled,AntivirusEnabled,AntivirusSignatureLastUpdated } catch { [pscustomobject]@{ Error=$_.Exception.Message } }
    $firewall  = try { Get-NetFirewallProfile | Select-Object Name,Enabled,DefaultInboundAction,DefaultOutboundAction } catch { @([pscustomobject]@{ Error=$_.Exception.Message }) }
    $adapters  = try { Get-NetAdapter | Select-Object Name,InterfaceDescription,Status,MacAddress,LinkSpeed } catch { @([pscustomobject]@{ Error=$_.Exception.Message }) }
    $neighbors = try { Get-NetNeighbor -AddressFamily IPv4 | Where-Object { $_.State -ne "Unreachable" } | Select-Object InterfaceAlias,IPAddress,LinkLayerAddress,State } catch { @([pscustomobject]@{ Error=$_.Exception.Message }) }
    $processes = try { Get-CimInstance Win32_Process | Select-Object ProcessId,ParentProcessId,Name,ExecutablePath,CommandLine } catch { @([pscustomobject]@{ Error=$_.Exception.Message }) }
    $services  = try { Get-CimInstance Win32_Service | Where-Object State -eq "Running" | Select-Object Name,DisplayName,State,StartMode,StartName } catch { @([pscustomobject]@{ Error=$_.Exception.Message }) }
    $tasks     = try { Get-ScheduledTask | Where-Object { $_.TaskPath -notlike "\Microsoft*" } | Select-Object TaskName,TaskPath,State } catch { @([pscustomobject]@{ Error=$_.Exception.Message }) }

    [ordered]@{
        time        = (Get-Date).ToString("o")
        computer    = $env:COMPUTERNAME
        user        = $env:USERNAME
        mode        = "LOCAL_DEFENSIVE_READ_ONLY"
        defender    = $defender
        firewall    = $firewall
        adapters    = $adapters
        neighbors   = $neighbors
        wlan        = Get-WlanNetworksSafe
        processes   = $processes
        connections = $connections
        services    = $services
        tasks       = $tasks
    }
}

function Load-Baseline {
    if (Test-Path -LiteralPath $BaselinePath) {
        try { return Get-Content -LiteralPath $BaselinePath -Raw | ConvertFrom-Json } catch { return $null }
    }
    return $null
}

function Save-Baseline {
    param([object]$Snapshot)
    $Snapshot | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $BaselinePath -Encoding UTF8
}

function Analyze-Snapshot {
    param([object]$Snapshot)

    $alerts = New-Object System.Collections.Generic.List[object]
    $score = 0

    if ($Snapshot.defender.RealTimeProtectionEnabled -eq $false) {
        $score += 100
        $alerts.Add((Add-Alert "CRITICAL" "Defender Echtzeitschutz deaktiviert" "Windows Defender Echtzeitschutz ist aus." 100 $Snapshot.defender)) | Out-Null
    }

    foreach ($fw in @($Snapshot.firewall)) {
        if ($fw.Enabled -eq $false) {
            $score += 80
            $alerts.Add((Add-Alert "HIGH" "Firewall deaktiviert" "Firewall-Profil deaktiviert: $($fw.Name)" 80 $fw)) | Out-Null
        }
    }

    foreach ($c in @($Snapshot.connections)) {
        if ($null -ne $c.RemotePort -and ($RiskPorts -contains [int]$c.RemotePort)) {
            $s = 45
            $sev = "MEDIUM"
            if ([int]$c.RemotePort -in @(445,3389,5985,5986)) {
                $s = 75
                $sev = "HIGH"
            }
            $score += $s
            $alerts.Add((Add-Alert $sev "Risiko-Port Verbindung" "$($c.RemoteAddress):$($c.RemotePort) durch $($c.Process)" $s $c)) | Out-Null
        }
    }

    $baseline = Load-Baseline
    $delta = [ordered]@{
        baseline_exists = $null -ne $baseline
        new_neighbors   = @()
        new_wlan_bssid  = @()
        new_processes   = @()
        new_services    = @()
        new_tasks       = @()
    }

    if ($null -eq $baseline) {
        Save-Baseline $Snapshot
        New-TimelineEvent "Baseline" "Baseline erstellt" "Erster Snapshot wurde als Baseline gespeichert." "INFO" $null
    } else {
        $oldNeighbors = @($baseline.neighbors | ForEach-Object { "$($_.IPAddress)|$($_.LinkLayerAddress)" })
        foreach ($n in @($Snapshot.neighbors)) {
            $key = "$($n.IPAddress)|$($n.LinkLayerAddress)"
            if ($n.IPAddress -and ($oldNeighbors -notcontains $key)) {
                $delta.new_neighbors += $n
                $score += 20
            }
        }

        $oldBssid = @($baseline.wlan | ForEach-Object { $_.BSSID })
        foreach ($w in @($Snapshot.wlan)) {
            if ($w.BSSID -and ($oldBssid -notcontains $w.BSSID)) {
                $delta.new_wlan_bssid += $w
                $score += 10
            }
        }

        $oldProc = @($baseline.processes | ForEach-Object { $_.Name } | Sort-Object -Unique)
        foreach ($p in @($Snapshot.processes)) {
            if ($p.Name -and ($oldProc -notcontains $p.Name)) {
                $delta.new_processes += $p.Name
                $score += 5
            }
        }

        $oldServices = @($baseline.services | ForEach-Object { $_.Name })
        foreach ($s in @($Snapshot.services)) {
            if ($s.Name -and ($oldServices -notcontains $s.Name)) {
                $delta.new_services += $s
                $score += 20
            }
        }

        $oldTasks = @($baseline.tasks | ForEach-Object { "$($_.TaskPath)$($_.TaskName)" })
        foreach ($t in @($Snapshot.tasks)) {
            $key = "$($t.TaskPath)$($t.TaskName)"
            if ($t.TaskName -and ($oldTasks -notcontains $key)) {
                $delta.new_tasks += $t
                $score += 25
            }
        }

        if (@($delta.new_neighbors).Count -gt 0) {
            New-TimelineEvent "Delta" "Neue LAN-Nachbarn" "$(@($delta.new_neighbors).Count) neue Nachbarn seit Baseline." "WARN" $delta.new_neighbors
        }

        if (@($delta.new_wlan_bssid).Count -gt 0) {
            New-TimelineEvent "Delta" "Neue WLAN-BSSID" "$(@($delta.new_wlan_bssid).Count) neue WLAN-BSSID seit Baseline." "INFO" $delta.new_wlan_bssid
        }
    }

    [ordered]@{
        time        = (Get-Date).ToString("o")
        score       = [Math]::Min($score,999)
        alert_count = @($alerts).Count
        alerts      = $alerts
        delta       = $delta
    }
}

function Rows {
    param([object[]]$Items,[string[]]$Props,[string]$Empty="Keine Daten gefunden.")

    $rows = foreach ($item in @($Items)) {
        $tds = foreach ($p in $Props) { "<td>$(H $item.$p)</td>" }
        "<tr>$($tds -join '')</tr>"
    }

    if (-not $rows) {
        return "<tr><td colspan='$($Props.Count)'>$(H $Empty)</td></tr>"
    }

    return $rows
}

function Read-TimelineLast {
    if (Test-Path -LiteralPath $TimelineLog) {
        try {
            return Get-Content -LiteralPath $TimelineLog -Tail 100 | ForEach-Object { $_ | ConvertFrom-Json }
        } catch {}
    }
    return @()
}

function Build-Portal {
    param([object]$Snapshot,[object]$Analysis)

    $score = [int]$Analysis.score
    $health = "OK"
    if ($score -ge 150) { $health = "WARN" }
    if ($score -ge 300) { $health = "HIGH" }
    if ($score -ge 500) { $health = "CRITICAL" }

    $healthColor = @{ "OK" = "#22c55e"; "WARN" = "#eab308"; "HIGH" = "#f97316"; "CRITICAL" = "#ef4444" }[$health]

    $lastHash = "N/A"
    if (Test-Path -LiteralPath $TangleState) {
        try { $lastHash = (Get-Content -LiteralPath $TangleState -Raw | ConvertFrom-Json).last_hash } catch {}
    }
    $hashShort = if ($lastHash -ne "N/A") { $lastHash.Substring(0, [Math]::Min(16, $lastHash.Length)) + "..." } else { "N/A" }

    $alertRows = Rows @($Analysis.alerts) @("severity","title","message","score","time") "Keine Alerts gefunden."
    $wlanRows  = Rows @($Snapshot.wlan) @("SSID","BSSID","Authentication","Encryption","Signal","RadioType","Channel")
    $neiRows   = Rows @($Snapshot.neighbors) @("InterfaceAlias","IPAddress","LinkLayerAddress","State")
    $adpRows   = Rows @($Snapshot.adapters) @("Name","InterfaceDescription","Status","MacAddress","LinkSpeed")
    $connRows  = Rows (@($Snapshot.connections) | Select-Object -First 100) @("Process","PID","LocalAddress","LocalPort","RemoteAddress","RemotePort","State")
    $procRows  = Rows (@($Snapshot.processes) | Select-Object -First 100) @("Name","ProcessId","ParentProcessId","ExecutablePath","CommandLine")

    $timelineRows = foreach ($t in (Read-TimelineLast)) {
        "<tr><td>$(H $t.time)</td><td>$(H $t.category)</td><td>$(H $t.severity)</td><td>$(H $t.title)</td><td>$(H $t.message)</td></tr>"
    }
    if (-not $timelineRows) { $timelineRows = "<tr><td colspan='5'>Noch keine Timeline Events.</td></tr>" }

$Html = @"
<!doctype html>
<html lang="de">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>AVA SOC PORTAL V6 SAFE EDITION</title>
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
footer { margin-top: 18px; font-size: 12px; color: var(--muted); }
code { background: #1f2937; padding: 1px 5px; border-radius: 4px; }
</style>
</head>
<body>
<h1>AVA SOC PORTAL V6 SAFE EDITION</h1>
<p class="sub">Defensiv / Lokal / Read-Only &nbsp;&middot;&nbsp; $(H $Snapshot.computer) &nbsp;&middot;&nbsp; $(H $Snapshot.time)</p>

<div class="stats">
  <div class="stat"><div class="k">Risk Score</div><div class="v" style="color:$healthColor;">$score</div></div>
  <div class="stat"><div class="k">Health</div><div class="v" style="color:$healthColor;">$(H $health)</div></div>
  <div class="stat"><div class="k">Alerts</div><div class="v">$(@($Analysis.alerts).Count)</div></div>
  <div class="stat"><div class="k">Tangle Hash</div><div class="v" style="font-size:11px;word-break:break-all;">$(H $hashShort)</div></div>
</div>

<div class="section">
<h2>Alerts</h2>
<table>
<thead><tr><th>Severity</th><th>Titel</th><th>Meldung</th><th>Score</th><th>Zeit</th></tr></thead>
<tbody>
$($alertRows -join "`n")
</tbody></table>
</div>

<div class="section">
<h2>WLAN Netzwerke</h2>
<table>
<thead><tr><th>SSID</th><th>BSSID</th><th>Auth</th><th>Enc</th><th>Signal</th><th>RadioType</th><th>Channel</th></tr></thead>
<tbody>
$($wlanRows -join "`n")
</tbody></table>
</div>

<div class="section">
<h2>LAN Nachbarn</h2>
<table>
<thead><tr><th>Interface</th><th>IP-Adresse</th><th>MAC</th><th>Status</th></tr></thead>
<tbody>
$($neiRows -join "`n")
</tbody></table>
</div>

<div class="section">
<h2>Netzwerkadapter</h2>
<table>
<thead><tr><th>Name</th><th>Beschreibung</th><th>Status</th><th>MAC</th><th>Geschwindigkeit</th></tr></thead>
<tbody>
$($adpRows -join "`n")
</tbody></table>
</div>

<div class="section">
<h2>Verbindungen (max. 100)</h2>
<table>
<thead><tr><th>Prozess</th><th>PID</th><th>Lokal Adresse</th><th>Lokal Port</th><th>Remote Adresse</th><th>Remote Port</th><th>Status</th></tr></thead>
<tbody>
$($connRows -join "`n")
</tbody></table>
</div>

<div class="section">
<h2>Prozesse (max. 100)</h2>
<table>
<thead><tr><th>Name</th><th>PID</th><th>PPID</th><th>Pfad</th><th>Kommandozeile</th></tr></thead>
<tbody>
$($procRows -join "`n")
</tbody></table>
</div>

<div class="section">
<h2>Timeline (letzte 100)</h2>
<table>
<thead><tr><th>Zeit</th><th>Kategorie</th><th>Schwere</th><th>Titel</th><th>Meldung</th></tr></thead>
<tbody>
$($timelineRows -join "`n")
</tbody></table>
</div>

<footer>
  Portal: <code>$(H $PortalHtml)</code> &nbsp;&middot;&nbsp;
  Snapshot: <code>$(H $SnapshotJson)</code> &nbsp;&middot;&nbsp;
  Analysis: <code>$(H $AnalysisJson)</code>
</footer>
</body>
</html>
"@

    $Html | Set-Content -LiteralPath $PortalHtml -Encoding UTF8
    Write-Host "Portal gespeichert: $PortalHtml" -ForegroundColor Cyan
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

function Invoke-Run {
    Write-Host "[AVA V6 SAFE] Snapshot wird erfasst..." -ForegroundColor Cyan

    $snap     = New-Snapshot
    $analysis = Analyze-Snapshot -Snapshot $snap

    $snap | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $SnapshotJson -Encoding UTF8
    $analysis | ConvertTo-Json -Depth 30 | Set-Content -LiteralPath $AnalysisJson -Encoding UTF8

    Write-Tangle -Type "AVA_SOC_V6_SAFE_SNAPSHOT" -Summary "Score=$($analysis.score) Alerts=$($analysis.alert_count)" -Data ([ordered]@{
        score       = $analysis.score
        alert_count = $analysis.alert_count
    })

    Build-Portal -Snapshot $snap -Analysis $analysis

    Write-Host "[AVA V6 SAFE] Risk Score: $($analysis.score) | Alerts: $($analysis.alert_count)" -ForegroundColor Green
    Write-Host "[AVA V6 SAFE] Snapshot: $SnapshotJson" -ForegroundColor Yellow
    Write-Host "[AVA V6 SAFE] Analysis: $AnalysisJson" -ForegroundColor Yellow
}

Invoke-Run
