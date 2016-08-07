[CmdletBinding()]
Param(
    [Parameter(Mandatory=$false)] [switch]$ws7e=$false,
    [Parameter(Mandatory=$false)] [switch]$proxydisable=$false,
    [Parameter(Mandatory=$false)] [switch]$configure_cmd_console=$false,
    [Parameter(Mandatory=$false)] [switch]$errorreportingdisable=$false,
    [Parameter(Mandatory=$false)] [switch]$priorityBackgroundServices=$true,
    [Parameter(Mandatory=$false)] [switch]$removeieshortcut=$false,
    [Parameter(Mandatory=$false)] [switch]$bestPerformance=$false,
    [Parameter(Mandatory=$false)] [switch]$addtaylorsshortcuts=$false
)

. '.\include.ps1'

function mark_as_ran($keyname)
{
	New-Item -Type Directory -Force -Path HKCU:\Software\Streambox\win_settings
	New-ItemProperty -Path HKCU:\Software\Streambox\win_settings -Name $keyname -Value 1 `
	  -PropertyType DWORD -Force | Out-Null
}

<#
https://goo.gl/EluKKE
#>
function bestPerformance()
{
	if((Test-RegistryKeyValue 'HKCU:\Software\Streambox\win_settings' 'bestPerformance')){
		return 
	}

	$path = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects'
	try {
		$s = (Get-ItemProperty -ErrorAction stop `
		  -Name visualfxsetting -Path $path).visualfxsetting
		if ($s -ne 2) {
			Set-ItemProperty -Path $path -Name VisualFXSetting -Value 2
		}
	}
	catch {
		New-ItemProperty -Path $path -Name VisualFXSetting -Value 2 -PropertyType DWORD
	}

	mark_as_ran 'bestPerformance'
}

<#
https://goo.gl/AlWgg9

# this will prioritize background services
.\set-processorscheduling.ps1 -BackgroundServices

# this will prioritize programs
.\set-processorscheduling.ps1 -Programs 
#>

function set-processorscheduling()
{
	param
	(
		[switch]$Programs,
		[switch]$BackgroundServices
	)

	if((Test-RegistryKeyValue 'HKCU:\Software\Streambox\win_settings' 'set-processorscheduling')){
		return 
	}

	if($Programs)
	{
		Set-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl `
		  -Name Win32PrioritySeparation -Value 2
	}
	elseif($BackgroundServices)
	{
		Set-ItemProperty HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl `
		  -Name Win32PrioritySeparation -Value 18
	}
	else
	{
		Write-Output "You must specify a flag!"
	}

	mark_as_ran 'set-processorscheduling'
}

function configure_cmd_console()
{

	if((Test-RegistryKeyValue 'HKCU:\Software\Streambox\win_settings' 'configure_cmd_console')){
		return 
	}

	# (Get-ItemProperty -Path HKCU:\Console -Name QuickEdit).QuickEdit
	Set-ItemProperty -path HKCU:\Console -name QuickEdit -Type Dword -value 1

    #ScreenBufferSize 120 w x 300 h
	Set-ItemProperty -path HKCU:\Console -name ScreenBufferSize -Type Dword -value 0x12c0078

    #WindowSize 110 w x 23 h
	Set-ItemProperty -path HKCU:\Console -name WindowSize -Type Dword -value 0x190078

	mark_as_ran 'configure_cmd_console'

}

function error_reporting_disable()
{

	if((Test-RegistryKeyValue 'HKCU:\Software\Streambox\win_settings' 'error_reporting_disable')){
		return 
	}

	# Disable error reporting for current user
	set-itemproperty -path 'HKCU:\Software\Microsoft\Windows\Windows Error Reporting' `
	  -Type DWord -name DontShowUI -value 1

	mark_as_ran 'error_reporting_disable'

}

function proxy_disable()
{

	# don't run twice for same user
	if((Test-RegistryKeyValue 'HKCU:\Software\Streambox\win_settings' 'disable_proxy_ran')){
		return 
	}

	function Disable-AutomaticallyDetectProxySettings
	{
		# Read connection settings from Internet Explorer.
		$regKeyPath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Internet Settings\Connections\"
		$conSet = $(Get-ItemProperty $regKeyPath).DefaultConnectionSettings
		
		# Index into DefaultConnectionSettings where the relevant flag resides.
		$flagIndex = 8
		
		# Bit inside the relevant flag which indicates whether or not to enable automatically detect proxy settings.
		$autoProxyFlag = 8
		
		if ($($conSet[$flagIndex] -band $autoProxyFlag) -eq $autoProxyFlag)
		{
			# 'Automatically detect proxy settings' was enabled, adding one disables it.
			Write-Host "Disabling 'Automatically detect proxy settings'."
			$mask = -bnot $autoProxyFlag
			$conSet[$flagIndex] = $conSet[$flagIndex] -band $mask
			$conSet[4]++
			Set-ItemProperty -Path $regKeyPath -Name DefaultConnectionSettings -Value $conSet
		}
		
		$conSet = $(Get-ItemProperty $regKeyPath).DefaultConnectionSettings
		if ($($conSet[$flagIndex] -band $autoProxyFlag) -ne $autoProxyFlag)
		{
    		Write-Host "'Automatically detect proxy settings' is disabled."
		}
	}

	$job = Start-Job -ScriptBlock {
		$dir = (${env:ProgramFiles(x86)}, ${env:ProgramFiles} -ne $null)[0]
		$ie = "{0}\Internet Explorer\iexplore.exe" -f $dir
		Start-Process $ie -WindowStyle Minimized -Wait -PassThru
	}
	Start-Sleep -Seconds 5
	Stop-Job -Id $job.Id

	Disable-AutomaticallyDetectProxySettings

	Set-Itemproperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings\Connections" -Name ProxyEnable -Value 0

	taskkill /f /im iexplore.exe

	mark_as_ran 'disable_proxy_ran'

}

if($ws7e)
{
	$proxydisable = $true
	$errorreportingdisable = $true
	$configure_cmd_console = $true
	$removeieshortcut = $true
	$priorityBackgroundServices = $true
	$bestPerformance = $true
}

function main()
{
	if($proxydisable)
	{
		proxy_disable
	}

	if($errorreportingdisable)
	{
		error_reporting_disable
	}

	if($configure_cmd_console)
	{
		configure_cmd_console
 	}

	if($priorityBackgroundServices)
	{
		set-processorscheduling -BackgroundServices
	}

	if($bestPerformance)
	{
		bestPerformance
	}
}

main
