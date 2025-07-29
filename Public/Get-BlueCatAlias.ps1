function Get-BlueCatAlias { # also known as CNAME
<#
.SYNOPSIS
    Retrieve an Alias (CNAME)
.DESCRIPTION
    The Get-BlueCatAlias cmdlet allows the retrieval of DNS CNAME records.

    A Canonical Name (CNAME) record is a type of resource record in the Domain Name System (DNS) that maps one domain name (an alias) to another (the canonical name).
    
    CNAME records must always point to another domain name, never directly to an IP address.

    If a CNAME record is present at a node, no other data should be present; this ensures that the data for a canonical name and its aliases cannot be different.
.PARAMETER Name
    A string value representing the FQDN of the CNAME (Alias) to be retrieved.
.PARAMETER ViewID
    An integer value representing the entity ID of the desired view.
.PARAMETER View
    A PSCustomObject representing the desired view.
.PARAMETER BlueCatSession
    A BlueCat object representing the session to be used for this object lookup.
.EXAMPLE
    PS> Get-BlueCatAlias -Name myalias.example.com

    Returns a PSCustomObject representing the requested alias, or NULL if not found.
    BlueCatSession will default to the current default session.
    View will default to the BlueCatSession default view.
.EXAMPLE
    PS> Get-BlueCatCNAME -Name myservice.example.com -ViewID 23456 -BlueCatSession $Session6

    Returns a PSCustomObject representing the requested alias, or NULL if not found.
    Use the BlueCatSession associated with $Session6 to perform this lookup.
    The record will be searched for in view 23456.
.INPUTS
    None
.OUTPUTS
    PSCustomObject representing the requested alias, or NULL if not found.

    [int] id
    [string] name
    [string] shortName
    [string] type = 'AliasRecord'
    [string] properties
    [PSCustomObject] property
    [PSCustomObject] config
    [PSCustomObject] view
    [PSCustomObject] zone
#>
    [CmdletBinding(DefaultParameterSetName='ViewID')]

    param(
        [Parameter(Mandatory)]
        [Alias('CNAME','Alias')]
        [string] $Name,

        [Parameter(ParameterSetName='ViewID')]
        [int] $ViewID,

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
                throw "Invalid View object passed to function!"
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

        # Validate that an alias object was returned
        $AliasObj = $Resolved.alias
        if (!$AliasObj.id) { throw "No Alias/CName record found for $($FQDN)" }

        # Reduce redundant API calls by using zone information returned by Resolve-BlueCatFQDN
        $AliasObj | Add-Member -MemberType NoteProperty -Name zone -Value $Resolved.zone
        Write-Verbose "$($thisFN): Selected #$($AliasObj.id) as '$($AliasObj.name)' (points to '$($AliasObj.property.linkedRecordName)')"

        # Return the alias object to caller
        $AliasObj
    }
}
