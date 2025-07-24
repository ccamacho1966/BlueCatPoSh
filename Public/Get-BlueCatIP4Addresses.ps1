function Get-BlueCatIP4Addresses {    # no corresponding API call
    [CmdletBinding()]

    param(
        [Parameter(Mandatory,ParameterSetName='byObj')]
        [PSCustomObject] $Network,

        [Parameter(Mandatory,ParameterSetName='byID')]
        [ValidateRange(1, [int]::MaxValue)]
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
