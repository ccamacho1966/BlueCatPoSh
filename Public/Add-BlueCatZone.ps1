function Add-BlueCatZone {
    [cmdletbinding()]
    param(
        [Parameter()]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession,

        [parameter(Mandatory)]
        [string] $Zone,

        [bool] $Deployable = $true,

        [psobject] $Properties,

        [switch] $PassThru
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState }

    process {
        Confirm-Settings -BlueCatSession $BlueCatSession -Config -View

        if ($Deployable) {
            $propString='deployable=true|'
        } else {
            $propString='deployable=false|'
        }

        $Uri = "addZone?parentId=$($BlueCatSession.idView)&absoluteName=$($Zone)&properties=$($propString)"
        $zId = Invoke-BlueCatApi -BlueCatSession $BlueCatSession -Method Post -Request $Uri

        Write-Verbose "Add-BlueCatZone: Created #$($zId) as '$($Zone)'"

        if ($PassThru) { Get-BlueCatZone -BlueCatSession $BlueCatSession -Zone $Zone }
    }
}
