function Get-BlueCatIP4Blocks {
<#
.SYNOPSIS
    Retrieve IP4 Blocks
.DESCRIPTION
    The Get-BlueCatIP4Blocks cmdlet allows the retrieval of specific or multiple IP4 blocks.

    If a CIDR or Start/End IP range is provided, the specific block will be searched for and returned. Otherwise the cmdlet will return an array of IP4 blocks under the parent.
.PARAMETER Parent
    A PSCustomObject that represents the IP4 Block or Configuration to be searched.
.PARAMETER ParentID
    An integer value that represents the entity ID of the IP4 Block or Configuration to be searched.
.PARAMETER CIDR
    A string value that represents the IP4 Block in CIDR notation, such as '10.10.10.0/24'.
.PARAMETER StartIP
    A string value that represents the first IP4 Address in a Ranged IP4 Block.
.PARAMETER EndIP
    A string value that represents the last IP4 Address in a Ranged IP4 Block.
.PARAMETER Start
    An integer value defining the index to start returning results from. The default start value is 0.
.PARAMETER Count
    An integer value defining how many results to return for each query. The default count value is 10.
.PARAMETER BlueCatSession
    A BlueCat object representing the session to be used for this object lookup.
.EXAMPLE
    PS> Get-BlueCatIP4Blocks

    Returns one or more PSCustomObjects representing IP4 Blocks.
    A null value is returned if the search finds no IP4 Blocks.
    ParentID will default to the current default configuration.
    BlueCatSession will default to the current default session.
    Start will default to 0. Count will default to 10.
.EXAMPLE
    PS> Get-BlueCatIP4Blocks -ParentID 1732 -Start 25 -Count 25

    Returns one or more PSCustomObjects representing IP4 Blocks under the supplied entity ID, which should be a IP4 Block or Configuration.
    A null value is returned if the search finds no IP4 Blocks (or there are less than 25 IP4 Blocks in total).
    BlueCatSession will default to the current default session.
    Since Start is set to 25, the first 25 IP4 Blocks (index 0-24) will be skipped.
    Since Count is set to 25, objects 25-49 will be returned.
.EXAMPLE
    PS> Get-BlueCatIP4Blocks -ParentID 1218 -CIDR '10.0.0.0/8'

    Returns a PSCustomObject representing the IP4 Block '10.0.0.0/8' under the supplied entity ID, which should be a IP4 Block or Configuration.
    A null value is returned if the search finds no matching IP4 Block.
    BlueCatSession will default to the current default session.
.EXAMPLE
    PS> Get-BlueCatIP4Blocks -Parent $MyIP4Block -StartIP '10.10.8.0' -EndIP '10.10.10.255'

    Returns a PSCustomObject representing the IP4 Block '10.10.8.0-10.10.10.255' under $MyIP4Block, which should be a IP4 Block (or Configuration).
    A null value is returned if the search finds no matching IP4 Block.
    BlueCatSession will default to the current default session.
.INPUTS
    None
.OUTPUTS
    One or more PSCustomObjects representing IP4 Blocks.
#>
    [CmdletBinding(DefaultParameterSetName='ListID')]

    param(
        [Parameter(ParameterSetName='CIDRID')]
        [Parameter(ParameterSetName='ListID')]
        [Parameter(ParameterSetName='RangeID')]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $ParentID,

        [Parameter(Mandatory,ParameterSetName='CIDRObj')]
        [Parameter(Mandatory,ParameterSetName='ListObj')]
        [Parameter(Mandatory,ParameterSetName='RangeObj')]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject] $Parent,

        [Parameter(Mandatory,ParameterSetName='CIDRID')]
        [Parameter(Mandatory,ParameterSetName='CIDRObj')]
        [string] $CIDR,

        [Parameter(Mandatory,ParameterSetName='RangeID')]
        [Parameter(Mandatory,ParameterSetName='RangeObj')]
        [string] $StartIP,

        [Parameter(Mandatory,ParameterSetName='RangeID')]
        [Parameter(Mandatory,ParameterSetName='RangeObj')]
        [string] $EndIP,

        [Parameter(ParameterSetName='ListID')]
        [Parameter(ParameterSetName='ListObj')]
        [ValidateRange(0, [int]::MaxValue)]
        [int] $Start = 0,

        [Parameter(ParameterSetName='ListID')]
        [Parameter(ParameterSetName='ListObj')]
        [ValidateRange(1, 100)]
        [int] $Count = 10,

        [Parameter()]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession
    )

    begin {
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        if (-not $BlueCatSession) { throw 'No active BlueCatSession found' }
    }

    process {
        $thisFN = (Get-PSCallStack)[0].Command

        if ($Parent) {
            $ParentID = $Parent.id
        }

        if (-not $ParentID) {
            # No parent ID has been passed in so attempt to use the default configuration
            $BlueCatSession | Confirm-Settings -Config
            Write-Verbose "$($thisFN): Using default configuration '$($BlueCatSession.Config.name)' (ID:$($BlueCatSession.Config.id))"
            $ParentID = $BlueCatSession.Config.id
        }

        if (-not $Parent) {
            $Parent = Get-BlueCatEntityById -ID $ParentID -BlueCatSession $BlueCatSession
        }

        if ($Count) {
            # This is a list request. Build and pass to Get-BlueCatEntities
            return (Get-BlueCatEntities -Parent $ParentID -EntityType 'IP4Block' -Start $Start -Count $Count -BlueCatSession $BlueCatSession)
        }

        # Build lookup URI based on type of lookup (CIDR vs Range)
        if ($CIDR) {
            $Query="getEntityByCIDR?parentId=$($ParentID)&cidr=$($CIDR)&type=IP4Block"
            Write-Verbose "$($thisFN): CIDR $($CIDR) from entity #$($ParentID)"
        } else {
            $Query="getEntityByRange?parentId=$($ParentID)&address1=$($StartIP)&address2=$($EndIP)&type=IP4Block"
            Write-Verbose "$($thisFN): Range $($StartIP)-$($EndIP) from entity #$($ParentID)"
        }

        # Attempt to retrieve the IP4 Block
        $BlueCatReply = Invoke-BlueCatApi -Method Get -Request $Query -BlueCatSession $BlueCatSession
        if (-not $BlueCatReply.id) {
            # IP4 Block search didn't return a result
            throw "$($thisFN): Failed to find IP4 block"
        }

        # Build a standard object and attach the parent object information
        $ip4block   = $BlueCatReply | Convert-BlueCatReply -BlueCatSession $BlueCatSession
        $ip4block   | Add-Member -MemberType NoteProperty -Name 'parent' -Value $Parent

        # Return the IP4 Block object
        $ip4block
    }
}
