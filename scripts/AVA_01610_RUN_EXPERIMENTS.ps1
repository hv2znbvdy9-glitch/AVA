[CmdletBinding()]
param(
    [Parameter()]
    [string]$EvidencePath = (Join-Path ([System.IO.Path]::GetTempPath()) 'AVA_01610_EXPERIMENT_LATEST.json')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$StartedAt = [DateTime]::UtcNow
$RepositoryRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$OverallStatus = 'FAIL'
$TestExitCode = $null
$ScaleExitCode = $null
$NodeVersion = $null
$NpmVersion = $null
$ScaleReport = $null
$ScaleParseError = $null
$ExecutionError = $null
$EvidenceWriteError = $null

Push-Location -LiteralPath $RepositoryRoot
try {
    try {
        $NodeCommand = Get-Command 'node.exe' -ErrorAction Stop
        $NpmCommand = Get-Command 'npm.cmd' -ErrorAction SilentlyContinue
        if (-not $NpmCommand) {
            $NpmCommand = Get-Command 'npm' -ErrorAction Stop
        }

        $NodeExecutable = if ($NodeCommand.Source) { $NodeCommand.Source } else { $NodeCommand.Definition }
        $NpmExecutable = if ($NpmCommand.Source) { $NpmCommand.Source } else { $NpmCommand.Definition }
        $NodeVersion = (& $NodeExecutable --version | Out-String).Trim()
        if ($LASTEXITCODE -ne 0) { throw 'Unable to read Node.js version.' }
        $NpmVersion = (& $NpmExecutable --version | Out-String).Trim()
        if ($LASTEXITCODE -ne 0) { throw 'Unable to read npm version.' }

        Write-Host '[1/2] Running repository test suite: npm test'
        & $NpmExecutable test
        $TestExitCode = $LASTEXITCODE

        Write-Host '[2/2] Running bounded AVA/AVO scale model (690,000,000 logical nodes; 10,000 sampled observations)'
        $ScaleOutput = @(& $NodeExecutable 'src/scale-lab.js' '--nodes' '690000000' '--sample-size' '10000' '--seed' '1610')
        $ScaleExitCode = $LASTEXITCODE

        if ($ScaleExitCode -eq 0) {
            try {
                $ScaleReport = ($ScaleOutput -join [Environment]::NewLine) | ConvertFrom-Json -ErrorAction Stop
            } catch {
                $ScaleExitCode = 1
                $ScaleParseError = $_.Exception.Message
            }
        }

        if ($TestExitCode -eq 0 -and $ScaleExitCode -eq 0) {
            $OverallStatus = 'PASS'
        }
    } catch {
        $ExecutionError = $_.Exception.Message
        Write-Error -Message ("AVA experiment runner failed: " + $ExecutionError) -ErrorAction Continue
    }

    $FinishedAt = [DateTime]::UtcNow
    $Evidence = [ordered]@{
        schema = 'ava.01610.experiment-run.v1'
        status = $OverallStatus
        startedAtUtc = $StartedAt.ToString('o')
        finishedAtUtc = $FinishedAt.ToString('o')
        runtime = [ordered]@{
            nodeVersion = $NodeVersion
            npmVersion = $NpmVersion
            runner = 'Windows PowerShell; no administrator elevation required'
        }
        checks = @(
            [ordered]@{
                name = 'npm test'
                status = $(if ($TestExitCode -eq 0) { 'PASS' } elseif ($null -eq $TestExitCode) { 'NOT_RUN' } else { 'FAIL' })
                exitCode = $TestExitCode
            },
            [ordered]@{
                name = '690M logical-node analytical scale model'
                status = $(if ($ScaleExitCode -eq 0) { 'PASS' } elseif ($null -eq $ScaleExitCode) { 'NOT_RUN' } else { 'FAIL' })
                exitCode = $ScaleExitCode
                parseError = $ScaleParseError
            }
        )
        executionError = $ExecutionError
        scaleLabReport = $ScaleReport
        boundaries = [ordered]@{
            physicalServersCreated = 0
            cloudResourcesProvisioned = $false
            networkCallsMade = 0
            microphoneCaptured = $false
            audioPlayed = $false
            medicalActionOrAssessment = $false
            operatingSystemSettingsChanged = $false
            reportContainsDeviceIdentity = $false
            note = 'Audio tests process synthetic PCM samples only. Scale outputs are estimates based on declared assumptions, not measurements of real infrastructure or physiology.'
        }
    }

    try {
        $FullEvidencePath = [System.IO.Path]::GetFullPath($EvidencePath)
        $EvidenceDirectory = [System.IO.Path]::GetDirectoryName($FullEvidencePath)
        if (-not [System.IO.Directory]::Exists($EvidenceDirectory)) {
            [System.IO.Directory]::CreateDirectory($EvidenceDirectory) | Out-Null
        }
        $EvidenceJson = $Evidence | ConvertTo-Json -Depth 30
        [System.IO.File]::WriteAllText(
            $FullEvidencePath,
            $EvidenceJson + [Environment]::NewLine,
            [System.Text.UTF8Encoding]::new($false)
        )
        Write-Host ("Evidence JSON: " + $FullEvidencePath)
        Write-Host ("Overall result: " + $OverallStatus)
    } catch {
        $EvidenceWriteError = $_.Exception.Message
        Write-Error -Message ("Could not write evidence JSON: " + $EvidenceWriteError) -ErrorAction Continue
    }
} finally {
    Pop-Location
}

if ($OverallStatus -ne 'PASS' -or $EvidenceWriteError) {
    exit 1
}
exit 0
