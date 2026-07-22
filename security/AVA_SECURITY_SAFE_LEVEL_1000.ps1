#requires -Version 5.1
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
    [ValidateSet('Audit','Apply','Rollback')]
    [string]$Mode = 'Audit',

    [string]$CaseRoot = "$env:ProgramData\AVA\SecuritySafe",

    [string]$FirewallBackupPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-IsAdministrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

if (-not (Test-IsAdministrator)) {
    throw 'PowerShell must be started as Administrator.'
}

$timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$caseDir = Join-Path $CaseRoot "AVA_CASE_$timestamp"
New-Item -ItemType Directory -Path $caseDir -Force | Out-Null

$transcriptPath = Join-Path $caseDir 'transcript.txt'
Start-Transcript -Path $transcriptPath -Force | Out-Null

try {
    $result = [ordered]@{
        TimestampUtc = (Get-Date).ToUniversalTime().ToString('o')
        ComputerName = $env:COMPUTERNAME
        UserName = "$env:USERDOMAIN\$env:USERNAME"
        Mode = $Mode
        SafetyBoundary = 'Defensive local hardening only. No counterattack, no remote scanning, no persistence, no endless loop.'
        Actions = @()
        Errors = @()
    }

    $firewallBackup = Join-Path $caseDir 'firewall_before.wfw'
    & netsh.exe advfirewall export $firewallBackup | Out-Null
    $result.Actions += "Firewall policy exported to $firewallBackup"

    $snapshot = [ordered]@{}
    $snapshot.FirewallProfiles = Get-NetFirewallProfile |
        Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction
    $snapshot.Defender = Get-MpComputerStatus |
        Select-Object AntivirusEnabled, AntispywareEnabled, RealTimeProtectionEnabled,
                      BehaviorMonitorEnabled, IoavProtectionEnabled, NISEnabled,
                      AntivirusSignatureLastUpdated, QuickScanEndTime, FullScanEndTime
    $snapshot.LocalAdministrators = Get-LocalGroupMember -Group 'Administrators' |
        Select-Object Name, ObjectClass, PrincipalSource
    $snapshot.EstablishedConnections = Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue |
        Select-Object LocalAddress, LocalPort, RemoteAddress, RemotePort, OwningProcess
    $snapshot.NonMicrosoftScheduledTasks = Get-ScheduledTask |
        Where-Object { $_.TaskPath -notlike '\Microsoft\*' } |
        Select-Object TaskName, TaskPath, State, Author
    $snapshot.Processes = Get-Process |
        Sort-Object ProcessName |
        Select-Object ProcessName, Id, Path, StartTime -ErrorAction SilentlyContinue

    $snapshotPath = Join-Path $caseDir 'snapshot.json'
    $snapshot | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $snapshotPath -Encoding UTF8
    $result.Actions += "Read-only snapshot written to $snapshotPath"

    switch ($Mode) {
        'Audit' {
            $result.Actions += 'Audit completed. No security settings changed.'
        }

        'Apply' {
            if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, 'Enable Windows Firewall and add narrowly scoped inbound block rules')) {
                $profileParams = @{
                    Profile = @('Domain','Private','Public')
                    Enabled = $true
                    DefaultInboundAction = 'Block'
                    DefaultOutboundAction = 'Allow'
                }
                Set-NetFirewallProfile @profileParams

                $blockedTcpPorts = @(21,23,135,139,445,3389,5985,5986)
                foreach ($port in $blockedTcpPorts) {
                    $ruleName = "AVA-SAFE-BLOCK-TCP-$port"
                    if (-not (Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue)) {
                        $ruleParams = @{
                            DisplayName = $ruleName
                            Direction = 'Inbound'
                            Action = 'Block'
                            Protocol = 'TCP'
                            LocalPort = $port
                            Profile = 'Any'
                            Description = 'AVA defensive local block rule. No outbound action.'
                        }
                        New-NetFirewallRule @ruleParams | Out-Null
                    }
                }

                Update-MpSignature -ErrorAction Continue
                $result.Actions += 'Firewall enabled for all profiles; inbound default set to block; outbound remains allowed.'
                $result.Actions += "Inbound TCP blocks ensured for ports: $($blockedTcpPorts -join ', ')"
                $result.Actions += 'Microsoft Defender signature update requested.'
            }
        }

        'Rollback' {
            if ([string]::IsNullOrWhiteSpace($FirewallBackupPath)) {
                throw 'Rollback requires -FirewallBackupPath pointing to a previously exported .wfw file.'
            }
            if (-not (Test-Path -LiteralPath $FirewallBackupPath -PathType Leaf)) {
                throw "Firewall backup not found: $FirewallBackupPath"
            }
            if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, "Restore firewall policy from $FirewallBackupPath")) {
                & netsh.exe advfirewall import $FirewallBackupPath | Out-Null
                $result.Actions += "Firewall policy restored from $FirewallBackupPath"
            }
        }
    }

    $reportJson = Join-Path $caseDir 'report.json'
    $result | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $reportJson -Encoding UTF8

    $encodedActions = ($result.Actions | ForEach-Object { '<li>' + [System.Net.WebUtility]::HtmlEncode($_) + '</li>' }) -join "`n"
    $html = @"
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>AVA Security Safe Report</title>
<style>
body{font-family:Segoe UI,Arial,sans-serif;background:#08111f;color:#e8f1ff;margin:2rem}
main{max-width:1000px;margin:auto;background:#101d31;padding:2rem;border-radius:14px}
h1{color:#56b4ff}.ok{color:#7ee787}.warn{color:#ffcc66}code{background:#06101d;padding:.15rem .35rem;border-radius:4px}
</style>
</head>
<body><main>
<h1>AVA Security Safe</h1>
<p><strong>Mode:</strong> $Mode</p>
<p class="ok"><strong>Boundary:</strong> Defensive local hardening only.</p>
<p class="warn">No counterattack, remote scan, SYSTEM persistence, endless loop, credential action, or third-party targeting was performed.</p>
<h2>Actions</h2><ul>$encodedActions</ul>
<p>Evidence directory: <code>$caseDir</code></p>
</main></body></html>
"@
    $reportHtml = Join-Path $caseDir 'report.html'
    $html | Set-Content -LiteralPath $reportHtml -Encoding UTF8

    Write-Host "AVA Security Safe completed: $caseDir" -ForegroundColor Green
    Write-Host "JSON: $reportJson"
    Write-Host "HTML: $reportHtml"
}
catch {
    Write-Error $_
    throw
}
finally {
    Stop-Transcript | Out-Null
}
