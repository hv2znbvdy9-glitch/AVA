#requires -RunAsAdministrator
<#
AVA PORTAL V4
Defensiv / Lokal / Read-Only
Visual Portal + Graph Engine für AVA SOC CORE

Keine Angriffe. Keine Exploits. Keine fremden Systeme.
Liest nur lokale AVA Logs und erzeugt ein HTML-Dashboard.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root      = "C:\Windows\SecurityGuardian"
$LogDir    = Join-Path $Root "Logs"
$ReportDir = Join-Path $Root "Reports"
$StateDir  = Join-Path $Root "State"

$EventLog   = Join-Path $LogDir "events.jsonl"
$AlertLog   = Join-Path $LogDir "alerts.jsonl"
$GraphJson  = Join-Path $ReportDir "graph_v4.json"
$PortalHtml = Join-Path $ReportDir "ava_portal_v4.html"

function Ensure-Dirs {
    foreach ($d in @($Root,$LogDir,$ReportDir,$StateDir)) {
        if (-not (Test-Path -LiteralPath $d)) {
            New-Item -ItemType Directory -Path $d -Force | Out-Null
        }
    }
}

function Html {
    param([object]$Value)
    if ($null -eq $Value) { return "" }
    return [System.Net.WebUtility]::HtmlEncode([string]$Value)
}

function Read-JsonLines {
    param(
        [string]$Path,
        [int]$Tail = 300
    )

    if (-not (Test-Path -LiteralPath $Path)) { return @() }

    @(Get-Content -Path $Path -Tail $Tail | ForEach-Object {
        try { $_ | ConvertFrom-Json } catch { $null }
    } | Where-Object { $_ })
}

function Add-Node {
    param(
        [hashtable]$Nodes,
        [string]$Id,
        [string]$Label,
        [string]$Type,
        [int]$Score = 0
    )

    if (-not $Nodes.ContainsKey($Id)) {
        $Nodes[$Id] = [ordered]@{
            id    = $Id
            label = $Label
            type  = $Type
            score = $Score
        }
    } else {
        if ($Score -gt [int]$Nodes[$Id].score) {
            $Nodes[$Id].score = $Score
        }
    }
}

function Add-Link {
    param(
        [System.Collections.Generic.List[object]]$Links,
        [string]$Source,
        [string]$Target,
        [string]$Reason,
        [int]$Weight = 1
    )

    $Links.Add([ordered]@{
        source = $Source
        target = $Target
        reason = $Reason
        weight = $Weight
    }) | Out-Null
}

function Build-Graph {
    param(
        [object[]]$Events,
        [object[]]$Alerts
    )

    $nodes = @{}
    $links = New-Object System.Collections.Generic.List[object]

    $hostId = "host:$env:COMPUTERNAME"
    $userId = "user:$env:USERNAME"

    Add-Node $nodes $hostId $env:COMPUTERNAME "host" 0
    Add-Node $nodes $userId $env:USERNAME "user" 0
    Add-Link $links $hostId $userId "current_user" 1

    foreach ($e in $Events) {
        $eventId = "event:$($e.type):$($e.time)"
        Add-Node $nodes $eventId "$($e.type)" "event" 10
        Add-Link $links $hostId $eventId "event_on_host" 1

        if ($e.severity) {
            $sevId = "severity:$($e.severity)"
            Add-Node $nodes $sevId "$($e.severity)" "severity" 0
            Add-Link $links $eventId $sevId "has_severity" 1
        }
    }

    foreach ($a in $Alerts) {
        $score = 0
        try { $score = [int]$a.score } catch { $score = 0 }

        $alertId = "alert:$($a.title):$($a.time)"
        Add-Node $nodes $alertId "$($a.title)" "alert" $score
        Add-Link $links $hostId $alertId "alert_on_host" 3

        if ($a.severity) {
            $sevId = "severity:$($a.severity)"
            Add-Node $nodes $sevId "$($a.severity)" "severity" $score
            Add-Link $links $alertId $sevId "alert_severity" 2
        }

        if ($a.reason) {
            $reasonId = "reason:$($a.reason)"
            Add-Node $nodes $reasonId "$($a.reason)" "reason" $score
            Add-Link $links $alertId $reasonId "alert_reason" 1
        }

        if ($a.data.ProcessName) {
            $procId = "process:$($a.data.ProcessName)"
            Add-Node $nodes $procId "$($a.data.ProcessName)" "process" $score
            Add-Link $links $alertId $procId "related_process" 2
        }

        if ($a.data.RemotePort) {
            $portId = "port:$($a.data.RemotePort)"
            Add-Node $nodes $portId "Port $($a.data.RemotePort)" "port" $score
            Add-Link $links $alertId $portId "related_port" 2
        }

        if ($a.data.Name) {
            $nameId = "object:$($a.data.Name)"
            Add-Node $nodes $nameId "$($a.data.Name)" "object" $score
            Add-Link $links $alertId $nameId "related_object" 2
        }
    }

    [ordered]@{
        generated = (Get-Date).ToString("o")
        host      = $env:COMPUTERNAME
        user      = $env:USERNAME
        nodes     = @($nodes.Values)
        links     = @($links)
    }
}

