function Get-BlueCatIPContainerByIP {
<#
.SYNOPSIS
    Use an IP address to search for a container
.DESCRIPTION
    The Get-BlueCatIPContainerByIP cmdlet searches the BlueCat database for a specified type of container using a provided IP address.
.PARAMETER Parent
    A PSCustomObject that represents the container to be searched.

    Valid container types for searching are: Configuration, IP4Block, IP4Network, IP6Block, IP6Network, DHCP4Range, DHCP6Range
.PARAMETER ParentID
    An integer value that represents the entity ID of the container to be searched.

    Valid container types for searching are: Configuration, IP4Block, IP4Network, IP6Block, IP6Network, DHCP4Range, DHCP6Range
.PARAMETER Address
    A string value that represents the IP4 address to search with.
.PARAMETER Type
    A string value defining the type of containers to search for.

    Valid container types to search for are: Any, IP4Block, IP4Network, IP6Block, IP6Network, DHCP4Range, DHCP6Range
.PARAMETER BlueCatSession
    A BlueCat object representing the session to be used for this object lookup.
.EXAMPLE
    PS> Get-BlueCatIP4Networks -ParentID 1823 -Address '10.14.2.44'

    Returns a PSCustomObject representing a container under the supplied entity ID.
    A null value is returned if the search finds no match.
    BlueCatSession will default to the current default session.
.EXAMPLE
    PS> Get-BlueCatIP4Networks -Parent $MyContainer -Address '10.20.99.191' -Type IP4Network -BlueCatSession $Session92

    Returns a PSCustomObject representing the IP4 Network under the supplied entity.
    A null value is returned if the search finds no match.
    Use BlueCatSession $Session92 for the search.
.INPUTS
    None
.OUTPUTS
    PSCustomObject representing a container.
#>
    [CmdletBinding(DefaultParameterSetName='byID')]

    Param(
        [Parameter(ParameterSetName='byID')]
        [Alias('ContainerID')]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $ParentID,

        [Parameter(Mandatory,ParameterSetName='byObj')]
        [Alias('Container')]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject] $Parent,

        [Parameter(Mandatory)]
        [Alias('IP','IPAddress')]
        [string] $Address,

        [Parameter()]
        [ValidateSet('Any','IP4Block','IP4Network','IP6Block','IP6Network','DHCP4Range','DHCP6Range')]
        [string] $Type='Any',

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

        if ($Type -eq 'Any') {
            # Type=Any gives a name/value to the API expectation of an empty string for any type
            $SearchType = ''
        } else {
            $SearchType = $Type
        }

        if ($Parent) {
            $ParentID = $Parent.id
        }

        if (-not $ParentID) {
            # No parent ID has been passed in so attempt to use the default configuration
            $BlueCatSession | Confirm-Settings -Config
            Write-Verbose "$($thisFN): Using default configuration '$($BlueCatSession.Config.name)' (ID:$($BlueCatSession.Config.id))"
            $Parent   = $BlueCatSession.Config
            $ParentID = $Parent.id
        }

        if (-not $Parent) {
            $Parent = Get-BlueCatEntityById -ID $ParentID -BlueCatSession $BlueCatSession
        }

        # Confirm that the provided parent type is valid for this API call
        [string[]] $ValidParents = @('Configuration','IP4Block','IP4Network','IP6Block','IP6Network','DHCP4Range','DHCP6Range')
        if ($Parent.type -notin $ValidParents) {
            throw "$($thisFN): Invalid parent/container type '$($Parent.type)'"
        }

        Write-Verbose "$($thisFN): Find network/block containing [$($Address)] under parent $($Parent.type) $($Parent.name) (ID:$($Parent.id))"

        $Uri = "getIPRangedByIP?containerId=$($Parent.id)&address=$($Address)&type=$($SearchType)"
        $BlueCatReply = Invoke-BlueCatApi -Method Get -Request $Uri -BlueCatSession $BlueCatSession

        if ($BlueCatReply.id) {
            $IpContainer = $BlueCatReply | Convert-BlueCatReply -BlueCatSession $BlueCatSession
            if ($IpContainer.property.start) {
                $IpSpec = "$($IpContainer.property.start) - $($IpContainer.property.end)"
            } else {
                $IpSpec = $IpContainer.property.CIDR
            }

            if ($IpContainer.name) {
                $Label = "'$($IpContainer.name)'"
            } else {
                $Label = "ID:$($IpContainer.id)"
            }

            Write-Verbose "$($thisFN): Returning $($IpContainer.type) $($Label) ($($IpSpec))"
            $IpContainer
        } else {
            Write-Verbose "$($thisFN): No IP Container found for $($Address)"
        }
    }
}
