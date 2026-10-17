# AVA DEVITO 01610-15 SAFE AUDIT
# Read-only system inspection; writes a minimized report to the Desktop.
# Does not change firewall, Defender, registry, services, tasks, or user settings.
$ErrorActionPreference = 'Continue'

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$desktop = [Environment]::GetFolderPath('Desktop')
if ([string]::IsNullOrWhiteSpace($desktop) -or -not (Test-Path -LiteralPath $desktop)) {
    $desktop = (Get-Location).Path
}
$outDir = Join-Path $desktop "AVA_SAFE_AUDIT_$stamp"
New-Item -ItemType Directory -Path $outDir -Force | Out-Null

$report = [ordered]@{
    schema = 'ava.safe-audit.v1'
    mode = 'READ_ONLY'
    collectedAt = (Get-Date).ToString('o')
    computerName = $env:COMPUTERNAME
    powershellVersion = $PSVersionTable.PSVersion.ToString()
    operatingSystem = $null
    defender = $null
    firewallProfiles = @()
    selectedServices = @()
    networkAdapters = @()
    recentSystemEventSummary = @()
    limitations = @(
        'Report omits user names, IP/MAC addresses, process command lines, registry autoruns, download names and full event messages.'
        'Read-only means no system configuration changes; report files are written to the output directory.'
        'Missing permissions or unavailable cmdlets may result in incomplete sections.'
    )
}

try {
    $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
    $report.operatingSystem = [ordered]@{
        caption = $os.Caption
        version = $os.Version
        buildNumber = $os.BuildNumber
        architecture = $os.OSArchitecture
        lastBootUpTime = if ($os.LastBootUpTime) { $os.LastBootUpTime.ToString('o') } else { $null }
    }
} catch {
    $report.operatingSystem = @{ status = 'unavailable'; errorType = $_.Exception.GetType().Name }
}

try {
    if (Get-Command Get-MpComputerStatus -ErrorAction SilentlyContinue) {
        $d = Get-MpComputerStatus -ErrorAction Stop
        $report.defender = [ordered]@{
            antivirusEnabled = $d.AntivirusEnabled
            realTimeProtectionEnabled = $d.RealTimeProtectionEnabled
            behaviorMonitorEnabled = $d.BehaviorMonitorEnabled
            signatureLastUpdated = if ($d.AntivirusSignatureLastUpdated) { $d.AntivirusSignatureLastUpdated.ToString('o') } else { $null }
        }
    } else {
        $report.defender = @{ status = 'Get-MpComputerStatus unavailable' }
    }
} catch {
    $report.defender = @{ status = 'unavailable'; errorType = $_.Exception.GetType().Name }
}

try {
    if (Get-Command Get-NetFirewallProfile -ErrorAction SilentlyContinue) {
        $report.firewallProfiles = @(Get-NetFirewallProfile -ErrorAction Stop | Select-Object Name, Enabled, DefaultInboundAction, DefaultOutboundAction)
    } else {
        $report.firewallProfiles = @(@{ status = 'Get-NetFirewallProfile unavailable' })
    }
} catch {
    $report.firewallProfiles = @(@{ status = 'unavailable'; errorType = $_.Exception.GetType().Name })
}

try {
    $serviceNames = @('WinDefend', 'wuauserv', 'RemoteRegistry', 'TermService', 'WinRM', 'BITS', 'EventLog')
    $report.selectedServices = @(
        foreach ($name in $serviceNames) {
            Get-Service -Name $name -ErrorAction SilentlyContinue |
                Select-Object Name, Status, StartType
        }
    )
} catch {
    $report.selectedServices = @(@{ status = 'unavailable'; errorType = $_.Exception.GetType().Name })
}

try {
    if (Get-Command Get-NetAdapter -ErrorAction SilentlyContinue) {
        $report.networkAdapters = @(Get-NetAdapter -ErrorAction Stop | Select-Object Name, Status, LinkSpeed)
    } else {
        $report.networkAdapters = @(@{ status = 'Get-NetAdapter unavailable' })
    }
} catch {
    $report.networkAdapters = @(@{ status = 'unavailable'; errorType = $_.Exception.GetType().Name })
}

try {
    $start = (Get-Date).AddDays(-7)
    $report.recentSystemEventSummary = @(
        Get-WinEvent -FilterHashtable @{ LogName = 'System'; StartTime = $start; Level = 1, 2, 3 } -MaxEvents 100 -ErrorAction Stop |
            Group-Object ProviderName, LevelDisplayName |
            ForEach-Object {
                [ordered]@{ providerAndLevel = $_.Name; count = $_.Count }
            }
    )
} catch {
    $report.recentSystemEventSummary = @(@{ status = 'unavailable'; errorType = $_.Exception.GetType().Name })
}

$jsonPath = Join-Path $outDir 'ava-safe-audit.json'
$report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
Write-Host 'AVA SAFE AUDIT abgeschlossen.' -ForegroundColor Green
Write-Host "Report: $jsonPath" -ForegroundColor Cyan
Write-Host 'Es wurden keine Systemkonfigurationen geändert. Prüfe den Bericht vor dem Teilen auf sensible Daten.' -ForegroundColor Yellow
