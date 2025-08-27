function Add-BlueCatHost
{
<#
.SYNOPSIS
    Create a new DNS Host (A) record.
.DESCRIPTION
    The Add-BlueCatHost cmdlet will create a new DNS A record.

    DNS 'A' records map a FQDN to an IPv4 address.
.PARAMETER Name
    A string value representing the FQDN of the Host (A) record to be created.
.PARAMETER Addresses
    An array of string values each containing a single IP address.

    An IPv4 network for each IP address must be already defined.
.PARAMETER TTL
    An integer value representing time-to-live for the new Host record.
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
    A switch that causes a PSCustomObject representing the new Host record to be returned.
.EXAMPLE
    PS> Add-BlueCatHost -Name myhost.example.com -Addresses '10.99.100.10'

    Create a new Host record for the name 'myhost' in the example.com zone.
    The IPv4 address for this host record is: 10.99.100.10
    BlueCatSession will default to the current default session.
    View will default to the BlueCatSession default view.
    TTL will default to the zone default time-to-live.
.EXAMPLE
    PS> Add-BlueCatHost -Name server3.example.com -Addresses ('10.99.100.103','10.103.99.13') -TTL 300 -ViewID 23456 -BlueCatSession $Session4 -PassThru

    Create a new Host record for the name 'server3' in the example.com zone in view 23456.
    The record will have 2 IPv4 addresses: 10.99.100.103 and 10.103.99.13
    TTL for this record will be set to 300 seconds (5 minutes).
    Use the BlueCatSession associated with $Session4 to create this record.

    A PSCustomObject representing the new Host record will be returned (PassThru).
.INPUTS
    None
.OUTPUTS
    None, by default.

    If the '-PassThru' switch is used, a PSCustomObject representing the new Host record will be returned.
#>
    [CmdletBinding(DefaultParameterSetName='ViewID')]

    param(
        [parameter(Mandatory)]
        [Alias('HostName')]
        [string] $Name,

        [parameter(Mandatory)]
        [string[]] $Addresses, # accept one or more strings

        [int] $TTL = -1,

        [Parameter(ParameterSetName='ZoneObj',Mandatory)]
        [ValidateNotNullOrEmpty()]
        [PSCustomObject] $Zone,

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
            throw "$($thisFN): Existing alias record found - aborting Host creation!"
        } elseif (Get-BlueCatHost @LookupZone) {
            # There is already an existing host entry
            throw "$($thisFN): Existing host record found - aborting Host creation!"
        }

        $ExistingExternal = Get-BlueCatExternalHost @LookupView
        if ($ExistingExternal) {
            Write-Warning "$($thisFN): An external host entry exists for '$($ExistingExternal.name)' (ID:$($ExistingExternal.id))"
        }

        $ipList = $null
        $LookupIP4Network = @{
            Parent         = $View.config
            Type           = 'IP4Network'
            BlueCatSession = $BlueCatSession
        }
        foreach ($ip in $Addresses) {
            # Verify that an IPv4 network exists for each address
            $LookupIP4Network.Address = $ip
            $IP4Network = Get-BlueCatIPContainerByIP @LookupIP4Network
            if (-not $IP4Network) {
                # IPv4 network not found for this address - throw an error
                throw "$($thisFN): Could not find IP4 network for '$($ip)'"
            }

            # Build comma separated list of IP addresses for the API call
            if ($ipList) {
                $ipList = $ipList+','+$ip
            } else {
                $ipList = $ip
            }
        }

        $Body = @{
            type       = 'HostRecord'
            name       = $ShortName
            properties = "ttl=$($TTL)|absoluteName=$($SRVInfo.name)|addresses=$($ipList)|reverseRecord=true|"
        }
        $CreateHostRecord = @{
            Method         = 'Post'
            Request        = "addEntity?parentId=$($Zone.id)"
            Body           = ($Body | ConvertTo-Json)
            BlueCatSession = $BlueCatSession
        }

        $BlueCatReply = Invoke-BlueCatApi @CreateHostRecord
        if (-not $BlueCatReply) {
            throw "$($thisFN) Host creation failed for $($FQDN)"
        }

        Write-Verbose "$($thisFN): Created Host Record for '$($FQDN)' - ID:$($($BlueCatReply)), IP(s): $($ipList)"

        if ($PassThru) {
            Get-BlueCatHost @LookupZone
        }
    }
}
