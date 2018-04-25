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

		Show-InstallationWelcome -CheckDiskSpace -RequiredDiskSpace 200000
		[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

		##*===============================================
		##* INSTALLATION 
		##*===============================================
		[string]$installPhase = 'Installation'
				
		Show-InstallationProgress "Downloading Bitcoin Core 0.16"
		$BitcoinCoreInstaller = "$env:TEMP\BitcoinCore.exe"
		Invoke-WebRequest -Uri 'https://bitcoin.org/bin/bitcoin-core-0.16.0/bitcoin-0.16.0-win64-setup.exe' -OutFile $BitcoinCoreInstaller

		Show-InstallationProgress "Downloading Eclair 0.2 Beta 2"
		$EclairInstaller = "$env:TEMP\Eclair.exe"
		Invoke-WebRequest -Uri 'https://github.com/ACINQ/eclair/releases/download/v0.2-beta2/Eclair-0.2-beta2.exe' -OutFile $EclairInstaller

		
		Show-InstallationProgress "Installing Bitcoin Core 0.16"
		#Installing silently
		Execute-Process -Path $BitcoinCoreInstaller -Parameters '/S'
		$BitcoinConfigFolder = "$env:APPDATA\Bitcoin"
		if(!(Test-Path $BitcoinConfigFolder)) {
			#Creating the folder if it does not exist
			New-Item -Path $BitcoinConfigFolder -ItemType Directory -Force
		}
		$BitcoinConfig = @("testnet=0","server=1","rpcuser=$RPCUser","rpcpassword=$RPCPassword","txindex=1","zmqpubrawblock=tcp://127.0.0.1:29000","zmqpubrawtx=tcp://127.0.0.1:29000","addresstype=p2sh-segwit")
		foreach ($Line in $BitcoinConfig) {
			#Looping through the config properties and writing to config file, using ::Newline and -NoNewline because powershell weirdness. 
			if($Line -eq $BitcoinConfig[0]) {
				Add-Content -Path $BitcoinConfigFolder\bitcoin.conf -Value $Line -NoNewline
			}
			else {
				Add-Content -Path $BitcoinConfigFolder\bitcoin.conf -Value (([System.Environment]::NewLine)+$Line) -NoNewline
			}
		}
		#Adding firewall rules
		New-NetFirewallRule -DisplayName "Bitcoin Core" -Description "Bitcoin Core" -Enabled True -Profile Any -Direction Inbound -Protocol TCP -Program 'C:\Program Files\Bitcoin\bitcoin-qt.exe'
		New-NetFirewallRule -DisplayName "Bitcoin Core" -Description "Bitcoin Core" -Enabled True -Profile Any -Direction Inbound -Protocol UDP -Program 'C:\Program Files\Bitcoin\bitcoin-qt.exe'

		
		Show-InstallationProgress "Installing Eclair 0.2 Beta 2"
		#Installing silently
		Execute-Process -Path $EclairInstaller -Parameters '/VERYSILENT /NORESTART'
		$EclairConfigFolder = "$env:USERPROFILE\.eclair"
		if(!(Test-Path $EclairConfigFolder)) {
			#Creating the folder if it does not exist
			New-Item -Path $EclairConfigFolder -ItemType Directory -Force
		}
		$EclairConfig = @("eclair.chain=mainnet","eclair.bitcoind.rpcport=8332","eclair.bitcoind.rpcuser=$RPCUser","eclair.bitcoind.rpcpassword=$RPCPassword")
		foreach ($Line in $EclairConfig) {
			#Looping through the config properties and writing to config file, using ::Newline and -NoNewline because powershell weirdness. 
			if($Line -eq $EclairConfig[0]) {
				Add-Content -Path $EclairConfigFolder\eclair.conf -Value $Line -NoNewline
			}
			else {
				Add-Content -Path $EclairConfigFolder\eclair.conf -Value (([System.Environment]::NewLine)+$Line) -NoNewline
			}
		}
		#Adding firewall rules
		New-NetFirewallRule -DisplayName "Eclair" -Description "Eclair" -Enabled True -Profile Any -Direction Inbound -Protocol TCP -Program "$env:LOCALAPPDATA\Eclair\Eclair.exe"
		New-NetFirewallRule -DisplayName "Eclair" -Description "Eclair" -Enabled True -Profile Any -Direction Inbound -Protocol UDP -Program "$env:LOCALAPPDATA\Eclair\Eclair.exe"

		Show-InstallationPrompt -Title 'Bitcoin Core needs to sync' -Message 'Bitcoin Core needs to sync, this might take days... When this is done, you may open Eclair. In the meantime, forward port 9735 in your router to this computer.' -ButtonMiddleText "OK"
		#Starting Bitcoin Core without admin rights, even though this script is run as admin.
		Execute-ProcessAsUser -Path "$env:ProgramFiles\Bitcoin\bitcoin-qt.exe" -RunLevel LeastPrivilege

		##*===============================================
		##* POST-INSTALLATION
		##*===============================================
		[string]$installPhase = 'Post-Installation'
				
		## Display a message at the end of the install
		Show-InstallationPrompt -Message 'Done!' -ButtonRightText 'OK' -Icon Information -NoWait
	}
	ElseIf ($deploymentType -ieq 'Uninstall')
	{
		##*===============================================
		##* PRE-UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Pre-Uninstallation'
		
		
		##*===============================================
		##* UNINSTALLATION
		##*===============================================
		[string]$installPhase = 'Uninstallation'
				
		
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