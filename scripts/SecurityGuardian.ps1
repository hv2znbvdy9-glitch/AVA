#requires -RunAsAdministrator

param(
    [switch]$RunOnce,
    [switch]$InstallTask,
    [switch]$RemoveTask,
    [switch]$RollbackFirewall,
    [switch]$HardenRemoteServices
)

# =========================
# CONFIG
# =========================
$Root = "C:\Windows\SecurityGuardian"
$LogDir = "$Root\Logs"
$ReportDir = "$Root\Reports"
$StateDir = "$Root\State"
$TaskName = "WindowsSecurityGuardian"

$EventLog = "$LogDir\events.jsonl"
$AlertLog = "$LogDir\alerts.jsonl"
$BaselinePath = "$StateDir\baseline.json"
$HashPath = "$StateDir\integrity.hash"

$RulePrefix = "AVA_Block_"

# Allowed admins (customize per environment)
$AllowedAdmins = @(
    "Administrator",
    "$env:USERNAME"
)

# Canary files
$CanaryFiles = @(
    "$Root\finance_decoy_2026.txt",
    "$Root\admin_notes_decoy.txt",
    "$Root\vpn_inventory_decoy.txt"
)

# =========================
# INIT
# =========================
New-Item -ItemType Directory -Path $Root,$LogDir,$ReportDir,$StateDir -Force | Out-Null

function Log($obj,$path){
    $json = $obj | ConvertTo-Json -Compress -Depth 5
    Add-Content -Path $path -Value $json
}

function Alert($msg,$severity="MEDIUM"){
    Log @{
        time=(Get-Date)
        severity=$severity
        message=$msg
    } $AlertLog
}

# =========================
# BASELINE
# =========================
function Save-Baseline {
    $admins = Get-LocalGroupMember Administrators | Select Name
    $baseline = @{
        created=(Get-Date)
        admins=$admins
    }
    $baseline | ConvertTo-Json | Set-Content $BaselinePath
}

function Check-Admins {
    $admins = Get-LocalGroupMember Administrators | Select Name
    foreach($a in $admins){
        if($AllowedAdmins -notcontains $a.Name){
            Alert "UNAUTHORIZED ADMIN: $($a.Name)" "HIGH"
        }
    }
}

# =========================
# CANARY SYSTEM
# =========================
function Init-Canaries {
    foreach($file in $CanaryFiles){
        if(-not (Test-Path $file)){
            "DO NOT TOUCH - MONITORED" | Set-Content $file
        }
    }
}

function Check-Canaries {
    foreach($file in $CanaryFiles){
        if(-not (Test-Path $file)){
            Alert "CANARY DELETED: $file" "HIGH"
        }
    }
}

# =========================
# CANARY WATCHDOG (FileSystemWatcher)
# =========================
function Start-CanaryWatchdog {
    foreach($file in $CanaryFiles) {
        $path = Split-Path $file
        $filter = Split-Path $file -Leaf

        $watcher = New-Object System.IO.FileSystemWatcher
        $watcher.Path = $path
        $watcher.Filter = $filter
        $watcher.IncludeSubdirectories = $false
        $watcher.EnableRaisingEvents = $true

        $action = {
            $path = $Event.SourceEventArgs.FullPath
            $changeType = $Event.SourceEventArgs.ChangeType
            Write-Host "[!] ALERT: Canary File $changeType - $path" -ForegroundColor Red
        }

        Register-ObjectEvent $watcher "Changed" -Action $action
        Register-ObjectEvent $watcher "Deleted" -Action $action
        Register-ObjectEvent $watcher "Renamed" -Action $action
    }
}

# =========================
# INTEGRITY CHECK
# =========================
function Save-Hash {
    $hash = Get-FileHash $PSCommandPath
    $hash.Hash | Set-Content $HashPath
}

function Check-Hash {
    if(Test-Path $HashPath){
        $old = Get-Content $HashPath
        $new = (Get-FileHash $PSCommandPath).Hash
        if($old -ne $new){
            Alert "SCRIPT TAMPER DETECTED!" "HIGH"
        }
    }
}

# =========================
# FIREWALL
# =========================
$Ports = @(21,23,135,139,445,3389,5985,5986)

function Apply-FW {
    foreach($p in $Ports){
        if(-not (Get-NetFirewallRule -DisplayName "$RulePrefix$p" -ErrorAction SilentlyContinue)){
            New-NetFirewallRule -DisplayName "$RulePrefix$p" -Direction Inbound -Action Block -Protocol TCP -LocalPort $p
        }
    }
}

