#requires -Version 5.1
[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'High')]
param(
	[ValidateSet('Audit', 'Apply', 'Disable')]
	[string]$Mode = 'Audit'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$ruleName = 'AVA-01610-SMB445-InboundBlock'
$ruleDescription = 'AVA-01610: local inbound TCP-445 block'

function Get-AVAOwnedFirewallRule {
	$rule = Get-NetFirewallRule -Name $ruleName -ErrorAction SilentlyContinue
	if ($null -eq $rule) {
		return $null
	}

	if ($rule.Description -ne $ruleDescription -or
		$rule.Direction -ne 'Inbound' -or
		$rule.Action -ne 'Block') {
		throw "Rule name '$ruleName' exists but does not match AVA's expected rule; no change was made."
	}

	$portFilter = Get-NetFirewallPortFilter -AssociatedNetFirewallRule $rule
	if ($portFilter.Protocol -ne 'TCP' -or $portFilter.LocalPort -ne '445') {
		throw "Rule name '$ruleName' has an unexpected port filter; no change was made."
	}

	return $rule
}

switch ($Mode) {
	'Audit' {
		$listener = @(Get-NetTCPConnection -LocalPort 445 -State Listen -ErrorAction SilentlyContinue |
			Select-Object LocalAddress, LocalPort, State, OwningProcess)
		$service = Get-Service -Name 'LanmanServer' -ErrorAction SilentlyContinue |
			Select-Object Name, Status, StartType
		$rule = Get-AVAOwnedFirewallRule

		[pscustomobject]@{
			Mode = $Mode
			TimestampUtc = (Get-Date).ToUniversalTime().ToString('o')
			Listeners = $listener
			LanmanServer = $service
			FirewallRule = if ($null -eq $rule) { $null } else {
				$rule | Select-Object Name, DisplayName, Enabled, Direction, Action, Profile
			}
			ChangesMade = $false
		}
	}

	'Apply' {
		$rule = Get-AVAOwnedFirewallRule
		if ($null -ne $rule) {
			Write-Output "AVA rule '$ruleName' already exists; no change was made."
			break
		}

		if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, "Create inbound TCP 445 block rule '$ruleName'")) {
			New-NetFirewallRule -Name $ruleName -DisplayName $ruleName `
				-Direction Inbound -Action Block -Protocol TCP -LocalPort 445 `
				-Profile Any -Description $ruleDescription | Out-Null
			Write-Output "Created inbound TCP 445 block rule '$ruleName'."
		}
	}

	'Disable' {
		$rule = Get-AVAOwnedFirewallRule
		if ($null -eq $rule) {
			Write-Output "AVA rule '$ruleName' was not found; no change was made."
			break
		}

		if ($rule.Enabled -eq 'False') {
			Write-Output "AVA rule '$ruleName' is already disabled; no change was made."
			break
		}

		if ($PSCmdlet.ShouldProcess($env:COMPUTERNAME, "Disable AVA rule '$ruleName'")) {
			Disable-NetFirewallRule -Name $ruleName
			Write-Output "Disabled AVA rule '$ruleName'; its definition was retained."
		}
	}
}
