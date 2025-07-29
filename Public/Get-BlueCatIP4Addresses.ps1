function Get-BlueCatIP4Addresses {    # no corresponding API call
<#
.SYNOPSIS
    Retrieve IP4 Addresses
.DESCRIPTION
    The Get-BlueCatIP4Addresses cmdlet allows the retrieval of IP4 addresses associated with a specified IP4 network.
.PARAMETER Network
    A PSCustomObject that represents the IP4 network to be searched.
.PARAMETER NetworkID
    An integer value that represents the entity ID of the IP4 network to be searched.
.PARAMETER Start
    An integer value defining the index to start returning results from. The default start value is 0.
.PARAMETER Count
    An integer value defining how many results to return for each query. The default count value is 10.
.PARAMETER BlueCatSession
    A BlueCat object representing the session to be used for this object lookup.
.EXAMPLE
    PS> Get-BlueCatIP4Addresses -Network $MyNetwork

    Returns one or more PSCustomObjects representing IP4 addresses under the $MyNetwork IP4 network object.
    A null value is returned if the search finds no IP4 addresses.
    BlueCatSession will default to the current default session.
    Start will default to 0. Count will default to 10.
.EXAMPLE
    PS> Get-BlueCatEntities -NetworkID 117273 -Start 100 -Count 100 -BlueCatSession $Session7

    Returns one or more PSCustomObjects representing IP4 addresses under the supplied entity ID, which should be a IP4 network.
    A null value is returned if the search finds no IP4 addresses (or there are less than 100 IP4 addresses in total).
    BlueCatSession $Session7 will be used for this search.
    Since Start is set to 100, the first 100 IP4 addresses (index 0-99) will be skipped.
    Since Count is set to 100, objects 100-199 will be returned.
.INPUTS
    None
.OUTPUTS
    One or more PSCustomObjects representing IP4 addresses.
#>
    [CmdletBinding()]

    param(
        [Parameter(Mandatory,ParameterSetName='byObj')]
        [Alias('Parent')]
        [PSCustomObject] $Network,

        [Parameter(Mandatory,ParameterSetName='byID')]
        [ValidateRange(1, [int]::MaxValue)]
        [Alias('ParentID')]
        [int] $NetworkID,

        [Parameter()]
        [ValidateRange(0, [int]::MaxValue)]
        [int] $Start = 0,

        [Parameter()]
        [ValidateRange(1, 1000)]
        [int] $Count = 10,

        [Parameter()]
        [string] $Options,

        [Parameter()]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState }

    process {
        $thisFN = (Get-PSCallStack)[0].Command

        # Select the entity ID for the parent IP4 network
        if ($Network) {
            if (-not $Network.id) {
                throw "Invalid network object!"
            }
            $NetworkID = $Network.id
        } else {
            # Retrieve the parent IP4 network since we only got an entity ID to work with...
            $Network = Get-BlueCatEntityById -ID $NetworkID -BlueCatSession $BlueCatSession
        }

        # Confirm the object we're referencing is the correct entity type
        if ($Network.type -ne 'IP4Network') {
            throw "ID:$($NetworkID) is not an IP4Network entity!"
        }

        # Retrieve the requested number of IP4 address records
        $Uri = "getEntities?parentId=$($NetworkID)&type=IP4Address&start=$($Start)&count=$($Count)"
        if ($Options) {
            $Uri += "&options=$($Options)"
        }
        [PSCustomObject[]] $BlueCatReply = Invoke-BlueCatApi -BlueCatSession $BlueCatSession -Method Get -Request $Uri

        if ($BlueCatReply.Count) {
            Write-Verbose "$($thisFN): Retrieved $($BlueCatReply.Count) addresses under IP4Network #$($NetworkID)"
            foreach ($bit in $BlueCatReply) {
                $ip4addr = $bit | Convert-BlueCatReply -BlueCatSession $BlueCatSession
                $ip4addr | Add-Member -MemberType NoteProperty -Name 'parent' -Value $Network

                Write-Verbose "$($thisFN): ID #$($ip4addr.id): $($ip4addr.property.address) is '$($ip4addr.name)'"
                $ip4addr
            }
        }
    }
}