# =========================
# NETWORK MONITOR
# =========================
function Check-Network {
    $conns = Get-NetTCPConnection -State Established
    foreach($c in $conns){
        if($c.RemoteAddress -notlike "192.168*" -and $c.RemoteAddress -ne "127.0.0.1"){
            $proc = Get-Process -Id $c.OwningProcess -ErrorAction SilentlyContinue
            if($proc.Name -in @("powershell","cmd","python")){
                Alert "SUSPICIOUS CONNECTION: $($proc.Name) -> $($c.RemoteAddress)" "MEDIUM"
            }
        }
    }
}

function Check-Network-Advanced {
    $conns = Get-NetTCPConnection -State Established
    foreach($c in $conns){
        if($c.RemoteAddress -match "^127\.|^192\.168\.|^10\.|^172\.(1[6-9]|2[0-9]|3[0-1])\.") { continue }

        $proc = Get-Process -Id $c.OwningProcess -ErrorAction SilentlyContinue
        if($proc) {
            $path = $proc.Path
            if($proc.Name -in @('powershell','cmd','python','certutil','bitsadmin') -or $path -like "*\AppData\Local\Temp\*") {
                Alert "NETWORK ALERT: $($proc.Name) -> $($c.RemoteAddress):$($c.RemotePort) (Path: $path)" "CRITICAL"
            }
        }
    }
}

# =========================
# SUSPICIOUS PROCESS SCANNER
# =========================
function Scan-SuspiciousProcesses {
    $SuspiciousArgs = @("-enc", "encodedcommand", "windowstyle hidden", "bypass", "nop")

    $psProcs = Get-WmiObject Win32_Process -Filter "name='powershell.exe' OR name='pwsh.exe'"

    foreach($p in $psProcs) {
        $cmdLine = $p.CommandLine.ToLower()
        $foundFlags = @()

        foreach($flag in $SuspiciousArgs) {
            if($cmdLine -contains $flag) { $foundFlags += $flag }
        }

        if($foundFlags.Count -ge 2 -or $cmdLine.Contains("-enc")) {
            Alert "SUSPICIOUS PS PROCESS: PID $($p.ProcessId) | Args: $foundFlags" "CRITICAL"
        }
    }
}

# =========================
# THREAT RESPONSE
# =========================
function Terminate-Threat {
    param($ProcessId)
    Stop-Process -Id $ProcessId -Force
    Alert "AUTO-DEFENSE: Process $ProcessId terminated!" "HIGH"
}

# =========================
# HTML REPORT
# =========================
function Build-HTML {
    $alerts = Get-Content $AlertLog -ErrorAction SilentlyContinue | ConvertFrom-Json

    $htmlBody = foreach ($a in $alerts) {
        "<tr><td>$($a.time)</td><td>$($a.severity)</td><td>$($a.message)</td></tr>"
    }

    $finalHtml = @"
<!DOCTYPE html>
<html>
<head>
<title>AVA Security Dashboard</title>
<style>
body { font-family: sans-serif; background: #1a1a2e; color: #eee; padding: 2em; }
h1 { color: #0969DA; }
table { width: 100%; border-collapse: collapse; margin-top: 1em; }
th, td { border: 1px solid #333; padding: 0.5em; text-align: left; }
th { background: #16213e; }
</style>
</head>
<body>
<h1>AVA SECURITY DASHBOARD</h1>
<table>
<tr><th>Time</th><th>Severity</th><th>Message</th></tr>
$($htmlBody -join "`n")
</table>
</body>
</html>
"@
    $finalHtml | Set-Content "$ReportDir\report.html"
}

# =========================
# SCHEDULED TASK
# =========================
function Install-Task {
    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-File `"$PSCommandPath`" -RunOnce"
    $trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1)
    $trigger.RepetitionInterval = (New-TimeSpan -Minutes 5)
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest

    Register-ScheduledTask -TaskName $TaskName -Action $action -Trigger $trigger -Principal $principal -Force
}

# =========================
# MAIN
# =========================
if($RemoveTask){
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    exit
}

if(-not (Test-Path $BaselinePath)){
    Save-Baseline
}

Init-Canaries
Check-Hash
Check-Admins
Check-Canaries
Apply-FW
Check-Network
Build-HTML
Save-Hash

if($InstallTask){
    Install-Task
}

Write-Host "AVA ELITE v2 DONE" -ForegroundColor Green
