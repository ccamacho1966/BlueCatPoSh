function Update-BlueCatSOA {
    [CmdletBinding(DefaultParameterSetName='ViewID')]

    param(
        [Parameter(ParameterSetName='SOA',Mandatory)]
        [PSCustomObject] $SOA,

        [Parameter(ParameterSetName='ZoneObj',Mandatory)]
        [ValidateNotNullOrEmpty()]
        [Alias('ZoneObj')]
        [PSCustomObject] $Zone,

        [Parameter(Mandatory,ParameterSetName='ViewID')]
        [Parameter(Mandatory,ParameterSetName='ViewObj')]
        [Alias('ZoneName')]
        [string] $Name,

        [Parameter()]
        [Alias('RNAME','Admin')]
        [System.Net.Mail.MailAddress] $Email,

        [Parameter()]
        [ValidatePattern('^([a-z0-9]+(-[a-z0-9]+)*\.)+[a-z]{2,}$')]
        [Alias('MNAME','Primary')]
        [string] $OriginServer,

        [Parameter()]
        [Uint32] $Refresh,

        [Parameter()]
        [Uint32] $Retry,

        [Parameter()]
        [Uint32] $Expire,

        [Parameter()]
        [ValidateRange(1,10800)]    # Maximum permitted value is 10800 (3 hours)
        [Alias('NegTTL')]
        [Uint32] $Minimum,

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

        if ((-not $Email) -and (-not $Refresh) -and (-not $Retry) -and (-not $Expire) -and (-not $Minimum) -and (-not $OriginServer)) {
            throw "$($thisFN): You must supply at least 1 value to be updated."
        }

        if ($Name) {
            # Translate zone name into SOA object
            $SOALookup = @{
                Name               = $Name
                BlueCatSession     = $BlueCatSession
            }
            if ($View) {
                $SOALookup.View   = $View
            }
            if ($ViewID) {
                $SOALookup.ViewID = $ViewID
            }
        } elseif ($Zone) {
            $SOALookup = @{
                Zone           = $Zone
                BlueCatSession = $BlueCatSession
            }
        }

        if ($SOALookup) {
            $SOA = Get-BlueCatSOA @SOALookup
        }

        if ($SOA.type -ne 'StartOfAuthority') {
            if ($Name) {
                throw "$($thisFN): Could not find a zone named '$($Name)'"
            } else {
                throw "$($thisFN): Object is not a StartOfAuthority (ID:$($SOA.ID) $($SOA.name) is a $($SOA.type))"
            }
        }

        # Update individual property fields, as requested
        if ($Email)        { $SOA.property.email   = $Email        }
        if ($Refresh)      { $SOA.property.refresh = $Refresh      }
        if ($Retry)        { $SOA.property.retry   = $Retry        }
        if ($Expire)       { $SOA.property.expire  = $Expire       }
        if ($Minimum)      { $SOA.property.minimum = $Minimum      }
        if ($OriginServer) { $SOA.property.mname   = $OriginServer }

        # Convert the property object to a BlueCat properties string
        $SoaPropertyString = ($SOA.property | Convert-BlueCatPropertyObject)

        # Build the BlueCat StartOfAuthority object
        $SoaUpdateBody = @{
            id         = $SOA.id
            name       = 'start-of-authority'
            type       = 'StartOfAuthority'
            properties = $SoaPropertyString
        }

        # Build the BlueCat API v1 call
        $UpdateSOARecord = @{
            Method         = 'Put'
            Request        = "update"
            Body           = ($SoaUpdateBody | ConvertTo-Json)
            BlueCatSession = $BlueCatSession
        }

        # Update the SOA record
        $BlueCatReply = Invoke-BlueCatApi @UpdateSOARecord

        # There should not be an actual reply sent on success
        if ($BlueCatReply) {
            Write-Warning "$($thisFN): Unexpected reply: $($BlueCatReply)"
        }

        if ($PassThru) {
            # Update the retrieved object's property string and return, if requested
            $SOA.properties = $SoaPropertyString
            $SOA
        }
    }
}
