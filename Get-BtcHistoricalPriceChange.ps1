Function Get-BtcHistoricalPriceChange {
    [CmdletBinding()]
    Param (
        [string[]]$DaysBack = @('7','31','365','730')
    )

    Begin {
        $ReportArray = @()
    }

    Process {
        $CurrentValue        = (Invoke-RestMethod -Uri "https://apiv2.bitcoinaverage.com/indices/global/ticker/short?crypto=BTC&fiat=USD").BTCUSD.last
        $HistoricalValueData = Invoke-RestMethod  -Uri "https://apiv2.bitcoinaverage.com/indices/global/history/BTCUSD?format=json"

        $Report = New-Object -TypeName psobject
        $Report | Add-Member -MemberType NoteProperty -Name "DaysAgo"              -Value 0
        $Report | Add-Member -MemberType NoteProperty -Name "Date"                 -Value (Get-Date -Format yyyy-MM-dd)
        $Report | Add-Member -MemberType NoteProperty -Name "ValueUSD"             -Value ([int]$CurrentValue)
        $Report | Add-Member -MemberType NoteProperty -Name "PercentChangetoToday" -Value 0
        $ReportArray += $Report 

        Foreach ($Day in $DaysBack) {
            $Report = New-Object -TypeName psobject
            $Date = (Get-Date (Get-Date).AddDays(-$Day) -Format yyyy-MM-dd)
            $OldValue = ($HistoricalValueData | Where-Object time -Like $Date*).average
            $PercentChange = (($CurrentValue-$OldValue)/$OldValue)*100

            $Report | Add-Member -MemberType NoteProperty -Name "DaysAgo"              -Value $Day
            $Report | Add-Member -MemberType NoteProperty -Name "Date"                 -Value $Date
            $Report | Add-Member -MemberType NoteProperty -Name "ValueUSD"             -Value ([int]$OldValue)
            $Report | Add-Member -MemberType NoteProperty -Name "PercentChangetoToday" -Value ([int]$PercentChange)
            $ReportArray += $Report
        }
    }

    End {
        return $ReportArray
    }
}
