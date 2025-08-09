Function Get-BlueCatSRV {
<#
.SYNOPSIS
    Retrieve a set of SRV records
.DESCRIPTION
    The Get-BlueCatSRV cmdlet allows the retrieval of a set of DNS SRV records.
.PARAMETER Name
    A string value representing the FQDN of the SRV records to be retrieved.
.PARAMETER ViewID
    An integer value representing the entity ID of the desired view.
.PARAMETER View
    A PSCustomObject representing the desired view.
.PARAMETER BlueCatSession
    A BlueCat object representing the session to be used for this object lookup.
.EXAMPLE
    PS> Get-BlueCatSRV -Name server1.example.com

    Returns a PSCustomObject representing one or more SRV records, or NULL if none are found.
    BlueCatSession will default to the current default session.
    View will default to the BlueCatSession default view.
.EXAMPLE
    PS> Get-BlueCatSRV -Name server9.example.com -ViewID 23456 -BlueCatSession $Session3

    Returns a PSCustomObject representing the set of SRV records, or NULL if none are found.
    Use the BlueCatSession associated with $Session3 to perform this lookup.
    The record will be searched for in view 23456.
.INPUTS
    None
.OUTPUTS
    PSCustomObject array representing the requested set of SRV records, or NULL if none are found.

    [int] id
    [string] name
    [string] shortName
    [string] type = 'SRVRecord'
    [string] target
    [int] port
    [int] priority
    [int] weight
    [PSCustomObject] config
    [PSCustomObject] view
    [PSCustomObject] zone
#>
    [CmdletBinding()]

    param(
        [Parameter(Mandatory)]
        [Alias('HostName')]
        [string] $Name,

        [Parameter(ParameterSetName='ViewID')]
        [ValidateRange(1, [int]::MaxValue)]
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

        if ($View) {
            # A view object has been passed in so test its validity
            if (-not $View.ID) {
                # This is not a valid view object!
                throw "Invalid View object passed to $($thisFN)!"
            }
            # Use the view ID from the View object
            $ViewID = $View.ID
        }

        if (-not $ViewID) {
            # No view ID has been passed in so attempt to use the default view
            $BlueCatSession | Confirm-Settings -View
            Write-Verbose "$($thisFN): Using default view '$($BlueCatSession.View.name)' (ID:$($BlueCatSession.View.id))"
            $ViewID = $BlueCatSession.View.id
        }

        # Trim any trailing dots from the name for consistency/display purposes
        $FQDN = $Name | Test-ValidFQDN

        # Standardize lookups and retrieved information
        $Resolved = Resolve-BlueCatFQDN -FQDN $FQDN -ViewID $ViewID -BlueCatSession $BlueCatSession

        # Warn that a possibly conflicting external host record was also found
        if ($Resolved.external) {
            Write-Warning "$($thisFN): Found External Host '$($Resolved.name)' (ID:$($Resolved.external.id))"
        }

        # Use the resolved zone info to build a new query and retrieve the SRV record(s)
        $Query = "getEntitiesByName?parentId=$($Resolved.zone.id)&type=SRVRecord&start=0&count=100&name=$($Resolved.shortName)"
        [PSCustomObject[]] $BlueCatReply = Invoke-BlueCatApi -Method Get -Request $Query -BlueCatSession $BlueCatSession

        if ($BlueCatReply.Count) {
            [PSCustomObject[]] $SRVList = @()

            # Loop through the results and build an object
            foreach ($entry in $BlueCatReply) {
                $SRVRecord = $entry | Convert-BlueCatReply -BlueCatSession $BlueCatSession
                $SRVList  += $SRVrecord
                Write-Verbose "$($thisFN): SRV ID:$($SRVrecord.id) for $($FQDN) links to $($SRVrecord.target):$($SRVrecord.port) (Priority=$($SRVrecord.priority), Weight=$($SRVrecord.weight))"
            }

            # Return the SRV array to caller
            $SRVList
        }
    }
}
