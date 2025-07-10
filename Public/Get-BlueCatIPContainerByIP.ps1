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
