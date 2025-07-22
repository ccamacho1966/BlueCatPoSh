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

    begin { Get-CallerPreference -Cmdlet $PSCmdlet -SessionState $ExecutionContext.SessionState }

    process {
        $thisFN = (Get-PSCallStack)[0].Command

        $NewHost = $Name | Test-ValidFQDN
        $LookupParms = @{
            Name           = $NewHost
            BlueCatSession = $BlueCatSession
        }

        if ($ViewID) {
            $LookupParms.ViewID = $ViewID
            $ConfigID           = Get-BlueCatParent -ID $ViewID -BlueCatSession $BlueCatSession
        } elseif ($View)   {
            $LookupParms.View   = $View
            $ViewID             = $View.ID
            $ConfigID           = $View.config.id
        }

        if (-not $ConfigID) {
            if ($BlueCatSession.Config) {
                $ConfigID       = $BlueCatSession.Config.id
            }
        }

        $HostInfo = Resolve-BlueCatFQDN @LookupParms
        if ($HostInfo.host) {
            # There is already a host entry!!
            throw 'Host record already exists'
        }

        if (-not $HostInfo.zone) {
            # No deployable zone was found for Alias/CName
            throw "No deployable zone for $($NewHost)"
        }

        Write-Verbose "$($thisFN): Selected Zone #$($HostInfo.zone.id) as '$($HostInfo.zone.name)'"

        if ($HostInfo.external) {
            Write-Warning "$($thisFN): An external host entry exists for '$($HostInfo.external.name)'"
        }

        $ipList = $null
        $LookupIP4Network = @{
            Parent         = $ConfigID
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
            name       = $HostInfo.shortName
            properties = "ttl=$($TTL)|absoluteName=$($SRVInfo.name)|addresses=$($ipList)|reverseRecord=true|"
        }
        $CreateHostRecord = @{
            Method         = 'Post'
            Request        = "addEntity?parentId=$($HostInfo.zone.id)"
            Body           = ($Body | ConvertTo-Json)
            BlueCatSession = $BlueCatSession
        }

        $BlueCatReply = Invoke-BlueCatApi @CreateHostRecord
        if (-not $BlueCatReply) {
            throw "Host creation failed for $($NewHost)"
        }

        Write-Verbose "$($thisFN): Created Host Record for '$($HostInfo.name)' - ID:$($($BlueCatReply)), IP(s): $($ipList)"

        if ($PassThru) {
            Get-BlueCatEntityById -ID $BlueCatReply -BlueCatSession $BlueCatSession
        }
    }
}
