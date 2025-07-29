function Get-BlueCatIP4Networks {
<#
.SYNOPSIS
    Retrieve IP4 Networks
.DESCRIPTION
    The Get-BlueCatIP4Networks cmdlet allows the retrieval of specific or multiple IP4 networks.

    If a CIDR is provided, the specific network will be searched for and returned. Otherwise the cmdlet will return an array of IP4 networks under the parent.
.PARAMETER Block
    A PSCustomObject that represents the IP4 Block to be searched.
.PARAMETER BlockID
    An integer value that represents the entity ID of the IP4 Block to be searched.
.PARAMETER CIDR
    A string value that represents the IP4 Network in CIDR notation, such as '10.20.10.0/24'.
.PARAMETER Start
    An integer value defining the index to start returning results from. The default start value is 0.
.PARAMETER Count
    An integer value defining how many results to return for each query. The default count value is 10.
.PARAMETER IPAddresses
    A switch that causes this cmdlet to return an array of all defined IP4 addresses in each IP4 network object returned.
.PARAMETER BlueCatSession
    A BlueCat object representing the session to be used for this object lookup.
.EXAMPLE
    PS> Get-BlueCatIP4Networks -BlockID 1823

    Returns one or more PSCustomObjects representing IP4 Networks under the supplied entity ID, which should be an IP4 Block.
    A null value is returned if the search finds no IP4 Networks.
    BlueCatSession will default to the current default session.
    Start will default to 0. Count will default to 10.
.EXAMPLE
    PS> Get-BlueCatIP4Networks -ParentID 1732 -Start 25 -Count 25

    Returns one or more PSCustomObjects representing IP4 Networks under the supplied entity ID, which should be an IP4 Block.
    A null value is returned if the search finds no IP4 Networks (or there are less than 25 IP4 Networks in total).
    BlueCatSession will default to the current default session.
    Since Start is set to 25, the first 25 IP4 Networks (index 0-24) will be skipped.
    Since Count is set to 25, objects 25-49 will be returned.
.EXAMPLE
    PS> Get-BlueCatIP4Blocks -ParentID 1148 -CIDR '10.20.10.0/24'

    Returns a PSCustomObject representing the IP4 Block '10.20.10.0/24' under the supplied entity ID, which should be an IP4 Block.
    A null value is returned if the search finds no matching IP4 Block.
    BlueCatSession will default to the current default session.
.INPUTS
    None
.OUTPUTS
    One or more PSCustomObjects representing IP4 Networks.
#>
    [CmdletBinding()]

    param(
        [Parameter(Mandatory,ParameterSetName='CIDRObj')]
        [Parameter(Mandatory,ParameterSetName='ListObj')]
        [Alias('Parent')]
        [PSCustomObject] $Block,

        [Parameter(Mandatory,ParameterSetName='CIDRID')]
        [Parameter(Mandatory,ParameterSetName='ListID')]
        [ValidateRange(1, [int]::MaxValue)]
        [Alias('ParentID')]
        [int] $BlockID,

        [Parameter(Mandatory,ParameterSetName='CIDRID')]
        [Parameter(Mandatory,ParameterSetName='CIDRObj')]
        [string] $CIDR,

        [Parameter(ParameterSetName='ListObj')]
        [Parameter(ParameterSetName='ListID')]
        [ValidateRange(0, [int]::MaxValue)]
        [int] $Start = 0,

        [Parameter(ParameterSetName='ListObj')]
        [Parameter(ParameterSetName='ListID')]
        [ValidateRange(1, 1000)]
        [int] $Count = 10,

        [Parameter()]
        [switch] $IpAddresses,

        [Parameter()]
        [string] $Options,

        [Parameter()]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState }

    process {
        $thisFN = (Get-PSCallStack)[0].Command

        # Select the entity ID for the parent IP4 block
        if ($Block) {
            if (-not $Block.id) {
                throw "Invalid network block object!"
            }
            $BlockID = $Block.id
        } else {
            # Retrieve the parent IP4 block since we only got an entity ID to work with...
            $Block = Get-BlueCatEntityById -ID $BlockID -BlueCatSession $BlueCatSession
        }

        # Confirm the object we're referencing is the correct entity type
        if ($Block.type -ne 'IP4Block') {
            throw "ID:$($BlockID) is not an IP4Block entity!"
        }

        if ($CIDR) {
            $Uri = "getEntityByCIDR?parentId=$($BlockID)&cidr=$($CIDR)&type=IP4Network"
        } else {
            # Retrieve the requested number of IP4 network records
            $Uri = "getEntities?parentId=$($BlockID)&type=IP4Network&start=$($Start)&count=$($Count)"
        }
        if ($Options) {
            $Uri += "&options=$($Options)"
        }
        $LookupParms = @{
            Method         = 'Get'
            Request        = $Uri
            BlueCatSession = $BlueCatSession
        }
        $BlueCatReply = [PSCustomObject[]] (Invoke-BlueCatApi @LookupParms | Where-Object -Property id -NE -Value 0)

        if ($BlueCatReply.Count) {
            Write-Verbose "$($thisFN): Found $($BlueCatReply.Count) networks under IP4Block #$($BlockID)"
            foreach ($bit in $BlueCatReply) {
                $ip4net = $bit | Convert-BlueCatReply -BlueCatSession $BlueCatSession
                $ip4net | Add-Member -MemberType NoteProperty -Name 'parent' -Value $Block
                if ($IpAddresses) {
                    # Retrieve all IP addresses in this network and attach to the IP4 network object
                    [PSCustomObject[]]$addressList = @()
                    $i = 0
                    $perLoop = 10
                    do {
                        $addrResult = Get-BlueCatIP4Addresses -Network $ip4net -Start $i -Count $perLoop -BlueCatSession $BlueCatSession
                        if ($addrResult.Count) {
                            $addressList += $addrResult
                        }
                        $i += $perLoop
                    } while ($addrResult.Count -eq $perLoop)
                    if ($addressList.Count) {
                        $ip4net | Add-Member -MemberType NoteProperty -Name 'addresses' -Value $addressList
                    }
                }
                Write-Verbose "$($thisFN): ID #$($ip4net.id) is '$($ip4net.name)' CIDR: $($ip4net.property.CIDR)"

                # Add each IP4 Network object to the stack to return to the caller
                $ip4net
            }
        }
    }
}
