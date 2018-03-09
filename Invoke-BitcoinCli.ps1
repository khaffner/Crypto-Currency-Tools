<#
.Synopsis
   A wrapper for bitcoin-cli.exe
.DESCRIPTION
   A somewhat proper wrapper around bitcoin-cli.exe, that returns the results as psobject.
.EXAMPLE
   Invoke-BitcoinCli -RpcUser foo -RpcPassword bar -Command getblockchaininfo
#>
function Invoke-BitcoinCli {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory=$false)][string]$BitcoinPath = 'C:\Program Files\Bitcoin\daemon\bitcoin-cli.exe',
        [Parameter(Mandatory=$true)] [string]$RpcUser,
        [Parameter(Mandatory=$true)] [string]$RpcPassword,
        [Parameter(Mandatory=$true)] [string]$Command
    )

    Begin {
        $Command = $Command.TrimStart('-')
    }

    Process {
        & $BitcoinPath "-RpcUser=$RpcUser" "-RpcPassword=$RpcPassword" "$Command" | ConvertFrom-Json
    }

    End {
    }
}