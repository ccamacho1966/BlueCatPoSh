function Get-BlueCatIP4Networks {
    [cmdletbinding()]

    param(
        [Parameter(Mandatory,ParameterSetName='byBlock')]
        [PSCustomObject] $Block,

        [Parameter(Mandatory,ParameterSetName='byID')]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $Parent,

        [Parameter()]
        [ValidateRange(0, [int]::MaxValue)]
        [int] $Start = 0,

        [Parameter()]
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
            $Parent = $Block.id
        } else {
            # Retrieve the parent IP4 block since we only got an entity ID to work with...
            $Block = Get-BlueCatEntityById -ID $Parent -BlueCatSession $BlueCatSession
        }

        # Confirm the object we're referencing is the correct entity type
        if ($Block.type -ne 'IP4Block') {
            throw "ID:$($Parent) is not an IP4Block entity!"
        }

        # Retrieve the requested number of IP4 network records
        $Uri = "getEntities?parentId=$($Parent)&type=IP4Network&start=$($Start)&count=$($Count)"
        if ($Options) {
            $Uri += "&options=$($Options)"
        }
        [PSCustomObject[]] $BlueCatReply = Invoke-BlueCatApi -Method Get -Request $Uri -BlueCatSession $BlueCatSession

        if ($BlueCatReply.Count) {
            Write-Verbose "$($thisFN): Found $($BlueCatReply.Count) networks under IP4Block #$($Parent)"
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
