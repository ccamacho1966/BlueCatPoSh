Function Get-BlueCatTXT {
<#
.SYNOPSIS
    Retrieve a set of TXT records
.DESCRIPTION
    The Get-BlueCatTXT cmdlet allows the retrieval of a set of DNS TXT records.
.PARAMETER Name
    A string value representing the FQDN of the TXT records to be retrieved.
.PARAMETER ViewID
    An integer value representing the entity ID of the desired view.
.PARAMETER View
    A PSCustomObject representing the desired view.
.PARAMETER BlueCatSession
    A BlueCat object representing the session to be used for this object lookup.
.EXAMPLE
    PS> Get-BlueCatTXT -Name server1.example.com

    Returns a PSCustomObject representing one or more TXT records, or NULL if none are found.
    BlueCatSession will default to the current default session.
    View will default to the BlueCatSession default view.
.EXAMPLE
    PS> Get-BlueCatTXT -Name server9.example.com -ViewID 23456 -BlueCatSession $Session3

    Returns a PSCustomObject representing the set of TXT records, or NULL if none are found.
    Use the BlueCatSession associated with $Session3 to perform this lookup.
    The record will be searched for in view 23456.
.INPUTS
    None
.OUTPUTS
    PSCustomObject array representing the requested set of TXT records, or NULL if none are found.

    [int] id
    [string] name
    [string] shortName
    [string] type = 'TXTRecord'
    [string] relay
    [int] priority
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
        [int] $ViewID,

        [Parameter(ParameterSetName='ViewObj',Mandatory)]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject] $View,

        [Parameter(ValueFromPipeline)]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession
    )

    begin {
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        if (-not $BlueCatSession) { throw 'No active BlueCatSession found' }
    }

    process {
        $thisFN = (Get-PSCallStack)[0].Command

        # Trim any trailing dots from the name for consistency/display purposes
        $FQDN = $Name | Test-ValidFQDN

        $ZoneLookup = @{
            Name           = $FQDN
            BlueCatSession = $BlueCatSession
        }

        if ($ViewID) {
            # Entity ID for a View has been passed in
            $ZoneLookup.ViewID = $ViewID
        } else {
            if ($View) {
                # A view object has been passed in so test its validity
                if ((-not $View.ID) -or ($View.type -ne 'View')) {
                    # This is not a valid view object!
                    throw "Invalid View object passed to function!"
                }

                # Use the View object for the Zone lookup
                $ZoneLookup.View = $View
            } else {
                # Attempt to use the default view
                $BlueCatSession | Confirm-Settings -View
                Write-Verbose "$($thisFN): Using default view '$($BlueCatSession.View.name)' (ID:$($BlueCatSession.View.id))"
                $ZoneLookup.View = $BlueCatSession.View
            }
        }

        # Standardize lookups and retrieved information
        $Zone = Resolve-BlueCatZone @ZoneLookup

        if ($FQDN -eq $Zone.name) {
            $ShortName = ''
        } else {
            $ShortName = $FQDN -replace "\.$($Zone.name)$", ''
        }

        # Use the resolved zone info to build a new query and retrieve the TXT record(s)
        $Query = "getEntitiesByName?parentId=$($Zone.id)&type=TXTRecord&start=0&count=100&name=$($ShortName)"
        $BlueCatReply = Invoke-BlueCatApi -Method Get -Request $Query -BlueCatSession $BlueCatSession

        if ($BlueCatReply.Count) {
            [PSCustomObject[]] $TXTList = @()

            # Loop through the results and build an array of objects
            foreach ($entry in $BlueCatReply) {
                $TXTRecord = $entry | Convert-BlueCatReply -BlueCatSession $BlueCatSession
                $TXTList  += $TXTRecord
                Write-Verbose "$($thisFN): Selected TXT #$($TXTrecord.id) for $($FQDN) ($($TXTrecord.relay) Priority $($TXTentry.priority)) for $($TXTentry.name)"
            }

            # Return the TXT array to caller
            $TXTList
        }
    }
}
