$n = 0
while($true) {
    $Block = @{
        'PreviusHash'  = '000041635ab87bdb0807ad8a978e38bf84a03a9a7f7961777db0954aba0d1788'
        'Difficulty'   = '0000'
        'Transactions' = 'Kevin pays 1Btc to Magnus, Magnus pays 0,5Btc to Peter, I will get 12.5Btc as reward.'
        'Nonce'        = $n
    }
    $Block | Out-File "$env:TEMP\block.txt" -Force
    $BlockHash = Get-FileHash "$env:TEMP\block.txt" -Algorithm SHA256 | select -ExpandProperty Hash
    $Difficulty = $Block.Difficulty
    if($BlockHash -like "$Difficulty*") {
        return $BlockHash
    }
    else {
        $n++
    }
}