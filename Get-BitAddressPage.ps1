Function Get-BitAddressPage {
    [CmdletBinding()]
    Param (
        $Path = ".\bitaddress.org.html"
    )

    Begin {
        $htmlpage = 'https://raw.githubusercontent.com/pointbiz/bitaddress.org/master/bitaddress.org.html'
        $Changelog = 'https://www.bitaddress.org/CHANGELOG.txt.asc'
    }

    Process {
        # Getting the SHA256 hash of the latest version according to changelog
        $ValidHash = (Invoke-WebRequest -Uri $Changelog | select -ExpandProperty Content | Select-String -Pattern '[0-9A-z]{64,}').Matches.Value
        
        # Downloading the latest/current version
        Invoke-WebRequest -Uri $htmlpage -OutFile $Path

        #Getting the hash of the latest/current version
        $htmlhash = Get-FileHash $Path | select -ExpandProperty Hash
    }
    End {
        if($htmlhash -eq $ValidHash) {
            Write-Host "Hash is valid" -ForegroundColor Green
            return (Get-Item $Path).FullName
        }
        else {
            Write-Warning "Hash not valid! Do not trust $Path !!!"
        }
    }
}