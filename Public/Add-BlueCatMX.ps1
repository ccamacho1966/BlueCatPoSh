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

        $MXInfo = Resolve-BlueCatFQDN @LookupParms

        # Insert check for duplicate/conflicting specific MX record

        if ($MXInfo.alias) {
            throw "Aborting MX record creation: Alias/CName record for $($FQDN) found!"
        }

        if (-not $MXInfo.zone) {
            # No deployable zone was found for MX record
            throw "No deployable zone was found for $($FQDN)"
        }
        Write-Verbose "$($thisFN): Selected Zone #$($MXInfo.zone.id) as '$($MXInfo.zone.name)'"

        if ($MXInfo.external) {
            Write-Warning "$($thisFN): An external host entry exists for '$($MXInfo.external.name)'"
        }

        $LookupRelay      = $LookupParms
        $NewRelay         = $Relay | Test-ValidFQDN
        $LookupRelay.Name = $NewRelay

        $relayInfo        = Resolve-BlueCatFQDN @LookupRelay
        if ($relayInfo.host) {
            $relayName = $relayInfo.host.name
            Write-Verbose "$($thisFN): Found host record for relay '$($NewRelay)' (ID:$($relayInfo.host.id))"
            if ($relayInfo.external) {
                Write-Warning "$($thisFN): Both internal and external host entries found for $($NewRelay)"
            }
        } elseif ($relayInfo.external) {
            $relayName = $relayInfo.external.name
            Write-Verbose "$($thisFN): Found EXTERNAL host record for relay '$($NewRelay)' (ID:$($relayInfo.external.id))"
        } else {
            throw "Aborting MX record creation: No host record found for relay $($NewRelay)"
        }

        $Body = @{
            type       = 'MXRecord'
            name       = $MXInfo.shortName
            properties = "ttl=$($TTL)|absoluteName=$($MXInfo.name)|linkedRecordName=$($relayName)|priority=$($Priority)|"
        }
        $CreateMXRecord = @{
            Method         = 'Post'
            Request        = "addEntity?parentId=$($MXInfo.zone.id)"
            Body           = ($Body | ConvertTo-Json)
            BlueCatSession = $BlueCatSession
        }

        $BlueCatReply = Invoke-BlueCatApi @CreateMXRecord
        if (-not $BlueCatReply) {
            throw "MX record creation failed for $($FQDN)"
        }

        Write-Verbose "$($thisFN): Created ID:$($BlueCatReply) for '$($MXInfo.name)' (points to $($relayName) priority:$($Priority))"

        if ($PassThru) {
            Get-BlueCatEntityById -ID $BlueCatReply -BlueCatSession $BlueCatSession
        }
    }
}
