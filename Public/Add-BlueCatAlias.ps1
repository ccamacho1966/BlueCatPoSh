function Add-BlueCatAlias
{
<#
.SYNOPSIS
    Create a new DNS Alias (CNAME) record.
.DESCRIPTION
    The Add-BlueCatAlias cmdlet will create a new DNS CNAME record.

    A Canonical Name (CNAME) record is a type of resource record in the Domain Name System (DNS) that maps one domain name (an alias) to another (the canonical name).
    
    CNAME records must always point to another domain name, never directly to an IP address.

    If a CNAME record is present at a node, no other data should be present; this ensures that the data for a canonical name and its aliases cannot be different.
.PARAMETER Name
    A string value representing the FQDN of the CNAME (Alias) to be created.
.PARAMETER LinkedHost
    A string value representing the FQDN of the actual host the CNAME points to.
    The target must already exist as an internal or external host record.
.PARAMETER TTL
    An integer value representing time-to-live for the new CNAME record.
    A value of -1 will set the new record to use the zone default TTL.

    If not specified, BlueCatPoSh will default this value to -1 (use zone default).
.PARAMETER Zone
    An optional zone object to be searched. Providing a zone object reduces API calls making the lookup faster.
.PARAMETER ViewID
    An integer value representing the entity ID of the desired view.
.PARAMETER View
    A PSCustomObject representing the desired view.
.PARAMETER BlueCatSession
    A BlueCat object representing the session to be used for this object creation.
.PARAMETER PassThru
    A switch that causes a PSCustomObject representing the new CNAME record to be returned.
.EXAMPLE
    PS> Add-BlueCatAlias -Name myalias.example.com -LinkedHost realserver.example.com

    Create a new CNAME record for the alias 'myalias' in the example.com zone.
    Linked host (canonical name) is realserver.example.com.
    BlueCatSession will default to the current default session.
    View will default to the BlueCatSession default view.
    TTL will default to the zone default time-to-live.
.EXAMPLE
    PS> Add-BlueCatAlias -Name myservice.example.com -LinkedHost somehost.someplace.com -TTL 300 -ViewID 23456 -BlueCatSession $Session6 -PassThru

    Create a new CNAME record for the alias 'myservice' in the example.com zone in view 23456.
    Linked host (canonical name) is somehost.someplace.com.
    TTL for this record will be set to 300 seconds (5 minutes).
    Use the BlueCatSession associated with $Session6 to create this record.

    A PSCustomObject representing the new CNAME record will be returned (PassThru).
.INPUTS
    None
.OUTPUTS
    None, by default.

    If the '-PassThru' switch is used, a PSCustomObject representing the new CNAME record will be returned.
.LINK
    https://www.rfc-editor.org/rfc/rfc1034
    https://www.rfc-editor.org/rfc/rfc2181
    https://en.wikipedia.org/wiki/CNAME_record
#>
    [CmdletBinding(DefaultParameterSetName='ViewID')]

    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Alias('FQDN')]
        [string] $Name,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Alias('Target','Value')]
        [string] $LinkedHost,

        [Parameter()]
        [int] $TTL = -1,

        [Parameter(ParameterSetName='ZoneObj',Mandatory)]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject] $Zone,

        [Parameter(ParameterSetName='ViewID')]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $ViewID,

        [Parameter(ParameterSetName='ViewObj',Mandatory)]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject] $View,

        [Parameter()]
        [Alias('Connection','Session')]
        [BlueCat] $BlueCatSession = $Script:BlueCatSession,

        [switch] $PassThru
    )

    begin {
        Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState
        if (-not $BlueCatSession) { throw 'No active BlueCatSession found' }
    }

    process {
        $thisFN = (Get-PSCallStack)[0].Command

        if ($Zone) {
            $View = $Zone.view
        } elseif ($ViewID) {
            $View = Get-BlueCatView -ViewID $ViewID -BlueCatSession $BlueCatSession
        } elseif (-not $View) {
            # No View or ViewID has been passed in so attempt to use the default view
            $BlueCatSession | Confirm-Settings -View
            Write-Verbose "$($thisFN): Using default view '$($BlueCatSession.View.name)' (ID:$($BlueCatSession.View.id))"
            $View = $BlueCatSession.View
        }

        if (-not $View) {
            throw "$($thisFN): View could not be resolved"
        }

        if (-not $View.ID) {
            # This is not a valid object!
            throw "$($thisFN): Invalid View object passed to function!"
        }

        if ($View.type -ne 'View') {
            throw "$($thisFN): Object is not a View (ID:$($View.ID) $($View.name) is a $($View.type))"
        }

        # Trim any trailing dots from the name for consistency/display purposes
        $FQDN = $Name | Test-ValidFQDN

        # Resolve zone if not provided
        if (-not $Zone) {
            $Zone = Resolve-BlueCatZone -Name $FQDN -View $View -BlueCatSession $BlueCatSession
            if (-not $Zone) {
                # Zone could not be resolved
                throw "$($thisFN): Zone could not be resolved for $($FQDN)"
            }
        }

        # Resolve short name for lookup
        if ($FQDN -eq $Zone.name) {
            $ShortName = ''
        } else {
            $ShortName = $FQDN -replace "\.$($Zone.name)$", ''
        }

        $LookupBase = @{
            Name           = $FQDN
            BlueCatSession = $BlueCatSession
            ErrorAction    = 'SilentlyContinue'
        }
        $LookupZone = $LookupBase + @{ Zone = $Zone; SkipExternalHostCheck = $true }
        $LookupView = $LookupBase + @{ View = $View }

        if (Get-BlueCatAlias @LookupZone) {
            # There is already an existing alias
            throw "$($thisFN): Existing alias record found - aborting Alias creation!"
        } elseif (Get-BlueCatHost @LookupZone) {
            # There is already a host entry for this Alias/CName!!
            throw "$($thisFN): Existing host record found - aborting Alias creation!"
        }

        $ExistingExternal = Get-BlueCatExternalHost @LookupView
        if ($ExistingExternal) {
            Write-Warning "$($thisFN): An external host entry exists for '$($ExistingExternal.name)' (ID:$($ExistingExternal.id))"
        }

        $LookupLinked      = $LookupView
        $LinkedFQDN        = $LinkedHost | Test-ValidFQDN
        $LookupLinked.Name = $LinkedFQDN

        $LinkedInfo        = Resolve-BlueCatFQDN @LookupLinked
        $propString = "ttl=$($TTL)|absoluteName=$($FQDN)|linkedRecordName=$($LinkedInfo.name)|"
        if ($LinkedInfo.host) {
            $LinkedFQDN = $LinkedInfo.host.name
            Write-Verbose "$($thisFN): Found host record for linked host '$($LinkedFQDN)' (ID:$($LinkedInfo.host.id))"
            if ($LinkedInfo.external) {
                Write-Warning "$($thisFN): Both internal and external host entries found for $($LinkedFQDN)"
            }
            $propString += "linkedParentZoneName=$($LinkedInfo.zone.name)|"
        } elseif ($LinkedInfo.external) {
            $LinkedFQDN = $LinkedInfo.external.name
            Write-Verbose "$($thisFN): Found EXTERNAL host record for linked host '$($LinkedFQDN)' (ID:$($LinkedInfo.external.id))"
        } else {
            throw "Aborting CNAME record creation: No host record found for linked host $($LinkedFQDN)"
        }

        $Body = @{
            type       = 'AliasRecord'
            name       = $ShortName
            properties = $propString
        }
        $CreateAliasRecord = @{
            Method         = 'Post'
            Request        = "addEntity?parentId=$($Zone.id)"
            Body           = ($Body | ConvertTo-Json)
            BlueCatSession = $BlueCatSession
        }

        $BlueCatReply = Invoke-BlueCatApi @CreateAliasRecord

        if ($BlueCatReply) {
            Write-Verbose "$($thisFN): Created ID:$($BlueCatReply) as '$($FQDN)' (points to '$($LinkedFQDN)')"

            if ($PassThru) {
                Get-BlueCatAlias @LookupZone
            }
        } else {
            $Failure = "$($thisFN): CNAME record creation failed for $($FQDN)"
            throw $Failure
            Write-Verbose $Failure
        }
    }
}
