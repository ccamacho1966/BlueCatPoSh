function Get-BlueCatIP4Addresses {    # no corresponding API call
    [cmdletbinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession,

        [Parameter(Mandatory,ParameterSetName='byNetwork')]
        [psobject] $Network,

        [Parameter(Mandatory,ParameterSetName='byID')]
        [int] $Parent = 0,

        [int] $Start = 0,

        [int] $Count = 10,

        [string] $Options
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'byID') {
            $containerId = $Parent
        } else {
            $containerId = $Network.id
        }

        $parentInfo = [PSCustomObject]@{
            id   = $containerId
            type = 'IP4Network'
        }

        $Uri = "getEntities?parentId=$($containerId)&type=IP4Address&start=$($Start)&count=$($Count)"
        if ($Options) { $Uri += "&options=$($Options)" }
        $result = Invoke-BlueCatApi -BlueCatSession $BlueCatSession -Method Get -Request $Uri

        if ($result.Count) {
            Write-Verbose "Get-BlueCatIP4Addresses: Found $($result.Count) addresses under IP4Network #$($containerId)"
            foreach ($bit in $result) {
                $ip4addr = $bit | Convert-BlueCatReply -BlueCatSession $BlueCatSession
                $ip4addr | Add-Member -MemberType NoteProperty -Name 'parent' -Value $parentInfo

                Write-Verbose "Get-BlueCatIP4Addresses: ID #$($ip4addr.id): $($ip4addr.property.address) is '$($ip4addr.name)'"
                $ip4addr
            }
        }
    }
}
