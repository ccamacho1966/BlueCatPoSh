function Get-BlueCatZone {
    [CmdletBinding(DefaultParameterSetName='ViewID')]

    param(
        [parameter(Mandatory)]
        [Alias('Zone')]
        [string] $Name,

        [Parameter(ParameterSetName='ViewID')]
        [ValidateRange(1, [int]::MaxValue)]
        [int]$ViewID,

        [Parameter(ParameterSetName='ViewObj',Mandatory)]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject] $View,

        [Parameter()]
        [Alias('Connection','Session')]
        [BlueCat]$BlueCatSession = $Script:BlueCatSession
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState }

    process {
        $thisFN = (Get-PSCallStack)[0].Command

        $Zone = $Name | Test-ValidFQDN

        if ($View)   {
            $ViewID = $View.ID
        }
        if (-not $ViewID) {
            $BlueCatSession | Confirm-Settings -View
            $ViewID = $BlueCatSession.idView
        }

        $zPath = $Zone.Split('\.')
        [array]::Reverse($zPath)

        $zId = $ViewID
        foreach ($bit in $zPath) {
            $Query = "getEntityByName?parentId=$($zId)&type=Zone&name=$($bit)"
            $BlueCatReply = Invoke-BlueCatApi -Method Get -Request $Query -BlueCatSession $BlueCatSession
            if (-not $BlueCatReply.id) {
                throw "Zone $($Zone) not found!"
            }
            $zId = $BlueCatReply.id
        }
        $zObj = $BlueCatReply | Convert-BlueCatReply -BlueCatSession $BlueCatSession

        Write-Verbose "$($thisFN): Selected #$($zObj.id) as '$($zObj.name)'"
        $zObj
    }
}
