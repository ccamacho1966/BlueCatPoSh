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

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState } 

    process {
        $thisFN = (Get-PSCallStack)[0].Command

        $FQDN = $Name | Test-ValidFQDN
        $LookupParms = @{
            Name           = $FQDN
            BlueCatSession = $BlueCatSession
        }
        if ($ViewID) {
            $LookupParms.ViewID = $ViewID
        } elseif ($View)   {
            $LookupParms.View   = $View
            $ViewID             = $View.ID
        }

        $SRVInfo = Resolve-BlueCatFQDN @LookupParms

        # Insert check for duplicate/conflicting specific SRV record

        if ($SRVInfo.alias) {
            throw "Aborting SRV record creation: Alias/CName record for $($FQDN) found!"
        }

        if (-not $SRVInfo.zone) {
            # No deployable zone was found for SRV record
            throw "No deployable zone was found for $($FQDN)"
        }
        Write-Verbose "$($thisFN): Selected Zone #$($SRVInfo.zone.id) as '$($SRVInfo.zone.name)'"

        if ($SRVInfo.external) {
            Write-Warning "$($thisFN): An external host entry exists for '$($SRVInfo.external.name)'"
        }

        $LookupTarget      = $LookupParms
        $NewTarget         = $Target | Test-ValidFQDN
        $LookupTarget.Name = $NewTarget

        $targetInfo        = Resolve-BlueCatFQDN @LookupTarget
        if ($targetInfo.host) {
            $targetName = $targetInfo.host.name
            Write-Verbose "$($thisFN): Found host record for target '$($targetName)' (ID:$($targetInfo.host.id))"
            if ($targetName.external) {
                Write-Warning "$($thisFN): Both internal and external host entries found for $($targetName.host)"
            }
        } elseif ($targetInfo.external) {
            $targetName = $targetInfo.external.name
            Write-Verbose "$($thisFN): Found EXTERNAL host record for target '$($targetName)' (ID:$($targetInfo.external.id))"
        } else {
            throw "Aborting SRV record creation: No host record found for target $($NewTarget)"
        }

        $Body = @{
            type       = 'SRVRecord'
            name       = $SRVInfo.shortName
            properties = "ttl=$($TTL)|absoluteName=$($SRVInfo.name)|linkedRecordName=$($NewTarget)|port=$($Port)|priority=$($Priority)|weight=$($Weight)|"
        }
        $CreateSRVRecord = @{
            Method         = 'Post'
            Request        = "addEntity?parentId=$($SRVInfo.zone.id)"
            Body           = ($Body | ConvertTo-Json)
            BlueCatSession = $BlueCatSession
        }

        $BlueCatReply = Invoke-BlueCatApi @CreateSRVRecord
        if (-not $BlueCatReply) {
            throw "SRV record creation failed for $($FQDN)"
        }

        Write-Verbose "$($thisFN): Created ID:$($BlueCatReply) for '$($SRVInfo.name)' (points to $($targetName):$($Port) priority:$($Priority) weight:$($Weight))"

        if ($PassThru) {
            Get-BlueCatEntityById -ID $BlueCatReply -BlueCatSession $BlueCatSession
        }
    }
}
