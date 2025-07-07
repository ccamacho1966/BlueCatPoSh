function Get-BlueCatIP4Addresses {    # no corresponding API call
    [cmdletbinding()]
    param(
        [Parameter(Mandatory,ParameterSetName='byNetwork')]
        [PSCustomObject] $Network,

        [Parameter(Mandatory,ParameterSetName='byID')]
        [int] $Parent,

        [int] $Start = 0,

        [int] $Count = 10,

        [string] $Options,

        [Parameter()]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession
    )

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState }

    process {
        $thisFN = (Get-PSCallStack)[0].Command

        # Select the entity ID for the parent IP4 network
        if ($Network) { $Parent = $Network.id }

        # Retrieve the parent IP4 network and confirm it is the correct entity type
        $parentInfo = Get-BlueCatEntityById -ID $Parent -BlueCatSession $BlueCatSession
        if ($parentInfo.type -ne 'IP4Network') {
            throw "ID:$($Parent) is not an IP4Network entity!"
        }

        # Retrieve the requested number of IP4 address records
        $Uri = "getEntities?parentId=$($Parent)&type=IP4Address&start=$($Start)&count=$($Count)"
        if ($Options) { $Uri += "&options=$($Options)" }
        $BlueCatReply = Invoke-BlueCatApi -BlueCatSession $BlueCatSession -Method Get -Request $Uri

        if ($BlueCatReply.Count) {
            Write-Verbose "$($thisFN): Retrieved $($BlueCatReply.Count) addresses under IP4Network #$($Parent)"
            foreach ($bit in $BlueCatReply) {
                $ip4addr = $bit | Convert-BlueCatReply -BlueCatSession $BlueCatSession
                $ip4addr | Add-Member -MemberType NoteProperty -Name 'parent' -Value $parentInfo

                Write-Verbose "$($thisFN): ID #$($ip4addr.id): $($ip4addr.property.address) is '$($ip4addr.name)'"
                $ip4addr
            }
        }
    }
}
