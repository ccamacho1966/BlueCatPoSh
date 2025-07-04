function Get-BlueCatIP4Block {
    [cmdletbinding(DefaultParameterSetName='CIDR')]
    param(
        [parameter()]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession,

        [int] $Parent,

        [parameter(Mandatory,ParameterSetName='CIDR')]
        [string] $CIDR,

        [parameter(Mandatory,ParameterSetName='Range')]
        [string] $Start,

        [parameter(Mandatory,ParameterSetName='Range')]
        [string] $End
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState }

    process {
        Confirm-Settings -Connection $BlueCatSession -Config

        if (-not $Parent) { $Parent = $BlueCatSession.idConfig }

        if ($PSCmdlet.ParameterSetName -eq 'CIDR') {
            $Query="getEntityByCIDR?parentId=$($Parent)&cidr=$($CIDR)&type=IP4Block"
            Write-Verbose "Get-BlueCatIP4Block: CIDR $($CIDR) from entity #$($Parent)"
        } else {
            $Query="getEntityByRange?parentId=$($Parent)&address1=$($Start)&address2=$($End)&type=IP4Block"
            Write-Verbose "Get-BlueCatIP4Block: Range $($Start)-$($End) from entity #$($Parent)"
        }

        $result = Invoke-BlueCatApi -BlueCatSession $BlueCatSession -Method Get -Request $Query
        if ($result.id -eq 0) { throw "Get-BlueCatIP4Block: Failed to find IP4 block" }

        $result | Convert-BlueCatReply -BlueCatSession $BlueCatSession
    }
}
