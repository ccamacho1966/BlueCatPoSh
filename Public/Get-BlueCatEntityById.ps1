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
        Write-Verbose "Get-BlueCatEntityById: ID='$($ID)'"

        $Query = "getEntityById?id=$($ID)"
        $result = Invoke-BlueCatApi -BlueCatSession $BlueCatSession -Method Get -Request $Query

        if (-not $result.id) {
            Write-Verbose "Get-BlueCatEntityById: ID #$($ID) not found: $($result)"
            throw "Entity Id $($ID) not found: $($result)"
        }
        Write-Verbose "Get-BlueCatEntityByID: Selected $($result.type) #$($result.id) as $($result.name)"

        $result | Convert-BlueCatReply -BlueCatSession $BlueCatSession
    }
}
