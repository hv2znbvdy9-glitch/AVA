[CmdletBinding()]
param(
    [Parameter()]
    [string]$PackagePath = (Join-Path $PSScriptRoot '..'),
    [Parameter()]
    [string]$EvidencePath = (Join-Path ([System.IO.Path]::GetTempPath()) 'AVA_01610_SAFE_STARTPLAN.json')
)
# Inventory only. Never launches a .cmd/.ps1 file or changes Windows configuration.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ExpectedLaunchers = @(
    [ordered]@{ name = 'START_AVA_DEVITO_01610_SAFE_AUDIT_READONLY.cmd'; purpose = 'Read-only audit'; risk = 'low'; manualApprovalRequired = $false },
    [ordered]@{ name = 'START_AVA_SAFE_AUDIT_ADMIN.cmd'; purpose = 'Read-only audit (admin launcher)'; risk = 'low'; manualApprovalRequired = $false },
    [ordered]@{ name = 'START_01_RUNONCE_ADMIN.cmd'; purpose = 'Portal run-once'; risk = 'review package documentation'; manualApprovalRequired = $false },
    [ordered]@{ name = 'START_02_LIVE_PREVIEW_ADMIN.cmd'; purpose = 'Live preview'; risk = 'preview only; verify package contents'; manualApprovalRequired = $false },
    [ordered]@{ name = 'START_03_LIVE_AUTODEFENSE_MIT_BESTAETIGUNG_ADMIN.cmd'; purpose = 'Optional AutoDefense'; risk = 'may add firewall block rules'; manualApprovalRequired = $true },
    [ordered]@{ name = 'START_04_ROLLBACK_BLOCKS_ADMIN.cmd'; purpose = 'Rollback AVA block rules'; risk = 'review before use'; manualApprovalRequired = $true }
)
$StartedAt = [DateTime]::UtcNow
$Root = [System.IO.Path]::GetFullPath($PackagePath)
if (-not [System.IO.Directory]::Exists($Root)) { throw 'PackagePath does not exist. No files were changed.' }
$Items = foreach ($launcher in $ExpectedLaunchers) {
    $candidate = Join-Path $Root $launcher.name
    $relativePath = $launcher.name
    $present = [System.IO.File]::Exists($candidate)
    if (-not $present) {
        $scriptCandidate = Join-Path (Join-Path $Root 'scripts') $launcher.name
        if ([System.IO.File]::Exists($scriptCandidate)) {
            $candidate = $scriptCandidate
            $relativePath = Join-Path 'scripts' $launcher.name
            $present = $true
        }
    }
    $hash = $null
    $hashStatus = 'NOT_AVAILABLE'
    if ($present) {
        try {
            $hash = (Get-FileHash -LiteralPath $candidate -Algorithm SHA256 -ErrorAction Stop).Hash.ToLowerInvariant()
            $hashStatus = 'COMPUTED'
        } catch { $hashStatus = 'ERROR' }
    }
    [ordered]@{
        file = $launcher.name
        relativePath = $(if ($present) { $relativePath } else { $null })
        purpose = $launcher.purpose
        status = $(if ($present) { 'PRESENT' } else { 'MISSING' })
        sha256 = $hash
        hashStatus = $hashStatus
        risk = $launcher.risk
        manualApprovalRequired = $launcher.manualApprovalRequired
        executed = $false
    }
}
$MissingCount = @($Items | Where-Object { $_.status -eq 'MISSING' }).Count
$FinishedAt = [DateTime]::UtcNow
$Report = [ordered]@{
    schema = 'ava.01610.safe-startplan.v1'
    status = $(if ($MissingCount -eq 0) { 'COMPLETE_INVENTORY' } else { 'PARTIAL_INVENTORY' })
    mode = 'READ_ONLY'
    startedAtUtc = $StartedAt.ToString('o')
    finishedAtUtc = $FinishedAt.ToString('o')
    expectedLauncherCount = $ExpectedLaunchers.Count
    presentLauncherCount = @($Items | Where-Object { $_.status -eq 'PRESENT' }).Count
    missingLauncherCount = $MissingCount
    launchers = @($Items)
    safetyBoundaries = [ordered]@{
        launchersExecuted = $false
        autoDefenseEnabled = $false
        firewallChanged = $false
        defenderChanged = $false
        registryChanged = $false
        usersOrScheduledTasksChanged = $false
        powershellPolicyChanged = $false
        networkCallsMade = 0
        absolutePackagePathIncluded = $false
        note = 'Presence and SHA256 inventory only. A matching filename/hash does not prove a launcher is safe. Review source before any manual start. START_03 can block network addresses and requires explicit human review.'
    }
}
$FullEvidencePath = [System.IO.Path]::GetFullPath($EvidencePath)
$EvidenceDirectory = [System.IO.Path]::GetDirectoryName($FullEvidencePath)
if (-not [System.IO.Directory]::Exists($EvidenceDirectory)) { [System.IO.Directory]::CreateDirectory($EvidenceDirectory) | Out-Null }
[System.IO.File]::WriteAllText($FullEvidencePath, (($Report | ConvertTo-Json -Depth 10) + [Environment]::NewLine), [System.Text.UTF8Encoding]::new($false))
Write-Host ("AVA safe-start inventory: " + $Report.status)
Write-Host ("Present: " + $Report.presentLauncherCount + "; missing: " + $Report.missingLauncherCount)
Write-Host ("Evidence JSON: " + $FullEvidencePath)
Write-Host 'No launcher was executed and no Windows configuration was changed.'
if ($MissingCount -gt 0) { exit 2 }
exit 0
