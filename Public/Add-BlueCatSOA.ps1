function Add-BlueCatSOA {
 <#
.SYNOPSIS
    Create a new Start of Authority definition
.DESCRIPTION
    The Add-BlueCatSOA cmdlet allows the retrieval of Start of Authority definitions.
.PARAMETER Name
    A string value representing the FQDN of the DNS Zone that will get the new Start of Authority record.
.PARAMETER Zone
    A PSCustomObject representing the DNS Zone that will get the new Start of Authority record.
.PARAMETER Email
    Mandatory MailAddress object representing the email address of the published domain administrator.
.PARAMETER OriginServer
    A string value representing the FQDN of the published primary name server.
    Defaults to automatic selection by BlueCat.
.PARAMETER Refresh
    Time in seconds that secondary servers wait before asking for the serial number again.
    Defaults to 1200 seconds (20 minutes).
.PARAMETER Retry
    Time in seconds a secondary waits to retry a failed request.
    Defaults to 180 seconds (3 minutes).
.PARAMETER Expire
    Maximum time in seconds a secondary server can wait before treating its data as invalid.
    Defaults to 1,209,600 seconds (14 days).
.PARAMETER Minimum
    The default time-to-live for caching negative (not found) records.
    Defaults to 3,600 seconds (1 hour).
.PARAMETER ViewID
    An integer value representing the entity ID of the desired view.
.PARAMETER View
    A PSCustomObject representing the desired view.
.PARAMETER BlueCatSession
    A BlueCat object representing the session to be used for this object creation.
.PARAMETER PassThru
    A switch that causes a PSCustomObject representing the new Start of Authority record to be returned.
.EXAMPLE
    PS> Add-BlueCatSOA -Name 'example.com' -email 'domains@example.com' -Refresh 600

    Create a Start of Authority for example.com
    - Administrative email address will be 'domains@example.com'
    - Refresh timer will be 600 seconds (10 minutes)
    - All other fields will be set to defaults
    BlueCatSession will default to the current default session.
    View will default to the BlueCatSession default view.
.EXAMPLE
    PS> $NewSOA = Add-BlueCatSOA -Zone $MyZone -Email 'dnsadmin@anotherzone.com' -PassThru

    Create a Start of Authority for the zone represented by $MyZone
    - Administrative email address will be 'dnsadmin@anotherzone.com'
    - All other fields will be set to defaults
    The new Start of Authority record will be returned and stored as $NewSOA (PassThru)
    BlueCatSession will default to the current default session.
.INPUTS
    None
.OUTPUTS
    None, by default.
    If PassThru is specified, a PSCustomObject representing the new Start of Authority will be returned.

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
        [Parameter(ParameterSetName='ZoneObj',Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Alias('ZoneObj')]
        [PSCustomObject] $Zone,

        [Parameter(Mandatory,ParameterSetName='ViewID')]
        [Parameter(Mandatory,ParameterSetName='ViewObj')]
        [Alias('ZoneName')]
        [string] $Name,

        [Parameter()]
        [Uint32] $ZoneTTL = 0,

        [Parameter()]
        # ObjectProperties.ttl
        [Uint32] $SOATTL  = 0,

        [Parameter(Mandatory)]
        [Alias('RNAME','Admin')]
        [System.Net.Mail.MailAddress] $Email,

        [Parameter()]
        [ValidatePattern('^([a-z0-9]+(-[a-z0-9]+)*\.)+[a-z]{2,}$')]
        [Alias('MNAME','Primary')]
        [string] $OriginServer,

        [Parameter()]
        [Uint32] $Refresh =    1200,

        [Parameter()]
        [Uint32] $Retry   =     180,

        [Parameter()]
        [Uint32] $Expire  = 1209600,

        [Parameter()]
        [ValidateRange(1,10800)]    # Maximum permitted value is 10800 (3 hours)
        [Alias('NegTTL')]
        [Uint32] $Minimum =    3600,

        [Parameter(ParameterSetName='ViewID')]
        [int]$ViewID,

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

        $AddParms = "parentId=$($Zone.id)&email=$($Email)&expire=$($Expire)&minimum=$($Minimum)&refresh=$($Refresh)&retry=$($Retry)"

        # Add object properties, including comments and user-defined fields. The supported properties are:
        # TTL (time-to-live)
        # mname (primary server)
        # serialNumberFormat (serial number format)
        #
        # To override the default TTL value for SOA records, use ObjectProperties.ttl=”<value>”
        $SoaPropertyString = ""
        if ($ZoneTTL) {
            $SoaPropertyString += "TTL=$($ZoneTTL)|"
        }
        if ($OriginServer) {
            $SoaPropertyString += "mname=$($OriginServer)|"
        }
        if ($SOATTL) {
            $SoaPropertyString += "ObjectProperties.ttl=$($SOATTL)|"
        }
        if ($SoaPropertyString) {
            $AddParms += "&properties=$($SoaPropertyString)"
        }

        $CreateSOARecord = @{
            Method         = 'Post'
            Request        = "addStartOfAuthority?$($AddParms)"
            BlueCatSession = $BlueCatSession
        }

        $BlueCatReply = Invoke-BlueCatApi @CreateSOARecord

        if ($BlueCatReply) {
            Write-Verbose "$($thisFN): Created ID:$($BlueCatReply) for '$($Zone.name)'"

            if ($PassThru) {
                Get-BlueCatSOA -Zone $Zone -BlueCatSession $BlueCatSession
            }
        } else {
            $Failure = "$($thisFN): Record creation failed for $($Zone.name)"
            throw $Failure
            Write-Verbose $Failure
        }
    }
}
