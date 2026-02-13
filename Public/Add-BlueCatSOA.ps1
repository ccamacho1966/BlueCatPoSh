function Add-BlueCatSOA {
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