function Get-Risk {
    param([object[]]$Alerts)

    if ($Alerts.Count -eq 0) {
        return [pscustomobject]@{
            Score = 0
            Level = "OK"
            Critical = 0
            High = 0
            Medium = 0
            Low = 0
        }
    }

    $critical = @($Alerts | Where-Object { $_.severity -eq "CRITICAL" }).Count
    $high     = @($Alerts | Where-Object { $_.severity -eq "HIGH" }).Count
    $medium   = @($Alerts | Where-Object { $_.severity -eq "MEDIUM" }).Count
    $low      = @($Alerts | Where-Object { $_.severity -eq "LOW" }).Count

    $max = 0
    foreach ($a in $Alerts) {
        try {
            if ([int]$a.score -gt $max) { $max = [int]$a.score }
        } catch {}
    }

    $level = "OK"
    if ($max -ge 90) { $level = "CRITICAL" }
    elseif ($max -ge 75) { $level = "HIGH" }
    elseif ($max -ge 50) { $level = "MEDIUM" }
    elseif ($max -gt 0) { $level = "LOW" }

    [pscustomobject]@{
        Score = $max
        Level = $level
        Critical = $critical
        High = $high
        Medium = $medium
        Low = $low
    }
}

function Build-Portal {
    param(
        [object[]]$Events,
        [object[]]$Alerts,
        [object]$Graph
    )

    $risk = Get-Risk -Alerts $Alerts

    $alertRows = foreach ($a in ($Alerts | Sort-Object score -Descending | Select-Object -First 25)) {
        $cls = "$(Html $a.severity)".ToLower()
        "<tr class='$cls'><td>$(Html $a.time)</td><td>$(Html $a.severity)</td><td>$(Html $a.score)</td><td>$(Html $a.title)</td><td>$(Html $a.reason)</td></tr>"
    }

    $eventRows = foreach ($e in ($Events | Select-Object -Last 40)) {
        "<tr><td>$(Html $e.time)</td><td>$(Html $e.severity)</td><td>$(Html $e.type)</td><td>$(Html $e.summary)</td></tr>"
    }

    $graphData = $Graph | ConvertTo-Json -Depth 20 -Compress

    $scoreColor = "var(--ok)"
    if ($risk.Score -ge 90) { $scoreColor = "var(--critical)" }
    elseif ($risk.Score -ge 75) { $scoreColor = "var(--high)" }
    elseif ($risk.Score -ge 50) { $scoreColor = "var(--medium)" }
    elseif ($risk.Score -gt 0) { $scoreColor = "var(--low)" }

    $levelColor = "var(--ok)"
    if ($risk.Level -eq "CRITICAL") { $levelColor = "var(--critical)" }
    elseif ($risk.Level -eq "HIGH") { $levelColor = "var(--high)" }
    elseif ($risk.Level -eq "MEDIUM") { $levelColor = "var(--medium)" }
    elseif ($risk.Level -eq "LOW") { $levelColor = "var(--low)" }

$html = @"
<!DOCTYPE html>
<html lang="de">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>AVA SOC PORTAL V4</title>
<style>
:root {
	color-scheme: dark;
	--bg: #0b0f19;
	--card: #111827;
	--border: #1f2937;
	--text: #f3f4f6;
	--muted: #9ca3af;
	--accent: #0969da;
	--critical: #ef4444;
	--high: #f97316;
	--medium: #eab308;
	--low: #22c55e;
	--ok: #10b981;
}
* { box-sizing: border-box; }
body {
	margin: 0;
	font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
	background-color: var(--bg);
	color: var(--text);
	padding: 24px;
	line-height: 1.5;
}
header {
	border-bottom: 1px solid var(--border);
	padding-bottom: 16px;
	margin-bottom: 24px;
}
h1 {
	margin: 0;
	font-size: 24px;
	color: var(--text);
	letter-spacing: 0.5px;
}
.subtitle {
	font-size: 14px;
	color: var(--muted);
	margin-top: 4px;
}
.stats-grid {
	display: grid;
	grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
	gap: 16px;
	margin-bottom: 24px;
}
.stat-card {
	background-color: var(--card);
	border: 1px solid var(--border);
	border-radius: 8px;
	padding: 16px;
	display: flex;
	flex-direction: column;
}
.stat-label {
	font-size: 12px;
	color: var(--muted);
	text-transform: uppercase;
	letter-spacing: 0.5px;
}
.stat-value {
	font-size: 28px;
	font-weight: 700;
	margin-top: 8px;
}
.grid-container {
	display: grid;
	grid-template-columns: 1fr;
	gap: 24px;
	margin-bottom: 24px;
}
@media (min-width: 1024px) {
	.grid-container {
		grid-template-columns: 1fr 1fr;
	}
}
.card {
	background-color: var(--card);
	border: 1px solid var(--border);
	border-radius: 8px;
	padding: 20px;
}
.card h2 {
	margin-top: 0;
	margin-bottom: 16px;
	font-size: 18px;
	border-bottom: 1px solid var(--border);
	padding-bottom: 8px;
}
table {
	width: 100%;
	border-collapse: collapse;
	font-size: 13px;
	text-align: left;
}
th {
	color: var(--muted);
	font-weight: 600;
	padding: 8px;
	border-bottom: 1px solid var(--border);
}
td {
	padding: 8px;
	border-bottom: 1px solid #1f2937;
	word-break: break-word;
}
.critical { color: var(--critical); font-weight: bold; }
.high { color: var(--high); }
.medium { color: var(--medium); }
.low { color: var(--low); }
.ok { color: var(--ok); }

#graph-canvas {
	width: 100%;
	height: 350px;
	background-color: #0d1117;
	border: 1px solid var(--border);
	border-radius: 6px;
}
.notice {
	background-color: #1e1b4b;
	border: 1px solid #3730a3;
	border-radius: 8px;
	padding: 16px;
	margin-bottom: 24px;
	font-size: 14px;
}
footer {
	text-align: center;
	color: var(--muted);
	font-size: 12px;
	margin-top: 48px;
	border-top: 1px solid var(--border);
	padding-top: 16px;
}
</style>
</head>
<body>
<header>
	<h1>AVA SOC PORTAL V4</h1>
	<div class="subtitle">Visual Portal + Graph Engine für AVA SOC CORE &middot; Host: $(Html $env:COMPUTERNAME) &middot; User: $(Html $env:USERNAME)</div>
