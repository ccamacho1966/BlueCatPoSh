function Get-BlueCatIPContainerByIP {
    [CmdletBinding()]

    Param(
        [Parameter(Mandatory)]
        [Alias('ContainerID')]
        [int] $Parent,

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

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState } 

    process {
        $thisFN = (Get-PSCallStack)[0].Command

        if ($Type -eq 'Any') {
            # Type=Any gives a name/value to the API expectation of an empty string for any type
            $SearchType = ''
        } else {
            $SearchType = $Type
        }

        # Confirm that the provided parent ID exists and is valid
        $BlockCheck = Get-BlueCatEntityById -ID $Parent -BlueCatSession $BlueCatSession

        # Confirm that the provided parent type is valid for this API call
        [string[]] $ValidParents = @('Configuration','IP4Block','IP4Network','IP6Block','IP6Network','DHCP4Range','DHCP6Range')
        if ($BlockCheck.type -notin $ValidParents) {
            throw "$($thisFN): Invalid parent/container type '$($BlockCheck.type)'"
        }

        Write-Verbose "$($thisFN): Find network/block containing [$($Address)] under parent $($BlockCheck.type) $($BlockCheck.name) (ID:$($BlockCheck.id))"

        $Uri = "getIPRangedByIP?containerId=$($BlockCheck.id)&address=$($Address)&type=$($SearchType)"
        $BlueCatReply = Invoke-BlueCatApi -Method Get -Request $Uri -BlueCatSession $BlueCatSession | Convert-BlueCatReply -BlueCatSession $BlueCatSession

        if ($BlueCatReply.id) {
            if ($BlueCatReply.property.start) {
                $IpSpec = "$($BlueCatReply.property.start) - $($BlueCatReply.property.end)"
            } else {
                $IpSpec = $BlueCatReply.property.CIDR
            }

            if ($BlueCatReply.name) {
                $Label = "'$($BlueCatReply.name)'"
            } else {
                $Label = "ID:$($BlueCatReply.id)"
            }

            Write-Verbose "$($thisFN): Returning $($BlueCatReply.type) $($Label) ($($IpSpec))"
            $BlueCatReply
        } else {
            Write-Verbose "$($thisFN): No IP Container found for $($Address)"
        }
    }
}
