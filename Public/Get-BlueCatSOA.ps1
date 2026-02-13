function Get-BlueCatSOA {
    [CmdletBinding(DefaultParameterSetName='ViewID')]

    param(
        [Parameter(Mandatory,ParameterSetName='ViewID')]
        [Parameter(Mandatory,ParameterSetName='ViewObj')]
        [Alias('ZoneName')]
        [string] $Name,

        [Parameter(ParameterSetName='ZoneObj',Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Alias('ZoneObj')]
        [PSCustomObject] $Zone,

        [Parameter(ParameterSetName='ViewID')]
        [int]$ViewID,

        [Parameter(ParameterSetName='ViewObj',Mandatory)]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject] $View,

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

        if ($Name) {
            # Translate zone name into a zone object
            $ZoneLookup = @{
                Name               = $Name
                BlueCatSession     = $BlueCatSession
            }
            if ($View) {
                $ZoneLookup.View   = $View
            }
            if ($ViewID) {
                $ZoneLookup.ViewID = $ViewID
            }
            $Zone = Get-BlueCatZone @ZoneLookup
        }

        if ($Zone.type -ne 'Zone') {
            if ($Name) {
                throw "$($thisFN): Could not find a zone named '$($Name)'"
            } else {
                throw "$($thisFN): Object is not a Zone (ID:$($Zone.ID) $($Zone.name) is a $($Zone.type))"
            }
        }

        # Retrieve the DNS Deployment Options
        $DnsOParms  = @{
            Method         = 'Get'
            Request        = "getDeploymentOptions?entityId=$($Zone.id)&optionTypes=DNSOption&serverId=-1"
            BlueCatSession = $BlueCatSession
        }
        $DnsOptions = Invoke-BlueCatApi @DnsOParms

        # Pull the SOA record from the list of DNS Deployment Options
        $SoaRecord  = $DnsOptions | Where-Object -Property type -EQ -Value 'START_OF_AUTHORITY'

        # Standardize the object
        $SoaRecord.name = $Zone.name
        $SoaRecord.type = 'StartOfAuthority'

        # Convert the tweaked reply and return result
        $SoaRecord | Convert-BlueCatReply -BlueCatSession $BlueCatSession
    }
}
