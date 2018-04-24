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
	[switch]$DisableLogging = $false,

	[Parameter(Mandatory=$false)][String]$RPCUser = 'User',
	[Parameter(Mandatory=$false)][String]$RPCPassword = (New-Guid).Guid.Replace('-','')
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
	[string]$appScriptAuthor = 'Kevin Haffner' #Based on https://mainnet.yalls.org/articles/97d67df1-d721-417d-a6c0-11d793739be9:0965AC5E-56CD-4870-9041-E69616660E6F/e276a8ee-01e3-4442-b6c7-340b6b54ce98
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
		
		## <Perform Pre-Installation tasks here>
		Show-InstallationWelcome -CheckDiskSpace -RequiredDiskSpace 200000
		[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

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
		Show-InstallationProgress "Downloading Bitcoin Core 0.16"
		$BitcoinCoreInstaller = "$env:TEMP\BitcoinCore.exe"
		Invoke-WebRequest -Uri 'https://bitcoin.org/bin/bitcoin-core-0.16.0/bitcoin-0.16.0-win64-setup.exe' -OutFile $BitcoinCoreInstaller

		Show-InstallationProgress "Downloading Eclair 0.2 Beta 2"
		$EclairInstaller = "$env:TEMP\Eclair.exe"
		Invoke-WebRequest -Uri 'https://github.com/ACINQ/eclair/releases/download/v0.2-beta2/Eclair-0.2-beta2.exe' -OutFile $EclairInstaller

		Show-InstallationProgress "Installing Bitcoin Core 0.16"
		Execute-Process -Path $BitcoinCoreInstaller -Parameters '/S'
		$BitcoinConfigFolder = "$env:APPDATA\Bitcoin"
		if(!(Test-Path $BitcoinConfigFolder)) {
			New-Item -Path $BitcoinConfigFolder -ItemType Directory -Force
		}
		Out-File $BitcoinConfigFolder\Bitcoin.conf -InputObject ((Get-Content $PSScriptRoot\Files\Bitcoin.conf) -replace "rpcuser,$RPCUser" -replace "RPCPassword,$RPCPassword")

		Show-InstallationProgress "Installing Eclair 0.2 Beta 2"
		Execute-Process -Path $EclairInstaller -Parameters '/VERYSILENT /NORESTART'
		$EclairConfigFolder = "$env:USERPROFILE\.eclair"
		if(!(Test-Path $EclairConfigFolder)) {
			New-Item -Path $EclairConfigFolder -ItemType Directory -Force
		}
		Out-File $EclairConfigFolder\Eclair.conf -InputObject ((Get-Content $PSScriptRoot\Files\Eclair.conf) -replace "rpcuser,$RPCUser" -replace "RPCPassword,$RPCPassword")

		Show-InstallationPrompt -Title 'Bitcoin Core needs to sync' -Message 'Bitcoin Core needs to sync, this might take days... When this is done, you may open Eclair.' -ButtonMiddleText "OK"
		Execute-ProcessAsUser -Path "$env:ProgramFiles\Bitcoin\bitcoin-qt.exe" -RunLevel LeastPrivilege -NoWait

		##*===============================================
		##* POST-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Installation'
		
		## <Perform Post-Installation tasks here>
		$ExtIP = Invoke-RestMethod "api.ipify.org"
		$ConnectionResult = Test-NetConnection -ComputerName $ExtIP -Port 9735
		if(!($ConnectionResult.TcpTestSucceeded)) {
			Show-InstallationPrompt -Message "Port 9735 on this computer is not accessible from the Internet. You'll need to configure this in your router and/or firewall." -ButtonMiddleText 'OK'
		}
		
		## Display a message at the end of the install
		If (-not $useDefaultMsi) { Show-InstallationPrompt -Message 'Done!' -ButtonRightText 'OK' -Icon Information -NoWait }
	}
	ElseIf ($deploymentType -ieq 'Uninstall')
	{
		##*===============================================
		##* PRE-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Uninstallation'
		
		## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing
		
		## Show Progress Message (with the default message)
		
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