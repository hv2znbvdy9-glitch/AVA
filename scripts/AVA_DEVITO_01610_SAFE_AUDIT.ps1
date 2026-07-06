$ErrorActionPreference = 'Continue'

Write-Host ''
Write-Host 'AVA DEVITO 01610 SAFE AUDIT startet...' -ForegroundColor Green
Write-Host 'Modus: READ-ONLY / keine Systemaenderungen' -ForegroundColor Cyan
Write-Host ''

$Stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$Desktop = [Environment]::GetFolderPath('Desktop')
$Root = Join-Path $Desktop "AVA_SAFE_AUDIT_$Stamp"
$DataDir = Join-Path $Root 'data'
$LogDir = Join-Path $Root 'logs'

New-Item -ItemType Directory -Path $Root, $DataDir, $LogDir -Force | Out-Null

$TranscriptPath = Join-Path $LogDir 'transcript.txt'
Start-Transcript -Path $TranscriptPath -Force | Out-Null

function Test-IsAdmin {
    try {
        $Identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $Principal = New-Object Security.Principal.WindowsPrincipal($Identity)
        return $Principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        return $false
    }
}

function Save-Json {
    param(
        [string]$Name,
        [object]$Object
    )

    $Path = Join-Path $DataDir "$Name.json"

    try {
        $Object | ConvertTo-Json -Depth 10 | Out-File -FilePath $Path -Encoding UTF8
    } catch {
        @{
            section = $Name
            error = $_.Exception.Message
            time = Get-Date
        } | ConvertTo-Json -Depth 5 | Out-File -FilePath $Path -Encoding UTF8
    }
}

function Save-Text {
    param(
        [string]$Name,
        [object]$Object
    )

    $Path = Join-Path $DataDir "$Name.txt"

    try {
        $Object | Out-String -Width 400 | Out-File -FilePath $Path -Encoding UTF8
    } catch {
        "ERROR: $($_.Exception.Message)" | Out-File -FilePath $Path -Encoding UTF8
    }
}

function Run-Safe {
    param(
        [string]$Name,
        [scriptblock]$Block
    )

    Write-Host "[AVA] Sammle: $Name" -ForegroundColor DarkCyan

    try {
        $Result = & $Block
        Save-Json -Name $Name -Object $Result
        Save-Text -Name $Name -Object $Result
        return $Result
    } catch {
        $Err = [pscustomobject]@{
            section = $Name
            error = $_.Exception.Message
            time = Get-Date
        }

        Save-Json -Name $Name -Object $Err
        Save-Text -Name $Name -Object $Err
        return $Err
    }
}

$IsAdmin = Test-IsAdmin

$Summary = [ordered]@{
    AVA_Mode = 'SAFE_AUDIT_DIRECT_PASTE_v1'
    Time = Get-Date
    ComputerName = $env:COMPUTERNAME
    UserName = "$env:USERDOMAIN\$env:USERNAME"
    IsAdmin = $IsAdmin
    OutputRoot = $Root
    Safety = 'Read-only audit. No firewall, Defender, Registry, user, service, or scheduled-task changes.'
}

Save-Json '00_summary' $Summary
Save-Text '00_summary' $Summary

$SystemInfo = Run-Safe '01_system_info' {
    Get-ComputerInfo | Select-Object `
        CsName,
        WindowsProductName,
        WindowsVersion,
        OsName,
        OsVersion,
        OsBuildNumber,
        OsArchitecture,
        BiosFirmwareType,
        CsManufacturer,
        CsModel,
        CsTotalPhysicalMemory,
        TimeZone,
        LogonServer
}

$Defender = Run-Safe '02_defender_status' {
    if (Get-Command Get-MpComputerStatus -ErrorAction SilentlyContinue) {
        Get-MpComputerStatus | Select-Object `
            AMServiceEnabled,
            AntivirusEnabled,
            AntispywareEnabled,
            RealTimeProtectionEnabled,
            BehaviorMonitorEnabled,
            IoavProtectionEnabled,
            NISEnabled,
            OnAccessProtectionEnabled,
            IsTamperProtected,
            AntivirusSignatureLastUpdated,
            QuickScanEndTime,
            FullScanEndTime
    } else {
        [pscustomobject]@{
            status = 'Get-MpComputerStatus nicht verfügbar'
        }
    }
}

