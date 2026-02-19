function Update-BlueCatSOA {
<#
.SYNOPSIS
    Update an existing Start of Authority record.
.DESCRIPTION
    The Update-BlueCatSOA cmdlet will update an existing Start of Authority record by allowing you to update specific fields.

    Any fields not supplied as a parameter to this cmdlet will not be modified.
.PARAMETER Name
    A string value representing the FQDN of the DNS Zone that will have its Start of Authority record updated.
.PARAMETER SOA
    A PSCustomObject representing the existing Start of Authority record.
.PARAMETER Zone
    A PSCustomObject representing the DNS Zone that will have its Start of Authority record updated.
.PARAMETER Email
    A MailAddress object representing the email address of the published domain administrator.
.PARAMETER OriginServer
    A string value representing the FQDN of the published primary name server.
.PARAMETER Refresh
    Time in seconds that secondary servers wait before asking for the serial number again.
.PARAMETER Retry
    Time in seconds a secondary waits to retry a failed request.
.PARAMETER Expire
    Maximum time in seconds a secondary server can wait before treating its data as invalid.
.PARAMETER Minimum
    The default time-to-live for caching negative (not found) records.
.PARAMETER ViewID
    An integer value representing the entity ID of the desired view.
.PARAMETER View
    A PSCustomObject representing the desired view.
.PARAMETER BlueCatSession
    A BlueCat object representing the session to be used for this object creation.
.PARAMETER PassThru
    A switch that causes a PSCustomObject representing the new DNS Zone to be returned.
.EXAMPLE
    PS> Update-BlueCatSOA -Name 'example.com' -Refresh 600

    Update the Start of Authority for example.com to have a refresh timer of 600 seconds (10 minutes).
    BlueCatSession will default to the current default session.
    View will default to the BlueCatSession default view.
.EXAMPLE
    PS> $NewSOA = ($MySOA | Update-BlueCatSOA -Email 'dnsadmin@example.com' -PassThru)

    Update the Start of Authority record represented by $MySOA by updating the administrative email address.

    A PSCustomObject representing the new Start of Authority will be returned (PassThru) and stored in the $NewSOA variable.
.INPUTS
    A PSCustomObject representing the existing Start of Authority record.
.OUTPUTS
    None, by default.

    If the '-PassThru' switch is used, a PSCustomObject representing the updated Start of Authority record will be returned.
#>
    [CmdletBinding(DefaultParameterSetName='ViewID')]

    param(
        [Parameter(ParameterSetName='SOA',Mandatory,ValueFromPipeline)]
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
        $SoaPropertyString = ($SOA.property | Select-Object -Property * -ExcludeProperty inherited | Convert-BlueCatPropertyObject)

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