</header>

<div class="stats-grid">
	<div class="stat-card">
		<span class="stat-label">Max Risk Score</span>
		<span class="stat-value" style="color: $scoreColor;">$($risk.Score)</span>
	</div>
	<div class="stat-card">
		<span class="stat-label">Risk Level</span>
		<span class="stat-value" style="color: $levelColor;">$($risk.Level)</span>
	</div>
	<div class="stat-card">
		<span class="stat-label">Alert Severity counts</span>
		<span class="stat-value" style="font-size: 14px; margin-top: 12px;">
			<span class="critical">Critical: $($risk.Critical)</span><br>
			<span class="high">High: $($risk.High)</span><br>
			<span class="medium">Medium: $($risk.Medium)</span><br>
			<span class="low">Low: $($risk.Low)</span>
		</span>
	</div>
	<div class="stat-card">
		<span class="stat-label">Total Events / Alerts</span>
		<span class="stat-value">$($Events.Count) / $($Alerts.Count)</span>
	</div>
</div>

<div class="grid-container">
	<div class="card">
		<h2>Interactive Topology (Graph Engine)</h2>
		<canvas id="graph-canvas"></canvas>
	</div>
	<div class="card">
		<h2>Alerts (Max 25)</h2>
		<div style="max-height: 350px; overflow-y: auto;">
			<table>
				<thead>
					<tr>
						<th>Time</th>
						<th>Severity</th>
						<th>Score</th>
						<th>Title</th>
						<th>Reason</th>
					</tr>
				</thead>
				<tbody>
					$($alertRows -join "`n")
				</tbody>
			</table>
		</div>
	</div>
</div>

<div class="card" style="margin-bottom: 24px;">
	<h2>Recent Events (Max 40)</h2>
	<div style="max-height: 400px; overflow-y: auto;">
		<table>
			<thead>
				<tr>
					<th>Time</th>
					<th>Severity</th>
					<th>Type</th>
					<th>Summary</th>
				</tr>
			</thead>
			<tbody>
				$($eventRows -join "`n")
			</tbody>
		</table>
	</div>
</div>

<div class="notice">
	<b>AVA-Integritätsrichtlinie:</b> Erster Blitz bleibt. Zweiter Blitz ergänzt. Kein Überschreiben. Original sichern, danach analysieren. Keine Fremdsysteme. Keine Gegenangriffe.
</div>

<footer>
	AVA SOC PORTAL V4 &middot; Generated at $(Get-Date -Format "yyyy-MM-dd HH:mm:ss") UTC
</footer>

