[CmdletBinding()]
Param (
	[Parameter(Mandatory=$false)]
	[ValidateSet('Install','Uninstall')]
	[string]$DeploymentType = 'Install',
	[Parameter(Mandatory=$false)]
	[ValidateSet('Interactive','Silent','NonInteractive')]
	[string]$DeployMode = 'Interactive',
	[Parameter(Mandatory=$false)]
	[switch]$AllowRebootPassThru = $false,
	[Parameter(Mandatory=$false)]
	[switch]$TerminalServerMode = $false,
	[Parameter(Mandatory=$false)]
	[switch]$DisableLogging = $false
)

Try {
	## Set the script execution policy for this process
	Try { Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop' } Catch {}
	
	##*===============================================
	##* VARIABLE DECLARATION
	##*===============================================
	## Variables: Application
	[string]$appVendor = ''
	[string]$appName = 'Lightning Node'
	[string]$appVersion = ''
	[string]$appArch = ''
	[string]$appLang = ''
	[string]$appRevision = ''
	[string]$appScriptVersion = ''
	[string]$appScriptDate = ''
	[string]$appScriptAuthor = 'Kevin Haffner'
	##*===============================================
	## Variables: Install Titles (Only set here to override defaults set by the toolkit)
	[string]$installName = ''
	[string]$installTitle = ''
	
	##* Do not modify section below
	#region DoNotModify
	
	## Variables: Exit Code
	[int32]$mainExitCode = 0
	
	## Variables: Script
	[string]$deployAppScriptFriendlyName = 'Deploy Application'
	[version]$deployAppScriptVersion = [version]'3.7.0'
	[string]$deployAppScriptDate = '01/01/2018'
	[hashtable]$deployAppScriptParameters = $psBoundParameters
	
	## Variables: Environment
	If (Test-Path -LiteralPath 'variable:HostInvocation') { $InvocationInfo = $HostInvocation } Else { $InvocationInfo = $MyInvocation }
	[string]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent
	
	## Dot source the required App Deploy Toolkit Functions
	Try {
		[string]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"
		If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) { Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]." }
		If ($DisableLogging) { . $moduleAppDeployToolkitMain -DisableLogging } Else { . $moduleAppDeployToolkitMain }
	}
	Catch {
		If ($mainExitCode -eq 0){ [int32]$mainExitCode = 60008 }
		Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
		## Exit the script, returning the exit code to SCCM
		If (Test-Path -LiteralPath 'variable:HostInvocation') { $script:ExitCode = $mainExitCode; Exit } Else { Exit $mainExitCode }
	}
	
	#endregion
	##* Do not modify section above
	##*===============================================
	##* END VARIABLE DECLARATION
	##*===============================================
		
	If ($deploymentType -ine 'Uninstall') {
		##*===============================================
		##* PRE-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Installation'

		
        ## Show Progress Message (with the default message)
		Show-InstallationProgress
		
		## <Perform Pre-Installation tasks here>
		
		
		##*===============================================
		##* INSTALLATION 
		##*===============================================
		[string]$installPhase = 'Installation'
		
		## Handle Zero-Config MSI Installations
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat =  @{ Action = 'Install'; Path = $defaultMsiFile }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat; If ($defaultMspFiles) { $defaultMspFiles | ForEach-Object { Execute-MSI -Action 'Patch' -Path $_ } }
		}
		
		## <Perform Installation tasks here>
		
        $NodeInstallerUri = ((Invoke-WebRequest -Uri 'https://nodejs.org/en/download/').Links | where href -Like '*x64.msi').href
        $NodeInstallerPath = "$env:TEMP\NodeInstaller.msi"
        Invoke-WebRequest -Uri $NodeInstallerUri -OutFile $NodeInstallerPath
        
        $GitInstallerUri = ((Invoke-WebRequest -Uri "https://git-scm.com/download/win").Links | where href -Like '*64-bit.exe').href | select -First 1
        $GitInstallerPath = "$env:TEMP\GitInstaller.exe"
        Invoke-WebRequest -Uri $GitInstallerUri -OutFile $GitInstallerPath

        $YarnInstallerUri = "https://yarnpkg.com/latest.msi"
        $YarnInstallerPath = "$env:TEMP\YarnInstaller.msi"
        Invoke-WebRequest -Uri $YarnInstallerUri -OutFile $YarnInstallerPath


        $VisualCPlusPlus2015BuildToolsInstallerUri = "http://go.microsoft.com/fwlink/?LinkId=691126&fixForIE=.exe"
        $VisualCPlusPlus2015BuildToolsInstallerPath = "$env:TEMP\VisualCPlusPlus2015BuildToolsInstaller.exe"
        Invoke-WebRequest -Uri $VisualCPlusPlus2015BuildToolsUri -OutFile $VisualCPlusPlus2015BuildToolsPath

        if (Test-Path (Get-Variable -Name *InstallerPath).Value) {
            Execute-MSI -Action Install -Path $NodeInstallerPath
            Execute-Process             -Path $GitInstallerPath -Parameters '/SILENT /NORESTART'
            Execute-MSI -Action Install -Path $YarnInstallerPath
            Execute-Process             -Path $VisualCPlusPlus2015BuildToolsInstallerUri -Parameters '/Passive /Norestart'
            #Show-InstallationRestartPrompt
        }



		
		##*===============================================
		##* POST-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Installation'
		
		## <Perform Post-Installation tasks here>
		
		## Display a message at the end of the install
		If (-not $useDefaultMsi) { Show-InstallationPrompt -Message 'You can customize text to appear at the end of an install or remove it completely for unattended installations.' -ButtonRightText 'OK' -Icon Information -NoWait }
	}
	ElseIf ($deploymentType -ieq 'Uninstall')
	{
		##*===============================================
		##* PRE-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Uninstallation'
		
		## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing
		Show-InstallationWelcome -CloseApps 'iexplore' -CloseAppsCountdown 60
		
		## Show Progress Message (with the default message)
		Show-InstallationProgress
		
		## <Perform Pre-Uninstallation tasks here>
		
		
		##*===============================================
		##* UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Uninstallation'
		
		## Handle Zero-Config MSI Uninstallations
		If ($useDefaultMsi) {
			[hashtable]$ExecuteDefaultMSISplat =  @{ Action = 'Uninstall'; Path = $defaultMsiFile }; If ($defaultMstFile) { $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile) }
			Execute-MSI @ExecuteDefaultMSISplat
		}
		
		# <Perform Uninstallation tasks here>
		
		
		##*===============================================
		##* POST-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Uninstallation'
		
		## <Perform Post-Uninstallation tasks here>
		
		
	}
	
	##*===============================================
	##* END SCRIPT BODY
	##*===============================================
	
	## Call the Exit-Script function to perform final cleanup operations
	Exit-Script -ExitCode $mainExitCode
}
Catch {
	[int32]$mainExitCode = 60001
	[string]$mainErrorMessage = "$(Resolve-Error)"
	Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
	Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
	Exit-Script -ExitCode $mainExitCode
}