function Get-BlueCatSOA {
 <#
.SYNOPSIS
    Retrieve a Start of Authority definition
.DESCRIPTION
    The Get-BlueCatSOA cmdlet allows the retrieval of Start of Authority definitions.
.PARAMETER Name
    A string value representing the FQDN of the Zone definition to be retrieved.
.PARAMETER ViewID
    An integer value representing the entity ID of the desired view.
.PARAMETER View
    A PSCustomObject representing the desired view.
.PARAMETER BlueCatSession
    A BlueCat object representing the session to be used for this object lookup.
.EXAMPLE
    PS> Get-BlueCatSOA -Name 'example.com'

    Returns a PSCustomObject representing the Start of Authority for 'example.com'.
    BlueCatSession will default to the current default session.
    View will default to the BlueCatSession default view.
.EXAMPLE
    PS> Get-BlueCatSOA -Name 'anotherzone.com' -ViewID 23456 -BlueCatSession $Session3

    Returns a PSCustomObject representing the Start of Authority for 'anotherzone.com'.
    Use the BlueCatSession associated with $Session3 to perform this lookup.
    The record will be searched for in view 23456.
.INPUTS
    None
.OUTPUTS
    PSCustomObject representing the requested Start of Authority.

    [int] id
    [string] name
    [string] type = 'StartOfAuthority'
    [string] properties
    [PSCustomObject] property
    [PSCustomObject] config
    [PSCustomObject] view
#>
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

        if ($SoaRecord) {
            # Standardize the object
            $SoaRecord.name = $Zone.name
            $SoaRecord.type = 'StartOfAuthority'

            # Convert the tweaked reply and return result
            $SoaRecord | Convert-BlueCatReply -BlueCatSession $BlueCatSession
        } else {
            # There is no SOA record...
            Write-Warning "$($thisFN): No SOA record found for $($Zone.name)"
        }
    }
}