<script>
const graphData = $graphData;
const canvas = document.getElementById('graph-canvas');
const ctx = canvas.getContext('2d');

let width = canvas.width = canvas.clientWidth;
let height = canvas.height = canvas.clientHeight;

window.addEventListener('resize', () => {
	width = canvas.width = canvas.clientWidth;
	height = canvas.height = canvas.clientHeight;
});

const nodes = (graphData && graphData.nodes) || [];
const links = (graphData && graphData.links) || [];

nodes.forEach(node => {
	node.x = Math.random() * (width - 100) + 50;
	node.y = Math.random() * (height - 100) + 50;
	node.vx = 0;
	node.vy = 0;
});

function step() {
	const k = 0.05;
	const rep = 400;
	const dump = 0.85;

	for (let i = 0; i < nodes.length; i++) {
		for (let j = i + 1; j < nodes.length; j++) {
			const n1 = nodes[i];
			const n2 = nodes[j];
			const dx = n2.x - n1.x;
			const dy = n2.y - n1.y;
			const dist = Math.sqrt(dx * dx + dy * dy) || 1;
			if (dist < 250) {
				const force = rep / (dist * dist);
				const fx = (dx / dist) * force;
				const fy = (dy / dist) * force;
				n1.vx -= fx;
				n1.vy -= fy;
				n2.vx += fx;
				n2.vy += fy;
			}
		}
	}

	links.forEach(link => {
		const sourceNode = nodes.find(n => n.id === link.source);
		const targetNode = nodes.find(n => n.id === link.target);
		if (sourceNode && targetNode) {
			const dx = targetNode.x - sourceNode.x;
			const dy = targetNode.y - sourceNode.y;
			const dist = Math.sqrt(dx * dx + dy * dy) || 1;
			const force = (dist - 100) * k * (link.weight || 1);
			const fx = (dx / dist) * force;
			const fy = (dy / dist) * force;
			sourceNode.vx += fx;
			sourceNode.vy += fy;
			targetNode.vx -= fx;
			targetNode.vy -= fy;
		}
	});

	nodes.forEach(node => {
		node.vx += (width / 2 - node.x) * 0.005;
		node.vy += (height / 2 - node.y) * 0.005;
		node.x += node.vx;
		node.y += node.vy;
		node.vx *= dump;
		node.vy *= dump;

		node.x = Math.max(20, Math.min(width - 20, node.x));
		node.y = Math.max(20, Math.min(height - 20, node.y));
	});
}

function draw() {
	ctx.clearRect(0, 0, width, height);

	ctx.strokeStyle = '#30363d';
	ctx.lineWidth = 1;
	links.forEach(link => {
		const s = nodes.find(n => n.id === link.source);
		const t = nodes.find(n => n.id === link.target);
		if (s && t) {
			ctx.beginPath();
			ctx.moveTo(s.x, s.y);
			ctx.lineTo(t.x, t.y);
			ctx.stroke();

			ctx.fillStyle = '#8b949e';
			ctx.font = '9px monospace';
			ctx.fillText(link.reason, (s.x + t.x) / 2, (s.y + t.y) / 2);
		}
	});

	nodes.forEach(node => {
		let color = '#58a6ff';
		if (node.type === 'host') color = '#238636';
		else if (node.type === 'user') color = '#a371f7';
		else if (node.type === 'alert') color = '#f85149';
		else if (node.type === 'process') color = '#d29922';

		ctx.beginPath();
		ctx.arc(node.x, node.y, 8, 0, 2 * Math.PI);
		ctx.fillStyle = color;
		ctx.fill();
		ctx.strokeStyle = '#ffffff';
		ctx.lineWidth = 1.5;
		ctx.stroke();

		ctx.fillStyle = '#c9d1d9';
		ctx.font = '10px sans-serif';
		ctx.fillText(node.label, node.x + 12, node.y + 4);
	});
}

function loop() {
	step();
	draw();
	requestAnimationFrame(loop);
}

if (nodes.length > 0) {
	loop();
} else {
	ctx.fillStyle = '#8b949e';
	ctx.font = '14px sans-serif';
	ctx.textAlign = 'center';
	ctx.fillText('No graph data available to visualize.', width / 2, height / 2);
}
</script>
</body>
</html>
"@

    $html | Set-Content -LiteralPath $PortalHtml -Encoding UTF8
}

# ------------------------------------------------------------
# Execution Block
# ------------------------------------------------------------
Ensure-Dirs

$Events = Read-JsonLines -Path $EventLog -Tail 300
$Alerts = Read-JsonLines -Path $AlertLog -Tail 300

$Graph = Build-Graph -Events $Events -Alerts $Alerts
$Graph | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $GraphJson -Encoding UTF8

Build-Portal -Events $Events -Alerts $Alerts -Graph $Graph
