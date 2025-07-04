function Get-BlueCatIP4Networks {
    [cmdletbinding()]
    param(
        [Parameter()]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession,

        [Parameter(Mandatory,ParameterSetName='byBlock')]
        [psobject] $Block,

        [Parameter(Mandatory,ParameterSetName='byID')]
        [int] $Parent,

        [switch] $IpAddresses,

        [int] $Start = 0,

        [int] $Count = 10,

        [string] $Options
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'byID') {
            $containerId=$Parent
        } else {
            $containerId=$Block.id
        }

        $parentInfo = [PSCustomObject]@{
            id   = $containerId
            type = 'IP4Block'
        }

        $Uri = "getEntities?parentId=$($containerId)&type=IP4Network&start=$($Start)&count=$($Count)"
        if ($Options) { $Uri += "&options=$($Options)" }
        $result = Invoke-BlueCatApi -BlueCatSession $BlueCatSession -Method Get -Request $Uri

        if ($result.Count) {
            Write-Verbose "Get-BlueCatIP4Networks: Found $($result.Count) networks under IP4Block #$($containerId)"
            foreach ($bit in $result) {
                $ip4net = $bit | Convert-BlueCatReply -BlueCatSession $BlueCatSession
                $ip4net | Add-Member -MemberType NoteProperty -Name 'parent' -Value $parentInfo
                if ($IpAddresses) {
                    [PSCustomObject[]]$addressList = @()
                    $i = 0
                    $perLoop = 10
                    do {
                        $addrResult = Get-BlueCatIP4Addresses -BlueCatSession $BlueCatSession -Parent ($ip4net.id) -Start $i -Count $perLoop
                        if ($addrResult.Count) {
                            $addressList += $addrResult
                        }
                        $i += $perLoop
                    } while ($addrResult.Count -eq $perLoop)
                    if ($addressList.Count) {
                        $ip4net | Add-Member -MemberType NoteProperty -Name 'addresses' -Value $addressList
                    }
                }
                Write-Verbose "Get-BlueCatIP4Networks: ID #$($ip4net.id) is '$($ip4net.name)' CIDR: $($ip4net.property.CIDR)"
                $ip4net
            }
        }
    }
}
