function Add-BlueCatSRV
{
<#
.SYNOPSIS
    Create a new DNS SRV record.
.DESCRIPTION
    The Add-BlueCatSRV cmdlet will create a new DNS SRV record.

    A Service record (SRV record) is a specification of data in the Domain Name System defining the location, i.e., the hostname and port number, of servers for specified services. It is defined in RFC 2782, and its type code is 33. Some Internet protocols such as the Session Initiation Protocol (SIP) and the Extensible Messaging and Presence Protocol (XMPP) often require SRV support.
.PARAMETER Name
    A string value representing the FQDN of the service being provided.

    By convention the FQDN format is _[service]._[protocol].zone.tld where:
    * [service] is the symbolic name of the offered service.
    * [protocol] is the transport protocol, usually either 'tcp' or 'udp'.
    * 'zone.tld' is the DNS zone where the service is being offered.

    This convention is not enforced by code, but is required by most services.
.PARAMETER Target
    A string value representing the FQDN of the machine providing the service.
    The target must already exist as an internal or external host record.
.PARAMETER Port
    An integer value representing the TCP or UDP port the service is found on.
.PARAMETER Priority
    An integer value representing the relative priority for the target host.
    Higher value records are LESS preferred and will receive traffic only if connections to lower value targets fail first.
.PARAMETER Weight
    An integer value representing the relative weight for records with the same priority.
    Higher value records will receive a higher proportion of traffic for the service.
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
    A switch that causes a PSCustomObject representing the new SRV record to be returned.
.EXAMPLE
    PS> Add-BlueCatSRV -Name '_sip._udp.example.com' -Target 'sipserver.example.com' -Port 5060 -Priority 10 -Weight 50

    Create a new SRV record for the SIP service in the example.com zone.
    Target host is sipserver.example.com on UDP port 5060 with priority of 10 and weight of 50.
    BlueCatSession will default to the current default session.
    View will default to the BlueCatSession default view.
    TTL will default to the zone default time-to-live.
.EXAMPLE
    PS> Add-BlueCatSRV -Name '_ceph-mon._tcp.example.com' -Target 'cephmon.example.com' -Port 6789 -Priority 10 -Weight 20 -TTL 300 -View $ViewObj -BlueCatSession $Session2

    Create a new SRV record for the CEPH-MON service in the example.com zone in the $ViewObj view.
    Target host is cephmon.example.com on TCP port 6789 with priority of 10 and weight of 20.
    TTL for this record will be set to 300 seconds (5 minutes).
    Use the BlueCatSession associated with $Session2 to create this record.
.INPUTS
    None
.OUTPUTS
    None, by default.

    If the '-PassThru' switch is used, a PSCustomObject representing the new SRV record will be returned.
.LINK
    https://www.rfc-editor.org/rfc/rfc2782
    https://en.wikipedia.org/wiki/SRV_record
#>
    [CmdletBinding(DefaultParameterSetName='ViewID')]

    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Alias('FQDN')]
        [string] $Name,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Alias('Value')]
        [string] $Target,

        [Parameter(Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $Port,

        [Parameter(Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $Priority,

        [Parameter(Mandatory)]
        [ValidateRange(1, [int]::MaxValue)]
        [int] $Weight,

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

        $LookupTarget      = $LookupView
        $TargetFQDN        = $Target | Test-ValidFQDN
        $LookupTarget.Name = $TargetFQDN

        try {
            # Attempt an external host lookup first
            $TargetEntry = Get-BlueCatExternalHost @LookupTarget
        } catch {
            # record not found - continue processing
        }

        if (-not $TargetEntry) {
            # No external host so attempt an internal host lookup
            try {
                $TargetEntry = Get-BlueCatHost @LookupTarget
            } catch {
                # record not found - continue processing
            }
        }

        if (-not $TargetEntry) {
            # If we've reached here, there is nothing to link the record to
            throw "$($thisFN): No record found for linked host '$($LinkedFQDN)'"
        }

        Write-Verbose "$($thisFN): Using $($TargetEntry.type) ID:$($TargetEntry.id) for linked host '$($TargetEntry.name)'"
        $propString = "ttl=$($TTL)|absoluteName=$($FQDN)|linkedRecordName=$($TargetEntry.name)|port=$($Port)|priority=$($Priority)|weight=$($Weight)|"

        $Body = @{
            type       = 'SRVRecord'
            name       = $ShortName
            properties = $propString
        }
        $CreateSRVRecord = @{
            Method         = 'Post'
            Request        = "addEntity?parentId=$($Zone.id)"
            Body           = ($Body | ConvertTo-Json)
            BlueCatSession = $BlueCatSession
        }

        $BlueCatReply = Invoke-BlueCatApi @CreateSRVRecord

        if ($BlueCatReply) {
            Write-Verbose "$($thisFN): Created ID:$($BlueCatReply) for '$($FQDN)' (points to $($targetName):$($Port) priority:$($Priority) weight:$($Weight))"

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