$FirewallProfiles = Run-Safe '03_firewall_profiles' {
    if (Get-Command Get-NetFirewallProfile -ErrorAction SilentlyContinue) {
        Get-NetFirewallProfile | Select-Object `
            Name,
            Enabled,
            DefaultInboundAction,
            DefaultOutboundAction,
            NotifyOnListen
    } else {
        [pscustomobject]@{
            status = 'Get-NetFirewallProfile nicht verfügbar'
        }
    }
}

$Admins = Run-Safe '04_local_administrators' {
    if (Get-Command Get-LocalGroupMember -ErrorAction SilentlyContinue) {
        Get-LocalGroupMember -Group 'Administrators' |
            Select-Object Name, ObjectClass, PrincipalSource
    } else {
        net localgroup administrators
    }
}

$Users = Run-Safe '05_local_users' {
    if (Get-Command Get-LocalUser -ErrorAction SilentlyContinue) {
        Get-LocalUser |
            Select-Object Name, Enabled, LastLogon, PasswordRequired, PasswordLastSet
    } else {
        net user
    }
}

$Services = Run-Safe '06_critical_services' {
    $Names = @(
        'WinDefend',
        'wuauserv',
        'RemoteRegistry',
        'TermService',
        'WinRM',
        'BITS',
        'EventLog'
    )

    foreach ($Name in $Names) {
        Get-Service -Name $Name -ErrorAction SilentlyContinue |
            Select-Object Name, DisplayName, Status, StartType
    }
}

$NetworkAdapters = Run-Safe '07_network_adapters' {
    if (Get-Command Get-NetAdapter -ErrorAction SilentlyContinue) {
        Get-NetAdapter |
            Select-Object Name, InterfaceDescription, Status, MacAddress, LinkSpeed
    } else {
        ipconfig /all
    }
}

$IPConfig = Run-Safe '08_ip_config' {
    if (Get-Command Get-NetIPConfiguration -ErrorAction SilentlyContinue) {
        Get-NetIPConfiguration |
            Select-Object InterfaceAlias, IPv4Address, IPv6Address, IPv4DefaultGateway, DNSServer
    } else {
        ipconfig /all
    }
}

$Connections = Run-Safe '09_established_connections' {
    if (Get-Command Get-NetTCPConnection -ErrorAction SilentlyContinue) {
        Get-NetTCPConnection -State Established -ErrorAction SilentlyContinue |
            ForEach-Object {
                $PidValue = $_.OwningProcess
                $Proc = Get-Process -Id $PidValue -ErrorAction SilentlyContinue

                [pscustomobject]@{
                    LocalAddress = $_.LocalAddress
                    LocalPort = $_.LocalPort
                    RemoteAddress = $_.RemoteAddress
                    RemotePort = $_.RemotePort
                    State = $_.State
                    OwningProcess = $PidValue
                    ProcessName = $Proc.ProcessName
                    ProcessPath = $Proc.Path
                }
            } |
            Sort-Object ProcessName, RemoteAddress, RemotePort
    } else {
        netstat -ano
    }
}

$Processes = Run-Safe '10_processes' {
    Get-Process |
        Select-Object Id, ProcessName, Path, CPU, StartTime -ErrorAction SilentlyContinue |
        Sort-Object ProcessName
}

$SuspiciousProcesses = Run-Safe '11_interesting_process_names' {
    $Patterns = 'powershell|pwsh|cmd|wscript|cscript|mshta|rundll32|regsvr32|certutil|bitsadmin|python|node|curl|wget'

    Get-Process |
        Where-Object { $_.ProcessName -match $Patterns } |
        Select-Object Id, ProcessName, Path, StartTime -ErrorAction SilentlyContinue |
        Sort-Object ProcessName
}

$Tasks = Run-Safe '12_scheduled_tasks_non_microsoft' {
    if (Get-Command Get-ScheduledTask -ErrorAction SilentlyContinue) {
        Get-ScheduledTask |
            Where-Object { $_.TaskPath -notlike '\Microsoft\*' } |
            Select-Object TaskName, TaskPath, State, Author, Description
    } else {
        schtasks /query /fo LIST /v
    }
}

$Autoruns = Run-Safe '13_registry_autoruns_readonly' {
    $Paths = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'
    )

    foreach ($Path in $Paths) {
        if (Test-Path $Path) {
            [pscustomobject]@{
                RegistryPath = $Path
                Values = Get-ItemProperty -Path $Path
            }
        }
    }
}

$PowerShellEvents = Run-Safe '14_powershell_suspicious_events_last_7_days' {
    $Start = (Get-Date).AddDays(-7)
    $Suspicious = '-enc|encodedcommand|frombase64string|downloadstring|invoke-expression|iex|-nop|noprofile|windowstyle hidden|-w hidden|executionpolicy bypass|bitsadmin|certutil|mshta|regsvr32|rundll32|wscript|cscript'

    $Logs = @(
        'Windows PowerShell',
        'Microsoft-Windows-PowerShell/Operational'
    )

    foreach ($Log in $Logs) {
        try {
            Get-WinEvent -FilterHashtable @{
                LogName = $Log
                StartTime = $Start
            } -MaxEvents 700 -ErrorAction Stop |
                Where-Object { $_.Message -match $Suspicious } |
                Select-Object TimeCreated, ProviderName, Id, LevelDisplayName, Message
        } catch {
            [pscustomobject]@{
                Log = $Log
                Status = 'Nicht lesbar oder nicht verfügbar'
                Error = $_.Exception.Message
            }
        }
    }
}

$SystemEvents = Run-Safe '15_system_errors_last_7_days' {
    $Start = (Get-Date).AddDays(-7)

    Get-WinEvent -FilterHashtable @{
        LogName = 'System'
        StartTime = $Start
        Level = 1,2,3,4,5
    } -MaxEvents 250 -ErrorAction SilentlyContinue |
        Select-Object TimeCreated, ProviderName, Id, LevelDisplayName, Message
}

$DefenderEvents = Run-Safe '16_defender_events_last_14_days' {
    $Start = (Get-Date).AddDays(-14)

    try {
        Get-WinEvent -FilterHashtable @{
            LogName = 'Microsoft-Windows-Windows Defender/Operational'
            StartTime = $Start
        } -MaxEvents 999 -ErrorAction Stop |
            Select-Object TimeCreated, ProviderName, Id, LevelDisplayName, Message
    } catch {
        [pscustomobject]@{
            Status = 'Defender Eventlog nicht lesbar oder nicht verfügbar'
            Error = $_.Exception.Message
        }
    }
}

$DownloadsHashes = Run-Safe '17_recent_downloads_hashes' {
    $Downloads = Join-Path $env:USERPROFILE 'Downloads'

    if (Test-Path $Downloads) {
        Get-ChildItem -Path $Downloads -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 60 |
            ForEach-Object {
                $Hash = Get-FileHash -Path $_.FullName -Algorithm SHA256 -ErrorAction SilentlyContinue

                [pscustomobject]@{
                    Name = $_.Name
                    FullName = $_.FullName
                    Length = $_.Length
                    LastWriteTime = $_.LastWriteTime
                    SHA256 = $Hash.Hash
                }
            }
    } else {
        [pscustomobject]@{
            Status = 'Downloads-Ordner nicht gefunden'
        }
    }
}

$Findings = New-Object System.Collections.Generic.List[object]

function Add-Finding {
    param(
        [string]$Level,
        [string]$Title,
        [string]$Detail
    )

    $Findings.Add([pscustomobject]@{
        Level = $Level
        Title = $Title
        Detail = $Detail
    })
}

if (-not $IsAdmin) {
    Add-Finding 'INFO' 'Nicht als Administrator gestartet' 'Einige Bereiche können fehlen. Für vollständigere Logs PowerShell als Administrator öffnen.'
}

try {
    if ($Defender.RealTimeProtectionEnabled -eq $false) {
        Add-Finding 'HIGH' 'Defender Echtzeitschutz aus' 'RealTimeProtectionEnabled ist false.'
    }
} catch {}

try {
    foreach ($Profile in $FirewallProfiles) {
        if ($Profile.Enabled -eq $false) {
            Add-Finding 'MEDIUM' 'Firewall-Profil deaktiviert' "$($Profile.Name) ist deaktiviert."
        }
    }
} catch {}

try {
    $RemoteRiskServices = $Services | Where-Object {
        ($_.Name -eq 'RemoteRegistry' -and $_.Status -eq 'Running') -or
        ($_.Name -eq 'WinRM' -and $_.Status -eq 'Running') -or
        ($_.Name -eq 'TermService' -and $_.Status -eq 'Running')
    }

    foreach ($Svc in $RemoteRiskServices) {
        Add-Finding 'INFO' 'Remote-Dienst läuft' "$($Svc.Name) / $($Svc.DisplayName) läuft. Das ist nicht automatisch böse, aber prüfenswert."
    }
} catch {}

try {
    if ($SuspiciousProcesses.Count -gt 0) {
        Add-Finding 'INFO' 'Interessante Prozessnamen gefunden' 'PowerShell/CMD/Scripting/LOLBin-Prozesse wurden gefunden. Details in 11_interesting_process_names.'
    }
} catch {}

Save-Json '18_findings' $Findings
Save-Text '18_findings' $Findings

$HtmlPath = Join-Path $Root 'AVA_SAFE_AUDIT_REPORT.html'

$HtmlFindings = foreach ($F in $Findings) {
    "<tr><td>$($F.Level)</td><td>$($F.Title)</td><td>$($F.Detail)</td></tr>"
}

if (-not $HtmlFindings) {
    $HtmlFindings = '<tr><td>OK</td><td>Keine kritischen Sofort-Findings</td><td>Details trotzdem in den Daten prüfen.</td></tr>'
}

$Html = @"
<!doctype html>
<html lang="de">
<head>
<meta charset="utf-8">
<title>AVA Safe Audit Report</title>
<style>
body { font-family: Arial, sans-serif; background: #111; color: #eee; margin: 24px; }
h1, h2 { color: #f5f5f5; }
.card { background: #1d1d1d; border: 1px solid #333; border-radius: 12px; padding: 16px; margin: 14px 0; }
table { border-collapse: collapse; width: 100%; }
td, th { border: 1px solid #444; padding: 8px; vertical-align: top; }
th { background: #292929; }
code { background: #222; padding: 2px 6px; border-radius: 6px; }
.ok { color: #9be28f; }
.warn { color: #ffd36b; }
</style>
</head>
<body>
<h1>AVA Safe Audit Report</h1>

<div class="card">
<h2>Status</h2>
<p><b>Modus:</b> SAFE AUDIT / Read-only</p>
<p><b>Zeit:</b> $($Summary.Time)</p>
<p><b>Computer:</b> $($Summary.ComputerName)</p>
<p><b>User:</b> $($Summary.UserName)</p>
<p><b>Administrator:</b> $($Summary.IsAdmin)</p>
<p class="ok"><b>Sicherheit:</b> Keine Änderungen an Firewall, Defender, Registry, Benutzern, Services oder Tasks.</p>
</div>

<div class="card">
<h2>Findings</h2>
<table>
<tr><th>Level</th><th>Titel</th><th>Detail</th></tr>
$($HtmlFindings -join "`n")
</table>
</div>

</body>
</html>
"@

$Html | Out-File -FilePath $HtmlPath -Encoding UTF8

Stop-Transcript | Out-Null

$ZipPath = Join-Path $Desktop "AVA_SAFE_AUDIT_$Stamp.zip"

try {
    Compress-Archive -Path $Root -DestinationPath $ZipPath -Force
} catch {
    Write-Warning "ZIP konnte nicht erstellt werden: $($_.Exception.Message)"
}

Write-Host ''
Write-Host 'AVA SAFE AUDIT fertig.' -ForegroundColor Green
Write-Host "Report: $HtmlPath" -ForegroundColor Cyan
Write-Host "ZIP:    $ZipPath" -ForegroundColor Cyan
Write-Host ''

Start-Process $HtmlPath
