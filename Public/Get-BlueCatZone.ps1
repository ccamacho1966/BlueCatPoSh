function Get-BlueCatZone {
    [cmdletbinding()]
    param(
        [Parameter()]
        [Alias('Connection','Session')]
        [BlueCat]$BlueCatSession = $Script:BlueCatSession,

        [parameter(Mandatory)]
        [string] $Zone
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState }

    process {
        Confirm-Settings -BlueCatSession $BlueCatSession -Config -View

        $zPath = $Zone.Split('\.')
        [array]::Reverse($zPath)

        $zId = $BlueCatSession.idView
        foreach ($bit in $zPath) {
            $Query = "getEntityByName?parentId=$($zId)&type=Zone&name=$($bit)"
            $result = Invoke-BlueCatApi -BlueCatSession $BlueCatSession -Method Get -Request $Query
            if (-not $result.id) {
                throw "$($result) Zone $($Zone) not found!"
            }
            $zId = $result.id
        }
        $zObj = $result | Convert-BlueCatReply -BlueCatSession $BlueCatSession

        Write-Verbose "Get-BlueCatZone: Selected #$($zObj.id) as '$($zObj.name)'"
        $zObj
    }
}
