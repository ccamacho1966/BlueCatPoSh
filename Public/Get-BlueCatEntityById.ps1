function Get-BlueCatEntityById {
    [cmdletbinding()]
    param(
        [parameter(Mandatory)]
        [Alias('EntityID')]
        [int] $ID,

        [Parameter()]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState }

    process {
        $thisFN = (Get-PSCallStack)[0].Command

        Write-Verbose "$($thisFN): ID='$($ID)'"

        $Query = "getEntityById?id=$($ID)"
        $BlueCatReply = Invoke-BlueCatApi -Method Get -Request $Query -BlueCatSession $BlueCatSession

        if (-not $BlueCatReply.id) {
            Write-Verbose "$($thisFN): ID #$($ID) not found: $($BlueCatReply)"
            throw "Entity Id $($ID) not found: $($BlueCatReply)"
        }
        Write-Verbose "$($thisFN): Selected $($BlueCatReply.type) #$($BlueCatReply.id) as $($BlueCatReply.name)"

        $BlueCatReply | Convert-BlueCatReply -BlueCatSession $BlueCatSession
    }
}
