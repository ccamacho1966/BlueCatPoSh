function Get-BlueCatIP4Block {
    [cmdletbinding(DefaultParameterSetName='CIDR')]

    param(
        [int] $Parent,

        [parameter(Mandatory,ParameterSetName='CIDR')]
        [string] $CIDR,

        [parameter(Mandatory,ParameterSetName='Range')]
        [string] $Start,

        [parameter(Mandatory,ParameterSetName='Range')]
        [string] $End,

        [Parameter()]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState }

    process {
        $thisFN = (Get-PSCallStack)[0].Command

        if (-not $Parent) {
            # No parent ID has been passed in so attempt to use the default configuration
            $BlueCatSession | Confirm-Settings -Config
            Write-Verbose "$($thisFN): Using default configuration '$($BlueCatSession.Config)' (ID:$($BlueCatSession.idConfig))"
            $Parent = $BlueCatSession.idConfig
        }

        # Build lookup URI based on type of lookup (CIDR vs Range)
        if ($CIDR) {
            $Query="getEntityByCIDR?parentId=$($Parent)&cidr=$($CIDR)&type=IP4Block"
            Write-Verbose "$($thisFN): CIDR $($CIDR) from entity #$($Parent)"
        } else {
            $Query="getEntityByRange?parentId=$($Parent)&address1=$($Start)&address2=$($End)&type=IP4Block"
            Write-Verbose "$($thisFN): Range $($Start)-$($End) from entity #$($Parent)"
        }

        # Attempt to retrieve the IP4 Block
        $BlueCatReply = Invoke-BlueCatApi -Method Get -Request $Query -BlueCatSession $BlueCatSession
        if (-not $BlueCatReply.id) {
            # IP4 Block search didn't return a result
            throw "$($thisFN): Failed to find IP4 block"
        }

        # Build a standard object and attach the parent object information
        $ip4block   = $BlueCatReply | Convert-BlueCatReply -BlueCatSession $BlueCatSession
        $parentInfo = Get-BlueCatEntityById -ID $Parent -BlueCatSession $BlueCatSession
        $ip4block   | Add-Member -MemberType NoteProperty -Name 'parent' -Value $parentInfo

        # Return the IP4 Block object
        $ip4block
    }
}
