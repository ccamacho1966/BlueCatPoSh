function Add-BlueCatMX {
<#
.SYNOPSIS
    Create a new DNS Mail Exchanger (MX) record.
.DESCRIPTION
    The Add-BlueCatMX cmdlet will create a new DNS MX record.

    A mail exchanger record (MX record) specifies the mail server responsible for accepting email messages on behalf of a domain name. It is a resource record in the Domain Name System (DNS). It is possible to configure several MX records, typically pointing to an array of mail servers for load balancing and redundancy.

    The priority field identifies which mailserver should be preferred. If multiple servers have the same priority, email would be expected to be split evenly between them.
.PARAMETER Name
    A string value representing the FQDN of the mail service being provided.
.PARAMETER Relay
    A string value representing the FQDN of the machine accepting email on behalf of this mail service.
    The relay must already exist as an internal or external host record.
.PARAMETER Priority
    An integer value representing the relative priority for the relay host.
    Higher value records are LESS preferred and will receive traffic only if connections to lower value relays fail first.
.PARAMETER TTL
    An integer value representing time-to-live for the new SRV record.
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
    A switch that causes a PSCustomObject representing the new MX record to be returned.
.EXAMPLE
    PS> Add-BlueCatMX -Name 'mail.example.com' -Relay 'mailserver2.example.com' -Priority 20

    Create a new MX record for mail.example.com in the example.com zone.
    Relay host is mailserver2.example.com with a priority value of 20.
    BlueCatSession will default to the current default session.
    View will default to the BlueCatSession default view.
    TTL will default to the zone default time-to-live.
.EXAMPLE
    PS> Add-BlueCatMX -Name 'mail.example.com' -Relay 'exchange.example.com' -Priority 10 -TTL 300 -View $ViewObj -BlueCatSession $Session2 -PassThru

    Create a new MX record for mail.example.com in the example.com zone in the $ViewObj view.
    Relay host is exchange.example.com with a priority value of 10.
    TTL for this record will be set to 300 seconds (5 minutes).
    Use the BlueCatSession associated with $Session2 to create this record.
    Return a PSCustomObject representing the new MX record.
.INPUTS
    None
.OUTPUTS
    None, by default.

    If the '-PassThru' switch is used, a PSCustomObject representing the new MX record will be returned.
.LINK
    https://www.rfc-editor.org/rfc/rfc2782
    https://en.wikipedia.org/wiki/MX_record
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
        [string] $Relay,

        [Parameter(Mandatory)]
        [ValidateRange(0, 65535)]
        [int] $Priority,

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
            throw "$($thisFN): Existing alias record found - aborting MX creation!"
        }

        $ExistingExternal = Get-BlueCatExternalHost @LookupView
        if ($ExistingExternal) {
            Write-Warning "$($thisFN): An external host entry exists for '$($ExistingExternal.name)' (ID:$($ExistingExternal.id))"
        }

        # Insert check for duplicate / conflicting entries

        $LookupRelay      = $LookupView
        $RelayFQDN        = $Relay | Test-ValidFQDN
        $LookupRelay.Name = $RelayFQDN

        try {
            # Attempt an external host lookup first
            $RelayEntry = Get-BlueCatExternalHost @LookupRelay
        } catch {
            # record not found - continue processing
        }

        if (-not $RelayEntry) {
            # No external host so attempt an internal host lookup
            try {
                $RelayEntry = Get-BlueCatHost @LookupRelay
            } catch {
                # record not found - continue processing
            }
        }

        if (-not $RelayEntry) {
            # If we've reached here, there is nothing to link the record to
            throw "$($thisFN): No record found for linked host '$($LinkedFQDN)'"
        }

        Write-Verbose "$($thisFN): Using $($RelayEntry.type) ID:$($RelayEntry.id) for linked host '$($RelayEntry.name)'"
        $propString = "ttl=$($TTL)|absoluteName=$($FQDN)|linkedRecordName=$($RelayEntry.name)|priority=$($Priority)|"

        $Body = @{
            type       = 'MXRecord'
            name       = $ShortName
            properties = $propString
        }
        $CreateMXRecord = @{
            Method         = 'Post'
            Request        = "addEntity?parentId=$($Zone.id)"
            Body           = ($Body | ConvertTo-Json)
            BlueCatSession = $BlueCatSession
        }

        $BlueCatReply = Invoke-BlueCatApi @CreateMXRecord

        if ($BlueCatReply) {
            Write-Verbose "$($thisFN): Created ID:$($BlueCatReply) for '$($FQDN)' (points to $($relayName) priority:$($Priority))"

            if ($PassThru) {
                # Must pull record by ID since there can be multiple records
                Get-BlueCatEntityById -ID $BlueCatReply -BlueCatSession $BlueCatSession
            }
        } else {
            $Failure = "$($thisFN): Record creation failed for $($FQDN)"
            throw $Failure
            Write-Verbose $Failure
        }
    }
}
